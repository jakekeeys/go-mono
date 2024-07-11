package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

var (
	app       = flag.String("app", "", "path to your application main.go")
	base      = flag.String("base", "", "path to your application root directory")
	lPrefix   = flag.String("local", "", "local dependency prefix relative to GOPATH")
	since     = flag.Int("since", 1, "the number of commits to search for changes")
	targetRev = flag.String("target-revision", "HEAD", "the target (current) git revision to use when looking for changes")
	sourceRev = flag.String("source-revision", "HEAD", "the source (previous) git revision to use when looking for changes")
	show      = flag.Bool("show", false, "show the changes")
)

const usage = `changed - determines if an application has changed.

Changed determines if an application has changed by examining the source tree for changes in the last N (-since flag) commits.
Changed uses a combination of git ls-tree and git diff to discover such changes. This list is compared with the application files,
local and external dependencies (all determined using the go list command) in order to identify if the application has been changed.
Changed follows the "silence is golden" principle - ie, if nothing is output, no error occurred (the application has changed).

Example usage: changed -app=services/my-service/cmd/my-service -base=/home/me/go/src/github.com/jakekeeys/my-monorepo -local=github.com/jakekeeys/my-monorepo

Flags:
  app - path to the directory containing your main.go file, relative to 'base'
  base - absolute path to your application/monorepo root directory
  local - local dependency import path prefix (ie, dependencies within your monorepo)
  since - the number of commits to search for changes (HEAD~N) (eg, 2) [default 1]
  target-revision - the target (current) git revision to use when looking for changes (eg, master) [default HEAD]
  source-revision - the source (previous) git revision to use when looking for changes (eg, master) [default HEAD]
  show - show the changes [default false]

Exit codes:
  0 - the application has changed
  1 - incorrect usage (check the flags provided)
  2 - no Go files found
  3 - the application has not changed`

func main() {
	flag.Parse()
	if *app == "" || *base == "" || *lPrefix == "" {
		fmt.Fprintln(os.Stderr, usage)
		os.Exit(1)
	}

	name := strings.Trim(strings.Replace(*app, *base, "", -1), "/")

	files, local, external, err := dependencies(*app, *base, *lPrefix)
	if err != nil {
		panic(err)
	}

	if len(files) == 0 {
		fmt.Fprintln(os.Stderr, "no Go files found")
		os.Exit(2)
	}

	externalChanged, err := externalChanges(*base, *since)
	if err != nil {
		panic(err)
	}

	localChanged, err := localChanges(*base, *sourceRev, *targetRev, *since)
	if err != nil {
		panic(err)
	}

	var hasChanges bool
	for _, change := range externalChanged {
		for _, dependency := range external {
			if strings.Contains(dependency, change) {
				// the application contains an external dependency which has changed
				if *show {
					fmt.Println(dependency)
				}

				hasChanges = true
			}
		}
	}

	for _, change := range localChanged {
		for _, dependency := range local {
			if strings.Contains(change, strings.TrimPrefix(strings.TrimPrefix(dependency, *lPrefix), "/")) {
				// the application contains a local dependency which has changed
				if *show {
					fmt.Println(dependency, "-", change)
				}

				hasChanges = true
			}
		}

		// TODO(kaperys) add support for the deletion of a package main file
		for _, file := range files {
			if filepath.Join(name, file) == change {
				// package main files have changed/been added
				if *show {
					fmt.Println(change)
				}

				hasChanges = true
			}
		}
	}

	if hasChanges {
		os.Exit(0)
	}

	fmt.Fprintln(os.Stderr, "application has not changed")
	os.Exit(3)
}

func dependencies(app, base, lPrefix string) ([]string, []string, []string, error) {
	goX, err := exec.LookPath("go")
	if err != nil {
		return nil, nil, nil, fmt.Errorf("could not lookup `go` path: %v", err)
	}

	cmd := exec.Command(goX, "list", "-json", filepath.Join(base, app))
	cmd.Dir = base

	out, err := cmd.CombinedOutput()
	if err != nil {
		return nil, nil, nil, fmt.Errorf("could not execute `go list`: %s: %v", string(out), err)
	}

	list := struct {
		Deps    []string
		GoFiles []string
	}{}

	err = json.Unmarshal(out, &list)
	if err != nil {
		return nil, nil, nil, fmt.Errorf("could not unmarshal go list output %q: %w", string(out), err)
	}

	var local, external []string

	rxRelaxed := xurls.Relaxed()
	for _, dep := range list.Deps {
		u := rxRelaxed.FindString(dep)
		if u != "" {
			if strings.HasPrefix(u, lPrefix) { // dependency contains base path - local
				local = append(local, strings.Trim(strings.Replace(u, base, "", -1), "/"))
			} else { // dependency does not contain base path - external
				external = append(external, strings.Trim(u, "/"))
			}
		}
	}

	return list.GoFiles, local, external, nil
}

func externalChanges(base string, since int) ([]string, error) {
	git, err := exec.LookPath("git")
	if err != nil {
		return nil, fmt.Errorf("could not lookup `git` path: %v", err)
	}

	cmd := exec.Command(git, "diff", "HEAD", fmt.Sprintf("HEAD~%d", since), "go.mod")
	cmd.Dir = base

	out, err := cmd.CombinedOutput()
	if err != nil {
		return nil, fmt.Errorf("could not execute `git diff`: %s: %v", string(out), err)
	}

	rows := strings.Split(string(out), "\n")
	if len(rows) < 2 {
		return nil, nil
	}

	var (
		urls     []string
		versions = make(map[string]string)
	)

	rxRelaxed := xurls.Relaxed()
	for _, row := range rows[6:] { // remove the diff header (diff --git a/go.mod b/go.mod, etc)
		u := rxRelaxed.FindString(row)
		if u != "" {
			parts := strings.Split(row, " ")
			version := parts[len(parts)-1]

			// only append to urls if the version is different
			if version != versions[u] {
				versions[u] = version
				urls = append(urls, u)
			}
		}
	}

	return urls, nil
}

func localChanges(base, source, target string, since int) ([]string, error) {
	current, err := lsTree(base, target)
	if err != nil {
		return nil, fmt.Errorf("could not retrieve current revision: %w", err)
	}

	previous, err := lsTree(base, fmt.Sprintf("%s~%d", source, since))
	if err != nil {
		return nil, fmt.Errorf("could not retrieve previous revision: %w", err)
	}

	var files []string

	for file, hash := range current {
		if strings.HasSuffix(file, ".go") {
			if prev, ok := previous[file]; ok {
				if prev != hash { // file changed
					files = append(files, file)
				}
			} else { // file added
				files = append(files, file)
			}
		}
	}

	for file := range previous {
		if strings.HasSuffix(file, ".go") {
			if _, ok := current[file]; !ok { // file deleted
				files = append(files, file)
			}
		}
	}

	return files, nil
}

func lsTree(path, revision string) (map[string]string, error) {
	git, err := exec.LookPath("git")
	if err != nil {
		return nil, fmt.Errorf("could not lookup `git` path: %v", err)
	}

	cmd := exec.Command(git, "ls-tree", "-r", revision)
	cmd.Dir = path

	out, err := cmd.CombinedOutput()
	if err != nil {
		return nil, fmt.Errorf("could not execute `git ls-tree`: %sL %v", string(out), err)
	}

	files := strings.Split(strings.Replace(string(out), "\t", " ", -1), "\n")
	versions := make(map[string]string, len(files))

	for _, file := range files {
		parts := strings.Split(file, " ")
		if len(parts) > 2 {
			if !strings.HasSuffix(parts[3], "_test.go") {
				versions[parts[3]] = parts[2]
			}
		}
	}

	return versions, nil
}
