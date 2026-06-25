CRYSTAL ?= crystal
SRC     := src/swarmy.cr
BIN     := bin/swarmy
DEV_BIN := bin/swarmy-dev
PREFIX  ?= /usr/local
SOURCES := $(shell find src -name '*.cr')

ifeq ($(shell uname),Darwin)
LINK_FLAGS := --link-flags="-fuse-ld=/usr/bin/ld"
endif

.PHONY: all build dev run test clean install uninstall

all: build

build: $(BIN)

$(BIN): $(SOURCES)
	$(CRYSTAL) build $(SRC) --release $(LINK_FLAGS) -o $(BIN)

dev: $(DEV_BIN)

$(DEV_BIN): $(SOURCES)
	$(CRYSTAL) build $(SRC) $(LINK_FLAGS) -o $(DEV_BIN)

run: dev
	./$(DEV_BIN)

test:
	$(CRYSTAL) spec $(LINK_FLAGS)

clean:
	rm -rf bin/*

install: build
	install -d $(PREFIX)/bin
	install -m 0755 $(BIN) $(PREFIX)/bin/swarmy

uninstall:
	rm -f $(PREFIX)/bin/swarmy
