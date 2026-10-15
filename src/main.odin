package main

import "core:fmt"
import "core:mem"
import "core:os"

WORD_LEN :: 5

Word :: [5]byte
Feedback :: u8

Solver :: struct {
	guessable_words:        []Word,
	possible_words:         []Word,
	backing_feedback_table: []Feedback,
	feedback_table:         [][]Feedback,
}

fill_feedback_table :: proc(s: ^Solver) {
	n := len(s.guessable_words)
	m := len(s.possible_words)
	for i in 0 ..< n {
		for j in 0 ..< m {
			s.feedback_table[i][j] = feedback(s.guessable_words[i], s.possible_words[j])
		}
	}
}

solver_init :: proc(wordles: []Word, nonwordles: []Word) -> Solver {
	n := len(wordles) + len(nonwordles)
	m := len(wordles)
	res := Solver {
		guessable_words        = make([]Word, n),
		possible_words         = make([]Word, m),
		backing_feedback_table = make([]Feedback, n * m),
		feedback_table         = make([][]Feedback, n),
	}
	for i in 0 ..< n {
		res.feedback_table[i] = res.backing_feedback_table[i * m:(i + 1) * m]
	}

	copy(res.possible_words, wordles)
	copy(res.guessable_words[0:m], wordles)
	copy(res.guessable_words[m:], nonwordles)

	fill_feedback_table(&res)

	return res
}

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
	for i in 0 ..< len(ar) {
		res[i] = ar[i]
	}
	return res
}

entry :: proc() -> int {
	wordles := read_word_file("wordles.txt")
	defer delete(wordles)
	nonwordles := read_word_file("nonwordles.txt")
	defer delete(nonwordles)

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
