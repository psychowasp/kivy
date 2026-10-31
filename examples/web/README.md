# Kivy in the browser (Pyodide)

Build (needs `pyodide-build`, cmake, ninja, meson):

    pip install pyodide-build
    tools/build_emscripten_dependencies.sh   # SDL3 + ThorVG for wasm
    tools/build_emscripten_wheel.sh          # -> dist-wasm/kivy-*.whl

Run:

    mkdir -p examples/web/wheels && cp dist-wasm/kivy-*.whl examples/web/wheels/
    cd examples && python -m http.server

Open http://localhost:8000/web/ or any example, e.g.
http://localhost:8000/web/?app=../shader/shadertree.py (the app's folder is
copied into the FS, needs a server with directory listings).

`App.run()` doesn't block in the browser, it schedules `async_run()` on
Pyodide's event loop. A resizable window fills the page; set
`Config.set('graphics', 'resizable', 0)` for a fixed size canvas.
