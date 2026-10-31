'''Display metrics of the browser page (emscripten only).

.. versionadded:: 3.0.0
'''

__all__ = ('get_density', 'get_dpi', 'get_fontscale', 'watch_pixel_ratio')

cdef extern from *:
    """
    #include <emscripten/em_asm.h>
    #include <emscripten/html5.h>

    static double kivy_fontscale(void) {
        return EM_ASM_DOUBLE({
            if (typeof document === "undefined") return 1;
            const el = document.createElement("div");
            el.style.fontSize = "medium";
            document.body.appendChild(el);
            const size = parseFloat(getComputedStyle(el).fontSize);
            el.remove();
            return size / 16 || 1;
        });
    }

    static void kivy_watch_pixel_ratio(void) {
        EM_ASM({
            const watch = () => matchMedia("(resolution: " + devicePixelRatio + "dppx)")
                .addEventListener("change", () => {
                    window.dispatchEvent(new Event("resize"));
                    watch();
                }, {once: true});
            watch();
        });
    }
    """
    double emscripten_get_device_pixel_ratio()
    double kivy_fontscale()
    void kivy_watch_pixel_ratio()


cdef bint _watching = False


def get_density():
    '''Device pixels per CSS pixel (``devicePixelRatio``).'''
    cdef double ratio = emscripten_get_device_pixel_ratio()
    return ratio if ratio > 0 else 1.0


def get_dpi():
    '''96 DPI per CSS pixel, as CSS defines it.'''
    return 96. * get_density()


def get_fontscale():
    '''The browser's default font size, relative to 16px.'''
    return kivy_fontscale()


def watch_pixel_ratio():
    '''Sends the page a resize when ``devicePixelRatio`` changes (zoom,
    another screen), so SDL resizes the canvas and Kivy updates its
    metrics.'''
    global _watching
    if not _watching:
        _watching = True
        kivy_watch_pixel_ratio()
