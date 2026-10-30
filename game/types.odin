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
    DebugInfo,
    Dynamic
}

// thingies
ArrayInstruction :: struct {
    type: enum u8 { None, Compare, CompareFalse, Swap },
    lhs, rhs: int
}
