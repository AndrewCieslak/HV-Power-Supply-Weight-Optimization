CONFIG ?= debug

UNAME_S := $(shell uname -s 2>/dev/null)
UNAME_M := $(shell uname -m 2>/dev/null)

ifeq ($(CONFIG),debug)
  SUFFIX := debug
else ifeq ($(CONFIG),release)
  SUFFIX := release
else ifeq ($(CONFIG),asan-ubsan)
  SUFFIX := asan-ubsan
else ifeq ($(CONFIG),tsan)
  SUFFIX := tsan
else ifeq ($(CONFIG),release-lto)
  SUFFIX := release-lto
else ifeq ($(CONFIG),debug-gcc)
  SUFFIX := debug
  LINUX_TOOLCHAIN := gcc
else ifeq ($(CONFIG),debug-clang)
  SUFFIX := debug
  LINUX_TOOLCHAIN := clang
else
  $(error Unknown CONFIG '$(CONFIG)'. Use one of: debug release asan-ubsan tsan release-lto debug-gcc debug-clang)
endif

ifeq ($(UNAME_S),Darwin)
  ifeq ($(UNAME_M),arm64)
    CMAKE_CONFIGURE_PRESET := macos-arm64-$(SUFFIX)
  else ifeq ($(UNAME_M),x86_64)
    CMAKE_CONFIGURE_PRESET := macos-x64-$(SUFFIX)
  else
    $(error Unsupported macOS arch '$(UNAME_M)')
  endif
  BUILD_DIR := build/$(CMAKE_CONFIGURE_PRESET)

else ifeq ($(UNAME_S),Linux)
  ifndef LINUX_TOOLCHAIN
    LINUX_TOOLCHAIN := gcc
  endif
  CMAKE_CONFIGURE_PRESET := linux-x64-$(LINUX_TOOLCHAIN)-$(SUFFIX)
  BUILD_DIR := build/$(CMAKE_CONFIGURE_PRESET)

else
  ifneq (,$(findstring MINGW,$(UNAME_S)))
    CMAKE_CONFIGURE_PRESET := windows-x64-msvc-$(SUFFIX)
    BUILD_DIR := build/$(CMAKE_CONFIGURE_PRESET)
  else ifneq (,$(findstring MSYS,$(UNAME_S)))
    CMAKE_CONFIGURE_PRESET := windows-x64-msvc-$(SUFFIX)
    BUILD_DIR := build/$(CMAKE_CONFIGURE_PRESET)
  else ifneq (,$(findstring CYGWIN,$(UNAME_S)))
    CMAKE_CONFIGURE_PRESET := windows-x64-msvc-$(SUFFIX)
    BUILD_DIR := build/$(CMAKE_CONFIGURE_PRESET)
  else
    # If uname isn't available, assume Windows.
    CMAKE_CONFIGURE_PRESET := windows-x64-msvc-$(SUFFIX)
    BUILD_DIR := build/$(CMAKE_CONFIGURE_PRESET)
  endif

  ifeq ($(SUFFIX),asan-ubsan)
    $(error CONFIG=asan-ubsan is not supported for windows-x64-msvc presets)
  endif
  ifeq ($(SUFFIX),tsan)
    $(error CONFIG=tsan is not supported for windows-x64-msvc presets)
  endif
endif

# Derive the vcpkg triplet from platform to match CMakePresets.json
ifeq ($(UNAME_S),Darwin)
  ifeq ($(UNAME_M),arm64)
    VCPKG_TRIPLET := arm64-osx
  else ifeq ($(UNAME_M),x86_64)
    VCPKG_TRIPLET := x64-osx
  else
    $(error Unsupported macOS arch '$(UNAME_M)')
  endif
else ifeq ($(UNAME_S),Linux)
  VCPKG_TRIPLET := x64-linux
else
  # Windows/MSYS/Git Bash/Cygwin (probably)
  VCPKG_TRIPLET := x64-windows
endif

.PHONY: configure build run clean

configure:
	cmake --preset $(CMAKE_CONFIGURE_PRESET)
	bash ./scripts/sync_compile_commands.sh $(BUILD_DIR)

build: configure
	cmake --build $(BUILD_DIR)

run: build
	cmake --build $(BUILD_DIR) --target run

clean:
	rm -rf build

