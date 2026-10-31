#!/bin/bash
# SDL3 + satellites + ThorVG for Pyodide. Needs pyodide-build, cmake, ninja, meson.
set -e -x

SDL3_VERSION="3.4.0"
SDL3_IMAGE_VERSION="3.2.6"
SDL3_MIXER_VERSION="3.2.0"
SDL3_TTF_VERSION="3.2.2"

_SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(pwd)/kivy-dependencies"
DIST="$ROOT/dist"
BUILD="$ROOT/build"
DOWNLOAD="$ROOT/download"

if [ -n "$PYODIDE_VERSION" ]; then
  pyodide xbuildenv install "$PYODIDE_VERSION"
fi
EMSDK_DIR="$(pyodide config get emsdk_dir)"
if [ ! -f "$EMSDK_DIR/emsdk_env.sh" ]; then
  pyodide xbuildenv install-emscripten
fi
source "$EMSDK_DIR/emsdk_env.sh"

WASM_FLAGS="$(pyodide config get cxxflags | sed -E 's/-sSUPPORT_LONGJMP( |$)/-sSUPPORT_LONGJMP=wasm\1/')"
WASM_LDFLAGS="$(pyodide config get ldflags)"

mkdir -p "$DIST" "$BUILD" "$DOWNLOAD"

_fetch() {
  local name="$1" url="$2"
  [ -f "$DOWNLOAD/$name.tar.gz" ] || curl -fL "$url" -o "$DOWNLOAD/$name.tar.gz"
  [ -d "$BUILD/$name" ] || tar -xzf "$DOWNLOAD/$name.tar.gz" -C "$BUILD"
}

_clone_external() {
  local src="$1" path="$2"
  [ -d "$src/$path" ] && [ -n "$(ls -A "$src/$path")" ] && return
  rm -rf "$src/$path"
  local url branch
  url=$(git config -f "$src/.gitmodules" "submodule.$path.url")
  branch=$(git config -f "$src/.gitmodules" "submodule.$path.branch")
  git clone --depth 1 --filter=blob:none -b "$branch" "$url" "$src/$path"
}

_cmake() {
  local src="$1"
  shift
  emcmake cmake -S "$src" -B "$src/build-wasm" -GNinja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$DIST" \
    -DCMAKE_PREFIX_PATH="$DIST" \
    -DCMAKE_FIND_ROOT_PATH="$DIST" \
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
    -DBUILD_SHARED_LIBS=OFF \
    -DCMAKE_C_FLAGS="$WASM_FLAGS -include $RENAME_H" \
    -DCMAKE_CXX_FLAGS="$WASM_FLAGS -include $RENAME_H" \
    -DSDL3_DIR="$DIST/lib/cmake/SDL3" \
    "$@"
  cmake --build "$src/build-wasm" --parallel
  cmake --install "$src/build-wasm"
}

_fetch "SDL3-$SDL3_VERSION" \
  "https://github.com/libsdl-org/SDL/releases/download/release-$SDL3_VERSION/SDL3-$SDL3_VERSION.tar.gz"
_fetch "SDL3_image-$SDL3_IMAGE_VERSION" \
  "https://github.com/libsdl-org/SDL_image/releases/download/release-$SDL3_IMAGE_VERSION/SDL3_image-$SDL3_IMAGE_VERSION.tar.gz"
_fetch "SDL3_mixer-$SDL3_MIXER_VERSION" \
  "https://github.com/libsdl-org/SDL_mixer/releases/download/release-$SDL3_MIXER_VERSION/SDL3_mixer-$SDL3_MIXER_VERSION.tar.gz"
_fetch "SDL3_ttf-$SDL3_TTF_VERSION" \
  "https://github.com/libsdl-org/SDL_ttf/releases/download/release-$SDL3_TTF_VERSION/SDL3_ttf-$SDL3_TTF_VERSION.tar.gz"

# SharedArrayBuffer is undefined without cross-origin isolation
perl -pi -e 's/if \(pngData\.buffer instanceof SharedArrayBuffer\)/if (typeof SharedArrayBuffer !== "undefined" && pngData.buffer instanceof SharedArrayBuffer)/' \
  "$BUILD/SDL3-$SDL3_VERSION/src/video/emscripten/SDL_emscriptenvideo.c"

# pyodide main links emscripten's JS SDL, rename clashing SDL3 API
RENAME_H="$DIST/include/kivy_sdl_rename.h"
mkdir -p "$DIST/include"
python3 - "$(pyodide config get dist_dir)/pyodide.asm.js" "$RENAME_H" \
  "$BUILD"/SDL3-*/include/SDL3/*.h "$BUILD"/SDL3_*/include/SDL3_*/*.h <<'EOF'
import re, sys
taken = set(re.findall(r'\b(?:var|function) _(\w+)', open(sys.argv[1]).read()))
api, macros = set(), set()
for h in sys.argv[3:]:
    src = open(h).read()
    api |= set(re.findall(r'SDLCALL\s+(\w+)\s*\(', src))
    macros |= set(re.findall(r'#\s*define\s+(\w+)', src))
with open(sys.argv[2], 'w') as f:
    f.write('#pragma once\n')
    f.writelines(f'#define {n} kivy_{n}\n' for n in sorted((api & taken) - macros))
EOF

_cmake "$BUILD/SDL3-$SDL3_VERSION" \
  -DSDL_SHARED=OFF -DSDL_STATIC=ON \
  -DSDL_TEST_LIBRARY=OFF -DSDL_TESTS=OFF -DSDL_EXAMPLES=OFF

_cmake "$BUILD/SDL3_image-$SDL3_IMAGE_VERSION" \
  -DSDLIMAGE_VENDORED=OFF -DSDLIMAGE_DEPS_SHARED=OFF \
  -DSDLIMAGE_AVIF=OFF -DSDLIMAGE_JXL=OFF -DSDLIMAGE_TIF=OFF -DSDLIMAGE_WEBP=OFF \
  -DSDLIMAGE_SAMPLES=OFF -DSDLIMAGE_TESTS=OFF

_cmake "$BUILD/SDL3_mixer-$SDL3_MIXER_VERSION" \
  -DSDLMIXER_VENDORED=OFF -DSDLMIXER_DEPS_SHARED=OFF \
  -DSDLMIXER_FLAC_LIBFLAC=OFF -DSDLMIXER_GME=OFF -DSDLMIXER_MOD=OFF \
  -DSDLMIXER_MP3_MPG123=OFF -DSDLMIXER_MIDI_FLUIDSYNTH=OFF -DSDLMIXER_OPUS=OFF \
  -DSDLMIXER_VORBIS_VORBISFILE=OFF -DSDLMIXER_WAVPACK=OFF \
  -DSDLMIXER_TESTS=OFF -DSDLMIXER_EXAMPLES=OFF

_TTF_SRC="$BUILD/SDL3_ttf-$SDL3_TTF_VERSION"
_clone_external "$_TTF_SRC" external/freetype
_clone_external "$_TTF_SRC" external/harfbuzz
_cmake "$_TTF_SRC" \
  -DSDLTTF_VENDORED=ON -DSDLTTF_HARFBUZZ=ON -DSDLTTF_PLUTOSVG=OFF \
  -DFT_DISABLE_PNG=ON -DSDLTTF_SAMPLES=OFF

# native html5 bits pyodide's main module lacks
_HTML5="$(pyodide config get emscripten_dir)/system/lib/html5"
emcc $WASM_FLAGS -c "$_HTML5/dom_pk_codes.c" -o "$BUILD/dom_pk_codes.o"
emcc $WASM_FLAGS -c "$_HTML5/key_codes.c" -o "$BUILD/key_codes.o"
emcc $WASM_FLAGS -c "$_SCRIPT_DIR/emscripten_sdl_js_exports.c" -o "$BUILD/sdl_js_exports.o"

# one side module, shared by every kivy extension
mkdir -p "$DIST/wasm"
emcc $WASM_LDFLAGS -o "$DIST/wasm/libkivy_sdl3.so" \
  "$BUILD/dom_pk_codes.o" "$BUILD/key_codes.o" "$BUILD/sdl_js_exports.o" \
  -Wl,--whole-archive \
  "$DIST/lib/libSDL3.a" "$DIST/lib/libSDL3_image.a" \
  "$DIST/lib/libSDL3_mixer.a" "$DIST/lib/libSDL3_ttf.a" \
  -Wl,--no-whole-archive

THORVG_EMSCRIPTEN=1 THORVG_INSTALL_PREFIX="$DIST" \
  THORVG_BUILD_ROOT="$BUILD/thorvg" bash "$_SCRIPT_DIR/build_thorvg.sh"

ls -l "$DIST/lib" "$DIST/wasm"
