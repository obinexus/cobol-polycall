# CBLPolyCall Makefile v1.1 -- GnuCOBOL client over the Polycall core
# OBINexus Aegis Engineering - COBOL FFI Bridge Build System
# Technical Lead: Nnamdi Michael Okpala
#
# Needs GnuCOBOL (cobc >= 3.1), a C compiler and an installed Polycall core
# (>= 1.1.0, binding ABI 1) found through pkg-config
# (PKG_CONFIG_PATH=<prefix>/lib/pkgconfig).

PROJECT_NAME = cblpolycall
VERSION = 1.1.0
SRC_DIR = src
BUILD_DIR = build
TARGET_DIR = target
COPYBOOK_DIR = copybooks

COBC ?= cobc
CC ?= gcc
PKG_CONFIG ?= pkg-config

POLYCALL_CFLAGS ?= $(shell $(PKG_CONFIG) --cflags polycall 2>/dev/null)
POLYCALL_LIBS ?= $(shell $(PKG_CONFIG) --libs polycall 2>/dev/null)

ifeq ($(OS),Windows_NT)
EXT = .exe
else
EXT =
endif

CFLAGS ?= -O2 -g
CFLAGS += -fPIC -Wall -Wextra
# CALL "cobpc_..." / "POLYCALL-BRIDGE" are resolved at link time.
COBFLAGS ?= -O
COBFLAGS += -fstatic-call -I$(COPYBOOK_DIR)

SHIM_OBJ = $(BUILD_DIR)/cobpolycall.o
BRIDGE_OBJ = $(BUILD_DIR)/POLYCALL.o
MAIN_TARGET = $(TARGET_DIR)/$(PROJECT_NAME)$(EXT)
TEST_TARGET = $(BUILD_DIR)/polycall-test$(EXT)
LOADER_TARGET = $(BUILD_DIR)/loader-check$(EXT)
VALGRIND ?= valgrind
VALGRIND_FLAGS ?= --error-exitcode=99 --leak-check=full --errors-for-leak-kinds=definite --track-origins=yes
COPYBOOKS = $(wildcard $(COPYBOOK_DIR)/*.CPY)

.PHONY: all clean test test-build test-loader memcheck package help debug check-toolchain check-core

all: check-toolchain check-core $(MAIN_TARGET)

# A missing toolchain is a SKIP (exit 77), never a success.
check-toolchain:
	@command -v $(COBC) >/dev/null 2>&1 || { echo "SKIP: GnuCOBOL ($(COBC)) not found"; exit 77; }
	@command -v $(CC) >/dev/null 2>&1 || { echo "SKIP: C compiler ($(CC)) not found"; exit 77; }

check-core:
	@test -n "$(POLYCALL_LIBS)" || { echo "cblpolycall: pkg-config cannot find polycall (>= 1.1.0); set PKG_CONFIG_PATH=<prefix>/lib/pkgconfig" >&2; exit 2; }

$(BUILD_DIR) $(TARGET_DIR):
	@mkdir -p $@

$(SHIM_OBJ): $(SRC_DIR)/cobpolycall.c $(SRC_DIR)/cobpolycall.h | $(BUILD_DIR)
	$(CC) $(CFLAGS) $(POLYCALL_CFLAGS) -c $< -o $@

$(BRIDGE_OBJ): $(SRC_DIR)/POLYCALL.CBL $(COPYBOOKS) | $(BUILD_DIR)
	$(COBC) -c $(COBFLAGS) -o $@ $<

$(MAIN_TARGET): $(SRC_DIR)/MAIN.CBL $(BRIDGE_OBJ) $(SHIM_OBJ) | $(TARGET_DIR)
	$(COBC) -x $(COBFLAGS) -o $@ $(SRC_DIR)/MAIN.CBL $(BRIDGE_OBJ) $(SHIM_OBJ) $(POLYCALL_LIBS)
	@echo "Build completed: $@"

$(TEST_TARGET): tests/POLYCALL-TEST.CBL $(BRIDGE_OBJ) $(SHIM_OBJ) | $(BUILD_DIR)
	$(COBC) -x $(COBFLAGS) -o $@ tests/POLYCALL-TEST.CBL $(BRIDGE_OBJ) $(SHIM_OBJ) $(POLYCALL_LIBS)

$(LOADER_TARGET): tests/LOADER-CHECK.CBL $(SHIM_OBJ) | $(BUILD_DIR)
	$(COBC) -x $(COBFLAGS) -o $@ tests/LOADER-CHECK.CBL $(SHIM_OBJ) $(POLYCALL_LIBS)

test-build: check-toolchain check-core $(MAIN_TARGET) $(TEST_TARGET)

# Real-core tests + interop with the C CLI + a scripted run of the client.
test:
	sh tests/test_runner.sh

# Missing library, old library without ABI v1 symbols, ABI mismatch
# (Linux; exit 77 = SKIP elsewhere). See tests/loader-errors.sh.
test-loader: check-toolchain check-core $(LOADER_TARGET)
	sh tests/loader-errors.sh $(LOADER_TARGET) .

# The real-core test under valgrind memcheck (exit 77 = SKIP without it).
memcheck: test-build
	@command -v $(VALGRIND) >/dev/null 2>&1 || { echo "SKIP: $(VALGRIND) not found"; exit 77; }
	sh tests/run-real.sh $(VALGRIND) $(VALGRIND_FLAGS) $(TEST_TARGET) .

clean:
	rm -rf $(BUILD_DIR) $(TARGET_DIR)
	rm -f *.o *.obj *.lst *.i

package: all
	@mkdir -p dist/$(PROJECT_NAME)-$(VERSION)
	@cp -r $(TARGET_DIR)/* dist/$(PROJECT_NAME)-$(VERSION)/
	@cp README.md cobol-polycallrc dist/$(PROJECT_NAME)-$(VERSION)/
	@cd dist && tar -czf $(PROJECT_NAME)-$(VERSION).tar.gz $(PROJECT_NAME)-$(VERSION)
	@echo "Package created: dist/$(PROJECT_NAME)-$(VERSION).tar.gz"

debug:
	@echo "COBOL compiler: $$(command -v $(COBC) || echo none)"
	@$(COBC) --version 2>/dev/null | head -1 || true
	@echo "C compiler: $(CC)"
	@echo "Polycall cflags: $(POLYCALL_CFLAGS)"
	@echo "Polycall libs: $(POLYCALL_LIBS)"

help:
	@echo "CBLPolyCall Build System v$(VERSION)"
	@echo "  all       - build target/$(PROJECT_NAME) (default)"
	@echo "  test      - real-core tests (tests/test_runner.sh)"
	@echo "  test-loader - missing / old / ABI-mismatched library (Linux)"
	@echo "  memcheck  - the real-core test under valgrind"
	@echo "  clean     - remove build artifacts"
	@echo "  package   - distribution tarball"
	@echo "  debug     - toolchain information"
