package main

import (
	"os"
	"os/exec"
	"path/filepath"
)

func main() {
	dir, err := filepath.Abs(filepath.Dir(os.Args[0]))
	if err != nil {
		os.Exit(1)
	}
	headersScript := filepath.Join(dir, "headers.py")

	uv, err := exec.LookPath("uv")
	if err != nil {
		os.Exit(1)
	}

	cmd := exec.Command(uv, "run", headersScript)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		if exitErr, ok := err.(*exec.ExitError); ok {
			os.Exit(exitErr.ExitCode())
		}
		os.Exit(1)
	}
}
