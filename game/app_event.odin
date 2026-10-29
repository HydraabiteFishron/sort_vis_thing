package game

import "base:runtime"
import sdl "vendor:sdl3"

@(export)
app_event :: proc "c" (appstate: rawptr, ev: ^sdl.Event) -> sdl.AppResult {
    context = runtime.default_context()
    state := get_state()
    kb := sdl.GetKeyboardState(nil)

    #partial switch ev.type {
    case .QUIT:
        return .SUCCESS

    case .KEY_DOWN:
        key := ev.key.key
        switch key {
        case sdl.K_ESCAPE:
            if kb[sdl.Scancode.RSHIFT] { return .SUCCESS }

        case sdl.K_RETURN:
            if state.playback_state == .Finished {
                state.current_instruction_idx = 0
                state.playback_state = .Playing
                state.playback_elapsed = 0
                break
            }

            state.playback_state = .Playing if state.playback_state == .Paused else .Paused
        }
    }

    free_all(context.temp_allocator)
    return .CONTINUE
}
