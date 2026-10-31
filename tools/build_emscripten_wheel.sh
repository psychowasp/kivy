#!/bin/bash
# Pyodide wheel. Run tools/build_emscripten_dependencies.sh first.
set -e -x

export KIVY_DEPS_ROOT="${KIVY_DEPS_ROOT:-$(pwd)/kivy-dependencies}"
export KIVY_SPLIT_EXAMPLES="${KIVY_SPLIT_EXAMPLES:-1}"
OUT="${1:-dist-wasm}"

rm -f "$OUT"/kivy-*.whl
rm -rf build/*emscripten*
pyodide build -o "$OUT"

# sdl side module at site-packages root, found via pyodide's LD_LIBRARY_PATH
python3 - "$OUT"/kivy-*.whl "$KIVY_DEPS_ROOT/dist/wasm/libkivy_sdl3.so" <<'PY'
import base64, hashlib, os, sys, zipfile
whl, lib = sys.argv[1:]
name, data = os.path.basename(lib), open(lib, 'rb').read()
digest = base64.urlsafe_b64encode(hashlib.sha256(data).digest()).rstrip(b'=').decode()
with zipfile.ZipFile(whl) as z:
    items = [(i, z.read(i)) for i in z.infolist()]
with zipfile.ZipFile(whl, 'w', zipfile.ZIP_DEFLATED) as z:
    for info, content in items:
        if info.filename.endswith('.dist-info/RECORD'):
            z.writestr(name, data)
            content += f'{name},sha256={digest},{len(data)}\n'.encode()
        z.writestr(info, content)
PY
ls -l "$OUT"
