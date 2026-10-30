package game

import "base:runtime"
import "core:c"
import "core:fmt"
import "core:math/rand"
import "core:slice"

import sdl "vendor:sdl3"
import img "vendor:sdl3/image"
import ttf "vendor:sdl3/ttf"

init_test_instructions :: proc() {
    state := get_state()

    init_array_state(&state.array_state, 6)
    li, ri: int = 1, 3
    append(&state.array_instructions, ArrayInstruction{.Compare, li, ri})
    append(&state.array_instructions, ArrayInstruction{.Swap, li, ri})

    li, ri = 2, 4
    append(&state.array_instructions, ArrayInstruction{.Compare, li, ri})
    append(&state.array_instructions, ArrayInstruction{.Swap, li, ri})

    li, ri = 0, 5
    append(&state.array_instructions, ArrayInstruction{.Compare, li, ri})
    append(&state.array_instructions, ArrayInstruction{.Swap, li, ri})
}

@(export)
app_init :: proc "c" (appstate: ^rawptr, argc: c.int, argv: [^]cstring) -> sdl.AppResult {
    context = runtime.default_context()
    state := get_state()

    if !sdl.Init({.VIDEO}) {
        fmt.printfln("%s", sdl.GetError())
        return .FAILURE
    }

    if !ttf.Init() {
        fmt.printfln("%s", sdl.GetError())
        return .FAILURE
    }

    if !sdl.CreateWindowAndRenderer(
        "Odin Thing",
        854, 480, {.RESIZABLE},
        &state.wn, &state.rr
    ) {
        fmt.printfln("%s", sdl.GetError())
        return .FAILURE
    }

    // fonts and stuff
    state.tt = ttf.CreateRendererTextEngine(state.rr)
    if state.tt == nil {
        fmt.printfln("%s", sdl.GetError())
        return .FAILURE
    }

    sdl.SetHint(sdl.HINT_MAIN_CALLBACK_RATE, "60") // 60 fps cap
    now := sdl.GetPerformanceCounter()
    state.last_fps_update = now
    state.last_frame      = now
    state.frame_start     = now

    // textures
    state.textures = make([dynamic]^sdl.Texture, 8, 8)
    state.textures[TextureID.BgImage] = img.LoadTexture(state.rr, "assets/O108_rocket.jpg")
    sdl.SetTextureBlendMode(get_texture(.BgImage), {.BLEND})

    // fonts
    state.fonts = make([dynamic]^ttf.Font, 8, 8)
    state.fonts[FontID.Main] = ttf.OpenFont("assets/font_1.ttf", 20.0)

    // text objects
    state.texts = make([dynamic]^ttf.Text, 8, 8)
    state.texts[TextID.QuittingText] = ttf.CreateText(state.tt, get_font(.Main), cstring("Quitting"), 0)
    state.texts[TextID.DebugInfo]  = ttf.CreateText(state.tt, get_font(.Main), cstring(""), 0)

    state.texts[TextID.Title] = ttf.CreateText(state.tt, get_font(.Main), cstring("I am so fucking tired...\nsdkfgjkakjghakjg"), 0)
    state.texts[TextID.Dynamic]  = ttf.CreateText(state.tt, get_font(.Main), cstring(""), 0)

    // thingies
    state.playback_speed = 1.0

    init_array_state(&state.unsorted, 6)
    rand.shuffle(state.unsorted)
    state.array_state = slice.clone(state.unsorted)
    bubble_sort(state.array_state, &state.array_instructions)

    free_all(context.temp_allocator)
    return .CONTINUE
}
