//go:build linux

package main

/*
#cgo LDFLAGS: -lX11
#include <stdlib.h>
#include <string.h>
#include <X11/Xlib.h>
#include <X11/Xatom.h>
#include <X11/Xutil.h>

static Display* disp = NULL;
static Window mainWin = 0;

static Window getMainWin() {
    return mainWin;
}

static Window findWindow(const char* name) {
    if (disp == NULL) {
        disp = XOpenDisplay(NULL);
        if (disp == NULL) return 0;
    }
    Atom clientList = XInternAtom(disp, "_NET_CLIENT_LIST", True);
    Atom type;
    int format;
    unsigned long nitems, bytes;
    unsigned char* data = NULL;
    if (XGetWindowProperty(disp, DefaultRootWindow(disp), clientList, 0, 1024, False, XA_WINDOW, &type, &format, &nitems, &bytes, &data) == Success && data) {
        Window* list = (Window*)data;
        for (unsigned long i=0; i<nitems; i++) {
            char* wname = NULL;
            if (XFetchName(disp, list[i], &wname) > 0) {
                if (wname && strcmp(wname, name)==0) {
                    mainWin = list[i];
                    if (wname) XFree(wname);
                    XFree(data);
                    return mainWin;
                }
                if (wname) XFree(wname);
            }
        }
        XFree(data);
    }
    return 0;
}

static int isIconic() {
    if (!disp || mainWin==0) return 0;
    Atom WM_STATE = XInternAtom(disp, "WM_STATE", True);
    Atom type; int format; unsigned long items, bytes; unsigned char* prop=NULL;
    if (XGetWindowProperty(disp, mainWin, WM_STATE, 0, 2, False, WM_STATE, &type, &format, &items, &bytes, &prop) == Success && prop) {
        long state = *(long*)prop;
        XFree(prop);
        return state == IconicState;
    }
    return 0;
}

static void hideWindow() {
    if (disp && mainWin) { XUnmapWindow(disp, mainWin); XFlush(disp); }
}

static void showWindow() {
    if (disp && mainWin) { XMapRaised(disp, mainWin); XFlush(disp); }
}
*/
import "C"
import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"sync"
	"time"
	"unsafe"

	"github.com/getlantern/systray"
)

var downloadMu sync.Mutex
var downloading bool

func runCommand(cmd string) (string, error) {
	c := exec.Command("bash", "-c", cmd)
	out, err := c.CombinedOutput()
	return string(out), err
}

func runPrivilegedWrite(path, content, password string) error {
	dir := filepath.Dir(path)
	mkdirCmd := fmt.Sprintf("echo \"%s\" | sudo -S mkdir -pv \"%s\"", password, dir)
	if _, err := runCommand(mkdirCmd); err != nil {
		return err
	}
	escaped := strings.ReplaceAll(content, "\"", "\\\"")
	cmd := fmt.Sprintf("echo \"%s\" | sudo -S bash -c 'echo \"%s\" > \"%s\"'", password, escaped, path)
	_, err := runCommand(cmd)
	return err
}

//export WriteConfigFiles
func WriteConfigFiles(xrayPathC, xrayContentC, servicePathC, serviceContentC, vpnPathC, vpnContentC, passwordC *C.char) *C.char {
	xrayPath := C.GoString(xrayPathC)
	xrayContent := C.GoString(xrayContentC)
	servicePath := C.GoString(servicePathC)
	serviceContent := C.GoString(serviceContentC)
	vpnPath := C.GoString(vpnPathC)
	vpnContent := C.GoString(vpnContentC)
	password := C.GoString(passwordC)
	if err := runPrivilegedWrite(xrayPath, xrayContent, password); err != nil {
		return C.CString("error:" + err.Error())
	}
	if err := runPrivilegedWrite(servicePath, serviceContent, password); err != nil {
		return C.CString("error:" + err.Error())
	}
	var existing []map[string]interface{}
	if data, err := ioutil.ReadFile(vpnPath); err == nil {
		json.Unmarshal(data, &existing)
	}
	var newNodes []map[string]interface{}
	if err := json.Unmarshal([]byte(vpnContent), &newNodes); err == nil {
		existing = append(existing, newNodes...)
	} else {
		return C.CString("error:invalid vpn node content")
	}
	updated, _ := json.MarshalIndent(existing, "", "  ")
	if err := runPrivilegedWrite(vpnPath, string(updated), password); err != nil {
		return C.CString("error:" + err.Error())
	}
	return C.CString("success")
}

func downloadAndInstallXray() error {
	cmd := fmt.Sprintf("curl -L %s/xray-core/v25.3.6/Xray-linux-64.zip -o Xray-linux-64.zip && "+
		"mkdir -pv /opt/bin/ && "+
		"unzip -o Xray-linux-64.zip && "+
		"cp Xray-linux-64/xray /opt/bin/xray && chmod +x /opt/bin/xray", artifactBaseURL)
	_, err := runCommand(cmd)
	return err
}

//export StartNodeService
func StartNodeService(serviceC *C.char) *C.char {
	service := C.GoString(serviceC)
	cmd := fmt.Sprintf("systemctl --user start %s", service)
	out, err := runCommand(cmd)
	if err != nil {
		return C.CString("error:" + out)
	}
	return C.CString("success")
}

//export StopNodeService
func StopNodeService(serviceC *C.char) *C.char {
	service := C.GoString(serviceC)
	cmd := fmt.Sprintf("systemctl --user stop %s", service)
	out, err := runCommand(cmd)
	if err != nil {
		return C.CString("error:" + out)
	}
	return C.CString("success")
}

//export CheckNodeStatus
func CheckNodeStatus(serviceC *C.char) C.int {
	service := C.GoString(serviceC)
	cmd := fmt.Sprintf("systemctl --user is-active %s", service)
	out, err := runCommand(cmd)
	if err != nil {
		return -1
	}
	if strings.Contains(out, "active") {
		return 1
	}
	return 0
}

//export InitXray
func InitXray() *C.char {
	dest := "/opt/bin/xray"
	if _, err := os.Stat(dest); err == nil {
		return C.CString("success")
	}

	downloadMu.Lock()
	defer downloadMu.Unlock()
	if downloading {
		return C.CString("info:downloading in background")
	}
	downloading = true
	go func() {
		defer func() {
			downloadMu.Lock()
			downloading = false
			downloadMu.Unlock()
		}()
		if err := downloadAndInstallXray(); err != nil {
			fmt.Println("Download failed:", err)
		}
	}()
	return C.CString("info:download started")
}

//export UpdateXrayCore
func UpdateXrayCore() *C.char {
	downloadMu.Lock()
	defer downloadMu.Unlock()
	if downloading {
		return C.CString("info:downloading in background")
	}
	downloading = true
	go func() {
		defer func() {
			downloadMu.Lock()
			downloading = false
			downloadMu.Unlock()
		}()
		if err := downloadAndInstallXray(); err != nil {
			fmt.Println("Download failed:", err)
		}
	}()
	return C.CString("info:download started")
}

//export IsXrayDownloading
func IsXrayDownloading() C.int {
	downloadMu.Lock()
	d := downloading
	downloadMu.Unlock()
	if d {
		return 1
	}
	return 0
}

//export ResetXrayAndConfig
func ResetXrayAndConfig(passwordC *C.char) *C.char {
	password := C.GoString(passwordC)
	home, _ := os.UserHomeDir()
	script := fmt.Sprintf("rm -f %s/.local/bin/xray ; sudo -S rm -f /usr/local/bin/xray <<< \"%s\" ; rm -rf %s/.config/xray-vpn-node*", home, password, home)
	out, err := runCommand(script)
	if err != nil {
		return C.CString("error:" + out)
	}
	return C.CString("success")
}

//export StartXray
func StartXray(configC *C.char) *C.char {
	return C.CString("error:not supported")
}

//export StopXray
func StopXray() *C.char {
	return C.CString("error:not supported")
}

// ---- System tray integration ----

var trayOnce sync.Once

func monitorMinimize() {
	for {
		if C.getMainWin() == 0 {
			cname := C.CString("xstream")
			C.findWindow(cname)
			C.free(unsafe.Pointer(cname))
		}
		if C.getMainWin() != 0 {
			if C.isIconic() != 0 {
				C.hideWindow()
			}
		}
		time.Sleep(500 * time.Millisecond)
	}
}

//export InitTray
func InitTray() {
	trayOnce.Do(func() {
		go func() {
			runtime.LockOSThread()
			systray.Run(func() {
				icon, err := os.ReadFile("data/flutter_assets/assets/logo.png")
				if err == nil {
					systray.SetIcon(icon)
				}
				mShow := systray.AddMenuItem("Show", "Show window")
				mQuit := systray.AddMenuItem("Quit", "Quit")
				go func() {
					for {
						select {
						case <-mShow.ClickedCh:
							if C.getMainWin() == 0 {
								cname := C.CString("xstream")
								C.findWindow(cname)
								C.free(unsafe.Pointer(cname))
							}
							if C.getMainWin() != 0 {
								C.showWindow()
							}
						case <-mQuit.ClickedCh:
							systray.Quit()
							return
						}
					}
				}()
				go monitorMinimize()
			}, func() {})
		}()
	})
}
