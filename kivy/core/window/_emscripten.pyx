'''Display metrics and soft keyboard of the browser page (emscripten only).

.. versionadded:: 3.0.0
'''

__all__ = ('get_density', 'get_dpi', 'get_fontscale', 'watch_pixel_ratio',
           'show_keyboard', 'hide_keyboard', 'poll_keyboard',
           'get_keyboard_height')

import json

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

    /* hidden <input>: opens the soft keyboard, queues IME text for Kivy */
    static void kivy_keyboard_setup(void) {
        EM_ASM({(() => {
            const K = globalThis.__kivyKeyboard = globalThis.__kivyKeyboard || {
                queue: [], wanted: false, requested: 0, down: 0, sdlText: false, composing: false};
            if (K.input) return;
            const input = K.input = document.createElement("input");
            input.setAttribute("aria-hidden", "true");
            input.style.cssText = "position:fixed;left:0;top:0;width:1px;height:1px;opacity:0;"
                + "border:0;padding:0;margin:0;font-size:16px;pointer-events:none;caret-color:transparent";
            document.body.appendChild(input);
            K.reset = () => {
                if (K.composing) return;
                input.value = " ";
                input.setSelectionRange(1, 1);
            };
            input.addEventListener("keydown", () => { K.sdlText = false; });
            input.addEventListener("keypress", () => { K.sdlText = true; });
            input.addEventListener("beforeinput", (e) => {
                const type = e.inputType;
                if (type === "insertCompositionText") return;
                if (type === "insertText" || type === "insertReplacementText") {
                    if (!K.sdlText && e.data) K.queue.push(["text", e.data]);
                } else if (type === "deleteContentBackward") {
                    K.queue.push(["key", "backspace"]);
                } else if (type === "insertLineBreak" || type === "insertParagraph") {
                    K.queue.push(["key", "enter"]);
                }
                K.sdlText = false;
                if (e.cancelable) e.preventDefault();
            });
            input.addEventListener("compositionstart", () => { K.composing = true; });
            input.addEventListener("compositionupdate", (e) => { K.queue.push(["edit", e.data || ""]); });
            input.addEventListener("compositionend", (e) => {
                K.composing = false;
                K.queue.push(["edit", ""]);
                if (e.data) K.queue.push(["text", e.data]);
                setTimeout(K.reset);
            });
            input.addEventListener("input", K.reset);
            document.addEventListener("pointerdown", () => { K.down = performance.now(); }, true);
            document.addEventListener("mousedown", (e) => {
                if (K.wanted && e.target !== input) e.preventDefault();
            }, true);
            const refocus = () => {
                if (K.wanted && document.activeElement !== input && K.requested > K.down)
                    input.focus({preventScroll: true});
            };
            document.addEventListener("pointerup", refocus, true);
            document.addEventListener("touchend", refocus, true);
            if (globalThis.visualViewport)
                visualViewport.addEventListener("resize", () => K.queue.push(["height", ""]));
        })();});
    }

    static void kivy_keyboard_show(int type, int suggestions) {
        EM_ASM({((type, suggestions) => {
            const K = globalThis.__kivyKeyboard;
            const input = K.input;
            input.setAttribute("inputmode", ["text", "decimal", "tel", "email", "url", "none"][type]);
            input.setAttribute("autocomplete", "off");
            input.setAttribute("autocapitalize", "off");
            input.setAttribute("autocorrect", suggestions ? "on" : "off");
            input.spellcheck = !!suggestions;
            K.wanted = true;
            K.requested = performance.now();
            K.reset();
            input.focus({preventScroll: true});
        })($0, $1);}, type, suggestions);
    }

    static void kivy_keyboard_hide(void) {
        EM_ASM({(() => {
            const K = globalThis.__kivyKeyboard;
            if (!K || !K.input) return;
            K.wanted = false;
            K.composing = false;
            K.input.blur();
        })();});
    }

    static int kivy_keyboard_poll(char *buf, int size) {
        return EM_ASM_INT({return ((buf, size) => {
            const K = globalThis.__kivyKeyboard;
            if (!K || !K.queue.length) return 0;
            const bytes = new TextEncoder().encode(JSON.stringify(K.queue.splice(0)));
            if (bytes.length >= size) return 0;
            HEAPU8.set(bytes, buf);
            return bytes.length;
        })($0, $1);}, buf, size);
    }

    static double kivy_keyboard_height(void) {
        return EM_ASM_DOUBLE({return (() => {
            const K = globalThis.__kivyKeyboard;
            const vv = globalThis.visualViewport;
            if (!K || !K.wanted || !vv || document.activeElement !== K.input) return 0;
            return Math.max(0, innerHeight - vv.height - vv.offsetTop);
        })();});
    }
    """
    double emscripten_get_device_pixel_ratio()
    double kivy_fontscale()
    void kivy_watch_pixel_ratio()
    void kivy_keyboard_setup()
    void kivy_keyboard_show(int type, int suggestions)
    void kivy_keyboard_hide()
    int kivy_keyboard_poll(char *buf, int size)
    double kivy_keyboard_height()


cdef bint _watching = False
cdef bint _keyboard_ready = False
_input_modes = {'number': 1, 'tel': 2, 'mail': 3, 'url': 4, 'null': 5}


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


def show_keyboard(input_type='text', keyboard_suggestions=True):
    '''Focuses the hidden input, which opens the soft keyboard on phones
    and tablets.'''
    global _keyboard_ready
    if not _keyboard_ready:
        _keyboard_ready = True
        kivy_keyboard_setup()
    kivy_keyboard_show(_input_modes.get(input_type, 0), keyboard_suggestions)


def hide_keyboard():
    if _keyboard_ready:
        kivy_keyboard_hide()


def poll_keyboard():
    '''What the soft keyboard sent since the last call: ``(kind, value)``
    with kind ``text``, ``edit`` (IME composition), ``key`` (``backspace``,
    ``enter``) or ``height`` (the keyboard moved).'''
    cdef char buf[16384]
    cdef int n = kivy_keyboard_poll(buf, sizeof(buf))
    return json.loads(buf[:n].decode('utf-8')) if n > 0 else ()


def get_keyboard_height():
    '''How far the soft keyboard covers the page, in window pixels.'''
    return kivy_keyboard_height() * get_density()
