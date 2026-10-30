package game

import "core:math/rand"

import sdl "vendor:sdl3"
import ttf "vendor:sdl3/ttf"

GAME_TITLE :: "Sort Visualizer Odin Thing"

State :: struct {
    wn: ^sdl.Window,
    rr: ^sdl.Renderer,
    tt: ^ttf.TextEngine,

    wn_size: Vec2,

    last_frame, frame_start,
    last_fps_update, frame_counter: u64,

    dt,
    fps: f32,

    quit_held: f32,

    // stuff
    textures: [dynamic]^sdl.Texture,
    fonts: [dynamic]^ttf.Font,
    texts: [dynamic]^ttf.Text,

    // thingies
    unsorted: []int,
    array_state: []int,
    array_instructions: [dynamic]ArrayInstruction,
    current_instruction_idx: int,

    playback_state: enum u8 { Paused, Playing, Finished },
    playback_elapsed,
    playback_speed: f32,
}

g_state: State

// stuff
get_state :: proc() -> ^State {
    return &g_state
}

get_texture :: proc(id: TextureID) -> ^sdl.Texture {
    return g_state.textures[id]
}

get_font :: proc(id: FontID) -> ^ttf.Font {
    return g_state.fonts[id]
}

get_text :: proc(id: TextID) -> ^ttf.Text {
    return g_state.texts[id]
}

