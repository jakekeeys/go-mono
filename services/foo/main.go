package main

import "github.com/jakekeeys/go-mono/services/foo/cmd"
import _ "github.com/jakekeeys/go-mono/services/foo/internal/store"

func main() {
	cmd.Run()
}
