"""cibuildwheel repair for Kivy's Pyodide wheel: libkivy_sdl3.so at the
site-packages root, where Pyodide's LD_LIBRARY_PATH finds it.

    emscripten_repair_wheel.py {wheel} {dest_dir}
"""
import base64
import hashlib
import os
import sys
import zipfile

wheel, dest = sys.argv[1:]
lib = os.path.join(os.environ.get('KIVY_DEPS_ROOT', 'kivy-dependencies'), 'dist', 'wasm', 'libkivy_sdl3.so')
name, data = os.path.basename(lib), open(lib, 'rb').read()
digest = base64.urlsafe_b64encode(hashlib.sha256(data).digest()).rstrip(b'=').decode()
os.makedirs(dest, exist_ok=True)
with zipfile.ZipFile(wheel) as zin, \
        zipfile.ZipFile(os.path.join(dest, os.path.basename(wheel)), 'w', zipfile.ZIP_DEFLATED) as zout:
    for info in zin.infolist():
        content = zin.read(info)
        if info.filename.endswith('.dist-info/RECORD'):
            zout.writestr(name, data)
            content += f'{name},sha256={digest},{len(data)}\n'.encode()
        zout.writestr(info, content)
