package main

import "base:runtime"
import sdl "vendor:sdl3"

import "game"

main :: proc() {
    sdl.EnterAppMainCallbacks(
        i32(len(runtime.args__)),
        raw_data(runtime.args__),
        game.app_init,
        game.app_iter,
        game.app_event,
        game.app_quit
    )
}
