BIN := .build/release/mackey
PREFIX ?= /usr/local/bin

.PHONY: build test install clean

build:
	swift build -c release

test:
	swift run -c release mackey selftest

install: build
	install -d "$(PREFIX)"
	install -m 755 "$(BIN)" "$(PREFIX)/mackey"

clean:
	rm -rf .build
