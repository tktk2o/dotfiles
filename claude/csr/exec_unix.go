package main

import (
	"os"
	"syscall"
)

// syscallExec replaces csr with claude rather than nesting it under a parent
// that has nothing left to do. Only reached outside tmux.
func syscallExec(path string, argv []string) error {
	return syscall.Exec(path, argv, os.Environ())
}
