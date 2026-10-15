package main

import "core:fmt"
import "core:mem"
import "core:os"

WORD_LEN :: 5

Word :: [5]byte
Feedback :: u8

feedback :: proc(guess: Word, answer: Word) -> Feedback {
	counts: [26]u8
	colors: [WORD_LEN]u8 // 0 gray 1 yellow 2 green
	for i in 0 ..< WORD_LEN {
		if guess[i] == answer[i] {
			colors[i] = 2
		} else {
			counts[guess[i] - 'a'] += 1
		}
	}

	for i in 0 ..< WORD_LEN {
		c := guess[i] - 'a'
		if colors[i] == 0 && counts[c] > 0 {
			colors[i] = 1
			counts[c] -= 1
		}
	}

	res: Feedback
	p: Feedback = 1
	for i in 0 ..< WORD_LEN {
		res += colors[i] * p
		p *= 3
	}

	return res
}

entry :: proc() -> int {
	return 0


}

main :: proc() {
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

	os.exit(entry())
}
