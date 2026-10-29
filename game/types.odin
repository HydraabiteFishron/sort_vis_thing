package game

Vec2 :: [2]f32

// stuff
TextureID :: enum u8 {
    BgImage
}

FontID :: enum u8 {
    Main
}

TextID :: enum u8 {
    QuittingText,
    Title,
    DebugInfo
}

// thingies
ArrayInstruction :: struct {
    type: enum u8 { Compare, Swap },
    lhs, rhs: int
}
