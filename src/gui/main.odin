package wordle_gui

import "core:fmt"
import "core:os"
import rl "vendor:raylib"

WINDOW_WIDTH :: 720
WINDOW_HEIGHT :: 720
WINDOW_TITLE :: "gayest wordle game"

BLOCK_SIZE :: 80
BLOCK_GAP :: 20

WORD_LEN :: 5
GUESS_COUNT :: 6
Word :: [WORD_LEN]byte

read_word_file :: proc(path: string) -> []Word {
	ar: [dynamic]Word
	defer delete(ar)
	contents, _ := os.read_entire_file(path, context.allocator)
	defer delete(contents)
	i := 0
	j := 0
	for b in contents {
		if b == '\r' do continue
		if b == '\n' {
			if j != WORD_LEN do panic("Word file contains words of different length")
			j = 0
			i += 1
		} else {
			if j >= WORD_LEN do panic("Word file contains words of different length")
			resize(&ar, i + 1)
			ar[i][j] = b
			j += 1
		}
	}
	res := make([]Word, len(ar))
	copy(res, ar[:])
	return res
}

entry :: proc() -> int {
	rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, WINDOW_TITLE)

	wordles := read_word_file("wordles.txt")
	defer delete(wordles)
	nonwordles := read_word_file("nonwordles.txt")
	defer delete(nonwordles)

	for !rl.WindowShouldClose() {
		rl.BeginDrawing()
		defer rl.EndDrawing()
		rl.ClearBackground(rl.DARKGRAY)

		for i in 0 ..< 6 {
			for j in 0 ..< 5 {
				rect := rl.Rectangle {
					x      = f32(j) * (BLOCK_SIZE + BLOCK_GAP),
					y      = f32(i) * (BLOCK_SIZE + BLOCK_GAP),
					width  = BLOCK_SIZE,
					height = BLOCK_SIZE,
				}
				rl.DrawRectangleRec(rect, rl.WHITE)
			}
		}
	}

	return 0
}

main :: proc() {
	exit_code := 0
	defer os.exit(exit_code)

	when ODIN_DEBUG {
		track: mem.Tracking_Allocator
		mem.tracking_allocator_init(&track, context.allocator)
		context.allocator = mem.tracking_allocator(&track)

		defer {
			if len(track.allocation_map) > 0 {
				fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
				for _, entry in track.allocation_map {
					fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
				}
			}
			if len(track.bad_free_array) > 0 {
				fmt.eprintf("=== %v incorrect frees: ===\n", len(track.bad_free_array))
				for entry in track.bad_free_array {
					fmt.eprintf("- %p @ %v\n", entry.memory, entry.location)
				}
			}
			mem.tracking_allocator_destroy(&track)
		}
	}

	fmt.println(":3")

	exit_code = entry()
}
