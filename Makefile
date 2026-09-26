.PHONY: all test lint help

SHELL_SCRIPTS = idler.sh state.sh tests/idler.test.sh tests/state.test.sh

all: lint test

## test : unit tests of the model and the package, then the shell scripts
test:
	node --test tests/*.test.mjs
	./tests/idler.test.sh
	./tests/state.test.sh

## lint : shell syntax, shellcheck, JSON manifest
lint:
	@for script in $(SHELL_SCRIPTS); do bash -n "$$script" || exit 1; done
	@if command -v shellcheck >/dev/null; then shellcheck -S warning $(SHELL_SCRIPTS); \
	else docker run --rm -v "$(CURDIR):/mnt" -w /mnt koalaman/shellcheck:stable -S warning $(SHELL_SCRIPTS); fi
	@node -e 'JSON.parse(require("fs").readFileSync("manifest.json", "utf8"))'
	@echo "lint ok"

help:
	@grep -h '^## ' $(MAKEFILE_LIST) | sed 's/^## /  make /'
