package main

import (
	"fmt"
	"os"
	"path/filepath"
	"runtime"

	ort "github.com/yalue/onnxruntime_go"
)

func main() {
	libDir := os.Getenv("ORT_LIB_DIR")
	if libDir == "" {
		fmt.Fprintln(os.Stderr, "ORT_LIB_DIR not set")
		os.Exit(1)
	}

	var libName string
	switch runtime.GOOS {
	case "linux":
		matches, _ := filepath.Glob(filepath.Join(libDir, "libonnxruntime.so.*.*.*"))
		if len(matches) == 0 {
			fmt.Fprintln(os.Stderr, "libonnxruntime.so.*.*.* not found in "+libDir)
			os.Exit(1)
		}
		libName = matches[0]
	case "windows":
		libName = filepath.Join(libDir, "onnxruntime.dll")
	case "darwin":
		matches, _ := filepath.Glob(filepath.Join(libDir, "libonnxruntime.*.dylib"))
		if len(matches) == 0 {
			fmt.Fprintln(os.Stderr, "libonnxruntime.*.dylib not found in "+libDir)
			os.Exit(1)
		}
		libName = matches[0]
	default:
		fmt.Fprintf(os.Stderr, "unsupported OS: %s\n", runtime.GOOS)
		os.Exit(1)
	}

	fmt.Printf("Loading ORT library: %s\n", libName)
	ort.SetSharedLibraryPath(libName)

	if err := ort.InitializeEnvironment(); err != nil {
		fmt.Fprintf(os.Stderr, "InitializeEnvironment failed: %v\n", err)
		os.Exit(1)
	}
	defer ort.DestroyEnvironment()

	version := ort.GetVersion()
	fmt.Printf("ORT version: %s\n", version)

	if version == "" {
		fmt.Fprintln(os.Stderr, "ORT version is empty, library may not be loaded correctly")
		os.Exit(1)
	}

	fmt.Println("Smoke test PASSED")
}
