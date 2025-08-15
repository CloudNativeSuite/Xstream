package main

import (
	"archive/zip"
	"errors"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"runtime"
	"strconv"
	"strings"
	"time"
)

// xrayDestPath returns the installation path of xray binary according to OS.
func xrayDestPath() string {
	switch runtime.GOOS {
	case "windows":
		return filepath.Join(os.Getenv("ProgramFiles"), "Xstream", "xray.exe")
	case "darwin":
		return "/usr/local/bin/xray"
	default:
		return "/opt/bin/xray"
	}
}

func downloadFileWithResume(url, dest string) error {
	fmt.Println("Xray core download URL:", url)
	var downloaded int64
	if info, err := os.Stat(dest); err == nil {
		downloaded = info.Size()
	}
	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return err
	}
	if downloaded > 0 {
		req.Header.Set("Range", fmt.Sprintf("bytes=%d-", downloaded))
	}
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK && resp.StatusCode != http.StatusPartialContent {
		return fmt.Errorf("unexpected status: %s", resp.Status)
	}

	var total int64
	if resp.StatusCode == http.StatusOK {
		total = resp.ContentLength
	} else if resp.StatusCode == http.StatusPartialContent {
		if cr := resp.Header.Get("Content-Range"); cr != "" {
			if parts := strings.Split(cr, "/"); len(parts) == 2 {
				total, _ = strconv.ParseInt(parts[1], 10, 64)
			}
		}
	}

	out, err := os.OpenFile(dest, os.O_CREATE|os.O_WRONLY, 0644)
	if err != nil {
		return err
	}
	defer out.Close()
	if downloaded > 0 {
		if _, err := out.Seek(downloaded, io.SeekStart); err != nil {
			return err
		}
	}

	buf := make([]byte, 32*1024)
	last := time.Now()
	for {
		n, err := resp.Body.Read(buf)
		if n > 0 {
			if _, werr := out.Write(buf[:n]); werr != nil {
				return werr
			}
			downloaded += int64(n)
			if time.Since(last) > time.Second {
				if total > 0 {
					fmt.Printf("Download progress: %.2f%% (%d/%d bytes)\n", float64(downloaded)*100/float64(total), downloaded, total)
				} else {
					fmt.Printf("Downloaded %d bytes\n", downloaded)
				}
				last = time.Now()
			}
		}
		if err != nil {
			if err == io.EOF {
				break
			}
			return err
		}
	}
	fmt.Println("Download completed:", dest)
	return nil
}

func extractBinary(zipPath, binaryName, dest string) error {
	zr, err := zip.OpenReader(zipPath)
	if err != nil {
		return err
	}
	defer zr.Close()

	for _, f := range zr.File {
		if filepath.Base(f.Name) == binaryName {
			rc, err := f.Open()
			if err != nil {
				return err
			}
			defer rc.Close()

			if err := os.MkdirAll(filepath.Dir(dest), 0755); err != nil {
				return err
			}
			out, err := os.Create(dest)
			if err != nil {
				return err
			}
			if _, err := io.Copy(out, rc); err != nil {
				out.Close()
				return err
			}
			out.Close()
			if runtime.GOOS != "windows" {
				if err := os.Chmod(dest, 0755); err != nil {
					return err
				}
			}
			fmt.Println("Xray extracted to:", dest)
			return nil
		}
	}
	return errors.New("xray binary not found in archive")
}

func downloadAndInstallXray() error {
	var url, binaryName string
	switch runtime.GOOS {
	case "windows":
		url = fmt.Sprintf("%s/xray-core/v25.8.3/Xray-windows-64.zip", artifactBaseURL)
		binaryName = "xray.exe"
	case "darwin":
		url = fmt.Sprintf("%s/xray-core/v25.8.3/Xray-macos-64.zip", artifactBaseURL)
		binaryName = "xray"
	default:
		url = fmt.Sprintf("%s/xray-core/v25.8.3/Xray-linux-64.zip", artifactBaseURL)
		binaryName = "xray"
	}
	dest := xrayDestPath()
	tmpZip := filepath.Join(os.TempDir(), filepath.Base(url))
	if err := downloadFileWithResume(url, tmpZip); err != nil {
		return err
	}
	if err := extractBinary(tmpZip, binaryName, dest); err != nil {
		return err
	}
	return nil
}
