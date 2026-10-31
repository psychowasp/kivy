// SDL's JS calls these by name, a side module doesn't expose them
#include <emscripten.h>
#include <stddef.h>

extern void *SDL_malloc(size_t size);
extern void SDL_free(void *mem);
extern void Emscripten_SendSystemThemeChangedEvent(void);
extern void requestFullscreenThroughSDL(void *window);
extern void Emscripten_HandlePointerEnter(void *data, const void *event);
extern void Emscripten_HandlePointerLeave(void *data, const void *event);
extern void Emscripten_HandlePointerGeneric(void *data, const void *event);
extern void Emscripten_HandleMouseButtonUpGlobal(void *device, const void *event);
extern void Emscripten_SendDragEvent(void *data, const void *event);
extern void Emscripten_SendDragCompleteEvent(void *data);
extern void Emscripten_SendDragTextEvent(void *data, char *text);
extern void Emscripten_SendDragFileEvent(void *data, char *filename);
extern void Emscripten_HandleLockKeysCheck(void *data, int caps, int num, int scroll);

__attribute__((constructor)) static void kivy_sdl_js_exports(void)
{
    static void *fns[] = {
        (void *)SDL_malloc,
        (void *)SDL_free,
        (void *)Emscripten_SendSystemThemeChangedEvent,
        (void *)requestFullscreenThroughSDL,
        (void *)Emscripten_HandlePointerEnter,
        (void *)Emscripten_HandlePointerLeave,
        (void *)Emscripten_HandlePointerGeneric,
        (void *)Emscripten_HandleMouseButtonUpGlobal,
        (void *)Emscripten_SendDragEvent,
        (void *)Emscripten_SendDragCompleteEvent,
        (void *)Emscripten_SendDragTextEvent,
        (void *)Emscripten_SendDragFileEvent,
        (void *)Emscripten_HandleLockKeysCheck,
    };
    EM_ASM({
        ([
            "SDL_malloc", "SDL_free",
            "Emscripten_SendSystemThemeChangedEvent", "requestFullscreenThroughSDL",
            "Emscripten_HandlePointerEnter", "Emscripten_HandlePointerLeave",
            "Emscripten_HandlePointerGeneric", "Emscripten_HandleMouseButtonUpGlobal",
            "Emscripten_SendDragEvent", "Emscripten_SendDragCompleteEvent",
            "Emscripten_SendDragTextEvent", "Emscripten_SendDragFileEvent",
            "Emscripten_HandleLockKeysCheck",
        ]).forEach((name, i) => {
            globalThis["_" + name] = wasmTable.get(HEAPU32[($0 >> 2) + i]);
        });
    }, fns);
}
