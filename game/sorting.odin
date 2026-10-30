package game

// import "core:math/rand"
// import "core:sort"
import "core:slice"

// thingies
init_array_state :: proc(array: ^[]int, amount: uint) {
    array^ = make([]int, amount)
    for &elem, i in array {
        elem = i + 1
    }
}

bubble_sort :: proc(array: []int, instructions: ^[dynamic]ArrayInstruction) {
    clear(instructions)
    count := len(array)
    array := slice.clone(array)
    defer delete(array)

    init_j, last_j := 0, count-1

    for {
        init_swap, prev_swap := -1, -1

        for j in init_j..<last_j {
            append(instructions, ArrayInstruction{.Compare, j, j+1})

            if array[j] > array[j+1] {
                array[j], array[j+1] = array[j+1], array[j]
                prev_swap = j
                if init_swap == -1 {
                    init_swap = j
                }

                append(instructions, ArrayInstruction{.Swap, j, j+1})
            } else {
                append(instructions, ArrayInstruction{.CompareFalse, j, j+1})
            }
        }

        if prev_swap == -1 {
            return
        }

        init_j = max(init_swap-1, 0)
        last_j = prev_swap
    }
}
