//go:build windows

package main

import "C"
import (
	"archive/zip"
	"encoding/json"
	"errors"
	"fmt"
	"github.com/getlantern/systray"
	"golang.org/x/sys/windows"
	"io"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"sync"
	"time"
	"unsafe"
)

var downloadMu sync.Mutex
var downloading bool
var processMap sync.Map

func serviceExists(name string) bool {
	err := exec.Command("schtasks", "/Query", "/TN", name).Run()
	return err == nil
}

func cStringOrError(err error) *C.char {
	if err != nil {
		return C.CString("error:" + err.Error())
	}
	return C.CString("success")
}

//export WriteConfigFiles
func WriteConfigFiles(xrayPath, xrayContent, servicePath, serviceContent, vpnPath, vpnContent, password *C.char) *C.char {
	if res := writeConfigFile(xrayPath, xrayContent); res != nil {
		return res
	}
	if res := writeConfigFile(servicePath, serviceContent); res != nil {
		return res
	}
	return updateVpnNodesConfig(vpnPath, vpnContent)
}

func writeConfigFile(pathC, contentC *C.char) *C.char {
	p := C.GoString(pathC)
	c := C.GoString(contentC)
	if err := os.MkdirAll(filepath.Dir(p), 0755); err != nil {
		return C.CString("error:" + err.Error())
	}
	if err := os.WriteFile(p, []byte(c), 0644); err != nil {
		return C.CString("error:" + err.Error())
	}
	return nil
}

func updateVpnNodesConfig(pathC, contentC *C.char) *C.char {
	p := C.GoString(pathC)
	c := C.GoString(contentC)
	if err := os.MkdirAll(filepath.Dir(p), 0755); err != nil {
		return C.CString("error:" + err.Error())
	}
	var nodes []map[string]interface{}
	if data, err := os.ReadFile(p); err == nil {
		json.Unmarshal(data, &nodes)
	}
	var newNodes []map[string]interface{}
	if err := json.Unmarshal([]byte(c), &newNodes); err != nil {
		return C.CString("error:" + err.Error())
	}
	nodes = append(nodes, newNodes...)
	out, err := json.MarshalIndent(nodes, "", "  ")
	if err != nil {
		return C.CString("error:" + err.Error())
	}
	if err := os.WriteFile(p, out, 0644); err != nil {
		return C.CString("error:" + err.Error())
	}
	return C.CString("success")
}

func downloadAndExtractXray(destDir string) error {
	if err := os.MkdirAll(destDir, 0755); err != nil {
		return err
	}
	resp, err := http.Get(artifactBaseURL + "/xray-core/v25.8.3/Xray-windows-64.zip")
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	tmp, err := os.CreateTemp("", "xray-*.zip")
	if err != nil {
		return err
	}
	if _, err := io.Copy(tmp, resp.Body); err != nil {
		tmp.Close()
		os.Remove(tmp.Name())
		return err
	}
	tmp.Close()
	defer os.Remove(tmp.Name())
	zr, err := zip.OpenReader(tmp.Name())
	if err != nil {
		return err
	}
	defer zr.Close()
	var xrayFile *zip.File
	for _, f := range zr.File {
		name := strings.ToLower(filepath.Base(f.Name))
		if name == "xray.exe" {
			xrayFile = f
			break
		}
	}
	if xrayFile == nil {
		return errors.New("xray.exe not found")
	}
	rc, err := xrayFile.Open()
	if err != nil {
		return err
	}
	defer rc.Close()
	out, err := os.Create(filepath.Join(destDir, "xray.exe"))
	if err != nil {
		return err
	}
	defer out.Close()
	if _, err := io.Copy(out, rc); err != nil {
		return err
	}
	return nil
}

//export CreateWindowsService
func CreateWindowsService(nameC, execC, configC *C.char) *C.char {
	name := C.GoString(nameC)
	execPath := C.GoString(execC)
	cfg := C.GoString(configC)

	if serviceExists(name) {
		return C.CString("success")
	}

	taskCmd := fmt.Sprintf("\"%s\" run -c \"%s\"", execPath, cfg)
	out, err := exec.Command("schtasks", "/Create", "/TN", name, "/SC", "ONSTART", "/RL", "HIGHEST", "/TR", taskCmd, "/F").CombinedOutput()
	if err != nil {
		return C.CString("error:" + string(out))
	}
	return C.CString("success")
}

//export StartNodeService
func StartNodeService(name *C.char) *C.char {
	serviceName := C.GoString(name)
	programDir := filepath.Join(os.Getenv("ProgramFiles"), "Xstream")
	xrayPath := filepath.Join(programDir, "xray.exe")
	baseName := strings.TrimSuffix(serviceName, ".schtasks")
	parts := strings.Split(baseName, "-")
	code := parts[len(parts)-1]
	targetConfig := filepath.Join(programDir, fmt.Sprintf("xray-vpn-node-%s.json", code))
	configJson := filepath.Join(programDir, "config.json")

	// 复制节点配置为统一 config.json
	input, err := os.ReadFile(targetConfig)
	if err != nil {
		return C.CString("error: read " + targetConfig + " failed: " + err.Error())
	}
	if err := os.WriteFile(configJson, input, 0644); err != nil {
		return C.CString("error: write config.json failed: " + err.Error())
	}

	// 若任务不存在则创建
	if err := exec.Command("schtasks", "/Query", "/TN", serviceName).Run(); err != nil {
		taskCmd := fmt.Sprintf("\"%s\" run -c \"%s\"", xrayPath, configJson)
		if out, err := exec.Command("schtasks", "/Create", "/TN", serviceName, "/SC", "ONSTART", "/RL", "HIGHEST", "/TR", taskCmd, "/F").CombinedOutput(); err != nil {
			return C.CString("error:" + string(out))
		}
	}

	// 立即运行任务
	if out, err := exec.Command("schtasks", "/Run", "/TN", serviceName).CombinedOutput(); err != nil {
		return C.CString("error:" + string(out))
	}
	return C.CString("success")
}

//export StopNodeService
func StopNodeService(name *C.char) *C.char {
	serviceName := C.GoString(name)

	exec.Command("schtasks", "/End", "/TN", serviceName).Run()
	exec.Command("schtasks", "/Delete", "/TN", serviceName, "/F").Run()
	exec.Command("taskkill", "/F", "/IM", "xray.exe").Run()
	return C.CString("success")
}

//export CheckNodeStatus
func CheckNodeStatus(name *C.char) C.int {
	out, err := exec.Command("schtasks", "/Query", "/TN", C.GoString(name)).CombinedOutput()
	if err != nil {
		return -1
	}
	str := strings.ToLower(string(out))
	if strings.Contains(str, "running") || strings.Contains(str, "\xe6\xad\xa3\xe5\x9c\xa8\xe8\xbf\x90\xe8\xa1\x8c") {
		return 1
	}
	return 0
}

//export PerformAction
func PerformAction(action, password *C.char) *C.char {
	switch C.GoString(action) {
	case "initXray":
		return InitXray()
	case "updateXrayCore":
		return UpdateXrayCore()
	case "isXrayDownloading":
		if IsXrayDownloading() == 1 {
			return C.CString("1")
		}
		return C.CString("0")
	case "resetXrayAndConfig":
		return ResetXrayAndConfig(password)
	default:
		return C.CString("error:unknown action")
	}
}

//export InitXray
func InitXray() *C.char {
	destDir := filepath.Join(os.Getenv("ProgramFiles"), "Xstream")
	dest := filepath.Join(destDir, "xray.exe")
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
		if err := downloadAndExtractXray(destDir); err != nil {
			fmt.Println("Download failed:", err)
		}
	}()
	return C.CString("info:download started")
}

//export UpdateXrayCore
func UpdateXrayCore() *C.char {
	destDir := filepath.Join(os.Getenv("ProgramFiles"), "Xstream")
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
		if err := downloadAndExtractXray(destDir); err != nil {
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
func ResetXrayAndConfig(password *C.char) *C.char {
	dir := filepath.Join(os.Getenv("ProgramFiles"), "Xstream")
	os.RemoveAll(dir)
	exec.Command("schtasks", "/Delete", "/TN", "ray-node-jp.schtasks", "/F").Run()
	exec.Command("schtasks", "/Delete", "/TN", "ray-node-ca.schtasks", "/F").Run()
	exec.Command("schtasks", "/Delete", "/TN", "ray-node-us.schtasks", "/F").Run()
	return C.CString("success")
}

// ---- System tray integration ----

var trayOnce sync.Once
var windowHandle windows.Handle

var (
	user32                  = windows.NewLazySystemDLL("user32.dll")
	procFindWindowW         = user32.NewProc("FindWindowW")
	procShowWindow          = user32.NewProc("ShowWindow")
	procGetWindowPlacement  = user32.NewProc("GetWindowPlacement")
	procSetForegroundWindow = user32.NewProc("SetForegroundWindow")
)

type point struct {
	X int32
	Y int32
}

type rect struct {
	Left   int32
	Top    int32
	Right  int32
	Bottom int32
}

type windowPlacement struct {
	Length         uint32
	Flags          uint32
	ShowCmd        uint32
	MinPosition    point
	MaxPosition    point
	NormalPosition rect
}

func findMainWindow() windows.Handle {
	title, _ := windows.UTF16PtrFromString("xstream")
	h, _, _ := procFindWindowW.Call(0, uintptr(unsafe.Pointer(title)))
	return windows.Handle(h)
}

func showWindow(h windows.Handle, cmd int32) {
	procShowWindow.Call(uintptr(h), uintptr(cmd))
}

func getPlacement(h windows.Handle, wp *windowPlacement) bool {
	r, _, _ := procGetWindowPlacement.Call(uintptr(h), uintptr(unsafe.Pointer(wp)))
	return r != 0
}

func monitorMinimize() {
	for {
		if windowHandle == 0 {
			windowHandle = findMainWindow()
		}
		if windowHandle != 0 {
			var wp windowPlacement
			wp.Length = uint32(unsafe.Sizeof(wp))
			if getPlacement(windowHandle, &wp) {
				if wp.ShowCmd == windows.SW_SHOWMINIMIZED {
					showWindow(windowHandle, windows.SW_HIDE)
				}
			}
		}
		time.Sleep(500 * time.Millisecond)
	}
}

func onTrayReady() {
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
				if windowHandle == 0 {
					windowHandle = findMainWindow()
				}
				if windowHandle != 0 {
					showWindow(windowHandle, windows.SW_RESTORE)
					procSetForegroundWindow.Call(uintptr(windowHandle))
				}
			case <-mQuit.ClickedCh:
				systray.Quit()
				return
			}
		}
	}()
	go monitorMinimize()
}

//export InitTray
func InitTray() {
	trayOnce.Do(func() {
		go func() {
			runtime.LockOSThread()
			systray.Run(onTrayReady, func() {})
		}()
	})
}
