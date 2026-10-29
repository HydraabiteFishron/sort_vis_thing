package game

import "base:runtime"
import "core:fmt"
import "core:math"
import "core:math/ease"
import str "core:strings"

import sdl "vendor:sdl3"
import ttf "vendor:sdl3/ttf"

debug_info: str.Builder
add_debug_info :: proc(text: string) {
    str.write_string(&debug_info, text)
    str.write_byte(&debug_info, '\n')
}

stopwatch: f32
draw_easing_tests :: proc() {
    state := get_state()
    dt := state.dt
    rr := state.rr

    DURATION :: 0.38
    t := min(stopwatch / DURATION, 1.0)

    ease_out_back :: proc(t: f32, c1: f32 = 1.70158) -> f32 {
        t_clamped := math.clamp(t, 0.0, 1.0)
        c3 := c1 + 1.0
        
        f := t_clamped - 1.0
        return 1.0 + c3 * (f * f * f) + c1 * (f * f)
    }

    eases := [?]f32{
        t,
        ease.ease(.Back_Out, t),
        ease_out_back(t),
        ease.quadratic_out(t),
        ease.cubic_out(t),
    }

    dsts := [len(eases)]sdl.FRect{}
    for &dst, i in dsts {
        dst.w = 50.0
        dst.h = 50.0
        dst.y = 60.0 * f32(i)

        start_x: f32 = 0
        end_x: f32 = 300.0
        dst.x = math.lerp(start_x, end_x, eases[i])
    }

    sdl.SetRenderDrawColor(rr, 106, 193, 204, 64)
    for &dst, i in dsts {
        sdl.RenderFillRect(rr, &dst)
    }

    stopwatch += dt
}

@(export)
app_iter :: proc "c" (appstate: rawptr) -> sdl.AppResult {
    context = runtime.default_context()
    state := get_state()

    // dt, fps, and stuff
    perf_freq := sdl.GetPerformanceFrequency()
    state.last_frame = state.frame_start
    state.frame_start = sdl.GetPerformanceCounter()
    state.dt = f32(state.frame_start - state.last_frame) / f32(perf_freq)

    state.frame_counter += 1
    fps_update_delta := f32(state.frame_start - state.last_fps_update) / f32(perf_freq)
    if fps_update_delta >= 1.0 {
        state.fps = f32(state.frame_counter) / fps_update_delta
        state.frame_counter = 0
        state.last_fps_update = state.frame_start

        new_wn_title := fmt.ctprintf("%s :: FPS(%.2f) DTms(%.2f)",
                                     GAME_TITLE,
                                     state.fps,
                                     state.dt * 1000.0)
        sdl.SetWindowTitle(state.wn, new_wn_title)
    }

    // get wn_size in a paranoid manner
    {
        w, h: i32
        if sdl.GetWindowSize(state.wn, &w, &h) { state.wn_size = { f32(w), f32(h) } }
    }

    // quit hold
    kb := sdl.GetKeyboardState(nil)
    QUIT_HOLD_DURATION :f32: 1.25
    if kb[sdl.Scancode.ESCAPE] {
        state.quit_held += state.dt

        if state.quit_held >= QUIT_HOLD_DURATION {
            return .SUCCESS
        }
    } else {
        state.quit_held = 0.0
    }

    // copies
    dt := state.dt
    rr := state.rr
    wns := state.wn_size

    // updates
    INSTRUCTION_DURATION :: 1.0
    // INSTRUCTION_DURATION :: (1.0/240.0)
    active_instruction: ArrayInstruction
    if state.playback_state == .Playing {
        // aliases / copies
        elapsed := state.playback_elapsed
        arr := &state.array_state
        instructions := &state.array_instructions
        curr_idx := state.current_instruction_idx

        for curr_idx < len(instructions) {
            next_idx := curr_idx + 1
            active_instruction = instructions[curr_idx]

            until_next := INSTRUCTION_DURATION * f32(next_idx) - elapsed
            if until_next > 0.0 { break }

            // perform swap before switching to next
            if active_instruction.type == .Swap {
                // there was some tomfoolery that happened
                // fmt.printfln("swap %d | %d: %d, %d",
                //              curr_idx, state.current_instruction_idx,
                //              active_instruction.lhs, active_instruction.rhs)

                tmp := arr[active_instruction.lhs]
                arr[active_instruction.lhs] = arr[active_instruction.rhs]
                arr[active_instruction.rhs] = tmp
            }

            state.current_instruction_idx = next_idx
            curr_idx = state.current_instruction_idx
        }
        if curr_idx >= len(instructions) { state.playback_state = .Finished }
        else { state.playback_elapsed += dt }
        // else { state.playback_elapsed += dt * 0.25 }
    } else if state.playback_state == .Paused {
        active_instruction = state.array_instructions[state.current_instruction_idx]
    }

    sdl.SetRenderDrawColor(rr, 22, 22, 30, 255)
    sdl.RenderClear(rr)

    { // render bg
        tw, th: f32
        bg_image := get_texture(TextureID.BgImage)
        sdl.GetTextureSize(bg_image, &tw, &th)

        dst := sdl.FRect{}
        dst.h = wns.y
        dst.w = dst.h * tw /th

        if dst.w < wns.x {
            dst.w = wns.x
            dst.h = dst.w * th / tw
        }

        dst.x = wns.x / 2.0 - dst.w / 2.0
        dst.y = wns.y / 2.0 - dst.h / 2.0

        sdl.SetTextureAlphaMod(bg_image, 26)
        sdl.RenderTexture(rr, bg_image, nil, &dst)
    }
    
    TITLE_HEIGHT :: 69.0
    { // render title
        dst := sdl.FRect{ w=wns.x, h=TITLE_HEIGHT }
        sdl.SetRenderDrawBlendMode(rr, {.BLEND})
        sdl.SetRenderDrawColor(rr, 0, 0, 0, 128)
        sdl.RenderFillRect(rr, &dst)
        sdl.SetRenderDrawBlendMode(rr, {})

        text := get_text(.Title)
        w, h: i32; ttf.GetTextSize(text, &w, &h)
        x: f32 = wns.x / 2.0 - f32(w) / 2.0
        y: f32 = (TITLE_HEIGHT - f32(h)) / 2.0


        ttf.SetFontWrapAlignment(get_font(.Main), .CENTER)
        ttf.DrawRendererText(text, x, y)
    }

    // render stair thing
    WIDTH_PAD :: 10.0
    TOP_PAD :: 30.0
    MAX_HEIGHT := wns.y - TITLE_HEIGHT - TOP_PAD
    for elem, i in state.array_state {
        if  state.playback_state != .Finished &&
            (i == active_instruction.lhs || i == active_instruction.rhs) {
            continue
        }

        array_len := f32(len(state.array_state))
        dst := sdl.FRect{}
        dst.w = wns.x / array_len - WIDTH_PAD
        dst.h = MAX_HEIGHT * (f32(elem) / array_len)

        dst.x = wns.x * (f32(i) / array_len) + WIDTH_PAD / 2.0
        dst.y = wns.y - dst.h

        if      state.playback_state == .Playing  { sdl.SetRenderDrawColor(rr, 255, 255, 255, 255) }
        else if state.playback_state == .Finished { sdl.SetRenderDrawColor(rr,   0, 255,   0, 255) }
                                             else { sdl.SetRenderDrawColor(rr, 169, 169, 169, 255) }

        sdl.RenderFillRect(rr, &dst)
    }

    // draw the animated swap
    WIDTH_STRETCH :: 4.0
    HEIGHT_STRETCH :: 20.0
    if  active_instruction.type == .Swap &&
        state.playback_state != .Finished
    {
        elapsed := state.playback_elapsed
        array := &state.array_state
        array_len := f32(len(state.array_state))
        lhs_idx := active_instruction.lhs
        rhs_idx := active_instruction.rhs


        SWAP_DUR :: 0.35
        next_idx := state.current_instruction_idx + 1
        until_next := INSTRUCTION_DURATION - (INSTRUCTION_DURATION * f32(next_idx) - elapsed)
        until_next = min(until_next, SWAP_DUR)
        t := until_next / SWAP_DUR
        t = ease.cubic_out(t)

        // next_idx := state.current_instruction_idx + 1
        // until_next := INSTRUCTION_DURATION * f32(next_idx) - elapsed
        // t := (INSTRUCTION_DURATION - until_next) / INSTRUCTION_DURATION
        // t = ease.quartic_in_out(t)

        lhs_dst := sdl.FRect{}
        lhs_value := f32(array[lhs_idx])
        // lhs_dst.w = wns.x / array_len - 4.0

        lhs_width := wns.x / array_len - WIDTH_PAD
        lhs_width_stretch := wns.x / array_len - WIDTH_PAD + WIDTH_STRETCH
        lhs_dst.w = math.lerp(lhs_width_stretch, lhs_width, t)

        lhs_height := MAX_HEIGHT * (lhs_value / array_len)
        lhs_height_max := lhs_height + HEIGHT_STRETCH
        lhs_dst.h = math.lerp(lhs_height_max, lhs_height, t)
        lhs_dst.y = wns.y - lhs_dst.h

        lhs_start_x := (wns.x * (f32(lhs_idx) / array_len) + WIDTH_PAD / 2.0) - (lhs_dst.w - lhs_width) / 2.0
        lhs_end_x := (wns.x * (f32(rhs_idx) / array_len) + WIDTH_PAD / 2.0) - (lhs_dst.w - lhs_width) / 2.0
        // lhs_start_x := wns.x * (f32(lhs_idx) / array_len) + 2.0
        // lhs_end_x := wns.x * (f32(rhs_idx) / array_len) + 2.0

        lhs_dst.x = math.lerp(lhs_start_x, lhs_end_x, t)


        rhs_dst := sdl.FRect{}
        rhs_value := f32(array[rhs_idx])
        // rhs_dst.w = wns.x / array_len - 4.0

        rhs_width := wns.x / array_len - WIDTH_PAD
        rhs_width_stretch := wns.x / array_len - WIDTH_PAD + WIDTH_STRETCH
        rhs_dst.w = math.lerp(rhs_width_stretch, rhs_width, t)

        rhs_height := MAX_HEIGHT * (rhs_value / array_len)
        rhs_height_max := rhs_height + HEIGHT_STRETCH
        rhs_dst.h = math.lerp(rhs_height_max, rhs_height, t)
        rhs_dst.y = wns.y - rhs_dst.h

        rhs_start_x := (wns.x * (f32(rhs_idx) / array_len) + WIDTH_PAD / 2.0) - (rhs_dst.w - rhs_width) / 2.0
        rhs_end_x := (wns.x * (f32(lhs_idx) / array_len) + WIDTH_PAD / 2.0) - (rhs_dst.w - rhs_width) / 2.0

        rhs_dst.x = math.lerp(rhs_start_x, rhs_end_x, t)

        if state.playback_state == .Playing { sdl.SetRenderDrawColor(rr, 109, 229, 237, 255) }
                                       else { sdl.SetRenderDrawColor(rr,  76, 112, 145, 255) }
        sdl.RenderFillRect(rr, &lhs_dst)
        sdl.RenderFillRect(rr, &rhs_dst)

        debug_text := fmt.tprintf("instruction type: swap")
        add_debug_info(debug_text)

        debug_text = fmt.tprintf("t value: %.2f", t)
        add_debug_info(debug_text)

        debug_text = fmt.tprintf("lhs x: %.2f", lhs_dst.x)
        add_debug_info(debug_text)

        debug_text = fmt.tprintf("rhs x: %.2f", rhs_dst.x)
        add_debug_info(debug_text)
    } // draw the animated compare
    else if active_instruction.type == .Compare &&
            state.playback_state != .Finished
    {
        elapsed := state.playback_elapsed
        array := &state.array_state
        array_len := f32(len(state.array_state))

        lhs_idx := active_instruction.lhs
        rhs_idx := active_instruction.rhs
        lhs_value := f32(array[lhs_idx])
        rhs_value := f32(array[rhs_idx])

        // COMPARE_DUR :: INSTRUCTION_DURATION
        COMPARE_DUR :: 0.25

        next_idx := state.current_instruction_idx + 1
        until_next_inversed := INSTRUCTION_DURATION - (INSTRUCTION_DURATION * f32(next_idx) - elapsed)
        until_anim_finish   := min(until_next_inversed, COMPARE_DUR)
        lt := until_anim_finish / COMPARE_DUR

        // ease_return :: proc(t: f32, return_begin: f32 = 0.5) -> f32 {
        //     t := t
        //     if t < return_begin { t = 1 - math.pow(1 - t / return_begin, 2) }
        //                    else { t = 1 - math.pow((t - return_begin) / (1.0 - return_begin), 2) }
        //     return t
        // }

        lhs_dst := sdl.FRect{}

        lhs_width := wns.x / array_len - WIDTH_PAD
        lhs_width_stretch := wns.x / array_len - WIDTH_PAD + WIDTH_STRETCH

        lhs_height := MAX_HEIGHT * (lhs_value / array_len)
        lhs_height_max := lhs_height + HEIGHT_STRETCH
        lhs_height_min := max(lhs_height - 20.0, wns.y * (1 / array_len))

        rhs_dst := sdl.FRect{}

        rhs_width := wns.x / array_len - WIDTH_PAD
        rhs_width_stretch := wns.x / array_len - WIDTH_PAD + WIDTH_STRETCH

        rhs_height := MAX_HEIGHT * (rhs_value / array_len)
        rhs_height_max := rhs_height + HEIGHT_STRETCH
        // rhs_height_min := max(rhs_height - 20.0, wns.y * (1 / array_len))

        lt = ease.quartic_out(lt)
        lhs_dst.h = math.lerp(lhs_height, lhs_height_max, lt)
        lhs_dst.w = math.lerp(lhs_width, lhs_width_stretch, lt)

        // if lt < 0.5 {
        //     lt = ease_return(lt / 0.5)
        //     lhs_dst.h = math.lerp(lhs_height, lhs_height_max, lt)
        // } else {
        //     lt = ease_return((lt - 0.5) / 0.5)
        //     lhs_dst.h = math.lerp(lhs_height, lhs_height_min, lt)
        // }

        rhs_elapsed := (until_next_inversed - COMPARE_DUR)
        until_rhs_anim_finish := min(rhs_elapsed, COMPARE_DUR)
        rt := until_rhs_anim_finish / COMPARE_DUR
        if rhs_elapsed > 0.0 {
            rt = ease.quartic_out(rt)
            rhs_dst.h = math.lerp(rhs_height, rhs_height_max, rt)
            rhs_dst.w = math.lerp(rhs_width, rhs_width_stretch, rt)
            // if rt < 0.5 {
            //     rt = ease_return(rt / 0.5)
            //     rhs_dst.h = math.lerp(rhs_height, rhs_height_max, rt)
            // } else {
            //     rt = ease_return((rt - 0.5) / 0.5)
            //     rhs_dst.h = math.lerp(rhs_height, rhs_height_min, rt)
            // }
        }
        else {
            rhs_dst.h = rhs_height
            rhs_dst.w = rhs_width
        }

        lhs_dst.x = (wns.x * (f32(lhs_idx) / array_len) + WIDTH_PAD / 2.0) - (lhs_dst.w - lhs_width) / 2.0
        rhs_dst.x = (wns.x * (f32(rhs_idx) / array_len) + WIDTH_PAD / 2.0) - (rhs_dst.w - rhs_width) / 2.0
        lhs_dst.y = wns.y - lhs_dst.h
        rhs_dst.y = wns.y - rhs_dst.h

        // if      state == 0 { sdl.SetRenderDrawColor(rr, 255, 0, 0, 255) }
        // else if state == 1 { sdl.SetRenderDrawColor(rr, 0, 255, 0, 255) }
        //               else { sdl.SetRenderDrawColor(rr, 0, 0, 255, 255) }
        if state.playback_state == .Playing { sdl.SetRenderDrawColor(rr, 109, 229, 237, 255) }
                                       else { sdl.SetRenderDrawColor(rr,  76, 112, 145, 255) }
        sdl.RenderFillRect(rr, &lhs_dst)
        sdl.RenderFillRect(rr, &rhs_dst)

        debug_text := fmt.tprintf("instruction type: compare")
        add_debug_info(debug_text)

        debug_text = fmt.tprintf("t value: %.2f", lt)
        add_debug_info(debug_text)

        debug_text = fmt.tprintf("rt value: %.2f", rt)
        add_debug_info(debug_text)

        debug_text = fmt.tprintf("until_next_inversed: %.2f", until_next_inversed)
        add_debug_info(debug_text)

        debug_text = fmt.tprintf("until_anim_finish: %.2f", until_anim_finish)
        add_debug_info(debug_text)

        debug_text = fmt.tprintf("idk: %.2f", rhs_elapsed)
        add_debug_info(debug_text)
    }

    if kb[sdl.Scancode.P] { draw_easing_tests() }
    else { stopwatch = 0 }

    if len(debug_info.buf) > 0 {
        defer str.builder_reset(&debug_info)

        text_obj := get_text(.DebugInfo)
        debug_cstring := transmute(cstring)raw_data(str.to_string(debug_info))
        debug_string_len := uint(len(debug_info.buf))

        ttf.SetTextString(text_obj, debug_cstring, debug_string_len)
        w, h: i32; ttf.GetTextSize(text_obj, &w, &h)

        bg_dst := sdl.FRect{ wns.x - f32(w), wns.y - f32(h), f32(w), f32(h) }
        sdl.SetRenderDrawBlendMode(rr, {.BLEND})
        sdl.SetRenderDrawColor(rr, 0, 0, 0, 192)
        sdl.RenderFillRect(rr, &bg_dst)
        sdl.SetRenderDrawBlendMode(rr, {})

        ttf.SetFontWrapAlignment(get_font(.Main), .RIGHT)
        ttf.DrawRendererText(text_obj, bg_dst.x, bg_dst.y)
    }

    if state.quit_held > 0.0 {
        alpha: f32 = min(state.quit_held, 1.0)

        text := get_text(.QuittingText)
        ttf.SetTextColorFloat(text, 1.0, 1.0, 1.0, alpha)

        if state.quit_held >= 1.0 {
            ttf.SetTextString(text, cstring("Quitting..."), 0)
        } else if state.quit_held >= 1.0/2.0 {
            ttf.SetTextString(text, cstring("Quitting.."), 0)
        } else {
            ttf.SetTextString(text, cstring("Quitting."), 0)
        }

        w, h: i32; ttf.GetTextSize(text, &w, &h)
        text_size := Vec2{f32(w), f32(h)}

        ttf.DrawRendererText(text, 16.0, 8.0)
    }

    sdl.RenderPresent(rr)

    free_all(context.temp_allocator)
    return .CONTINUE
}
