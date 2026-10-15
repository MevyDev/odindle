package main

import "core:fmt"
import "core:math"
import "core:mem"
import "core:os"
import "core:strings"
import "core:time"

WORD_LEN :: 5
CORRECT_FEEDBACK: Feedback : 242

Word :: [WORD_LEN]byte
Feedback :: u8

Solver :: struct {
	f:                      proc(_: ^Solver, _: []int) -> Word,
	guessable_words:        []Word,
	possible_words:         []Word,
	backing_feedback_table: []Feedback,
	feedback_table:         [][]Feedback,
	precomputed:            bool,
	best_first:             Word,
	best_second:            []Word,
}

Guess :: struct {
	word: Word,
	fb:   Feedback,
}

State :: struct {
	candidates: []int,
	guesses:    [dynamic]Guess,
	try:        int,
}

all_possible_feedbacks :: proc() -> []Feedback {
	n := 1
	for _ in 0 ..< WORD_LEN {
		n *= 3
	}
	res := make([]Feedback, n)
	for i in 0 ..< n {
		res[i] = Feedback(i)
	}
	return res
}

entropy :: proc(s: ^Solver, candidates: []int) -> Word {
	feedback_counts := make([]f64, int(math.pow(3., WORD_LEN) + 10))
	defer delete(feedback_counts)
	best := [5]byte{'i', 'n', 'v', 'l', 'd'}
	score_best: f64 = -1.
	for guess, i in s.guessable_words {
		in_candidates: bool
		for j in candidates {
			feedback := s.feedback_table[i][j]
			feedback_counts[feedback] += 1
			in_candidates |= i == j
		}
		score: f64 = 0
		for b in feedback_counts {
			if b == 0 do continue
			p := f64(b) / f64(len(candidates))
			score -= p * math.log2(p)
		}
		if score > score_best {
			best = guess
			score_best = score
		} else if score == score_best && in_candidates {
			best = guess
		}
		mem.zero_slice(feedback_counts)
	}
	assert(best != [5]byte{'i', 'n', 'v', 'l', 'd'})
	return best
}

minmax :: proc(s: ^Solver, candidates: []int) -> Word {
	feedback_counts := make([]i16, int(math.pow(3., WORD_LEN) + 10))
	defer delete(feedback_counts)
	best := [5]byte{'i', 'n', 'v', 'l', 'd'}
	best_count: i16 = 30_000
	for guess, i in s.guessable_words {
		in_candidates: bool
		mx_count: i16 = 0
		for j in candidates {
			feedback := s.feedback_table[i][j]
			feedback_counts[feedback] += 1
			mx_count = math.max(feedback_counts[feedback], mx_count)
			in_candidates |= i == j
		}
		if mx_count < best_count {
			best = guess
			best_count = mx_count
		} else if mx_count == best_count && in_candidates {
			best = guess
		}
		mem.zero_slice(feedback_counts)
	}
	return best
}

word_from_string :: proc(s: string) -> (res: Word, ok: bool) {
	if len(s) != WORD_LEN do return Word{}, false
	r: Word
	for i in 0 ..< WORD_LEN {
		r[i] = s[i]
	}
	return r, true
}

feedback_from_string :: proc(s: string) -> (res: Feedback, ok: bool) {
	if len(s) != WORD_LEN do return 0, false
	r: Feedback = 0
	p: Feedback = 1
	for b in s {
		switch b {
		case 'w':
		case 'e':
			r += p
		case 'c':
			r += p + p
		case:
			return 0, false
		}
		p *= 3
	}
	return r, true
}

candidates_update :: proc(s: ^Solver, candidates_old: []int, guess: Guess) -> []int {
	n := 0
	for cand in candidates_old {
		if feedback(guess.word, s.guessable_words[cand]) == guess.fb {
			n += 1
		}
	}
	res := make([]int, n)
	i := 0
	for cand in candidates_old {
		if feedback(guess.word, s.guessable_words[cand]) == guess.fb {
			res[i] = cand
			i += 1
		}
	}
	return res
}

fill_feedback_table :: proc(s: ^Solver) {
	for guess, i in s.guessable_words {
		for answer, j in s.possible_words {
			s.feedback_table[i][j] = feedback(guess, answer)
		}
	}
}

solver_init :: proc(
	wordles: []Word,
	nonwordles: []Word,
	precompute: bool,
	f: proc(_: ^Solver, _: []int) -> Word,
) -> Solver {
	n := len(wordles) + len(nonwordles)
	m := len(wordles)
	res := Solver {
		f                      = f,
		guessable_words        = make([]Word, n),
		possible_words         = make([]Word, m),
		backing_feedback_table = make([]Feedback, n * m),
		feedback_table         = make([][]Feedback, n),
		precomputed            = precompute,
	}
	for i in 0 ..< n {
		res.feedback_table[i] = res.backing_feedback_table[i * m:(i + 1) * m]
	}

	copy(res.possible_words, wordles)
	copy(res.guessable_words[0:m], wordles)
	copy(res.guessable_words[m:], nonwordles)

	fill_feedback_table(&res)

	if precompute {
		state := state_init(&res)
		res.best_first = res.f(&res, state.candidates)
		state_deinit(&state)

		feedbacks := all_possible_feedbacks()
		res.best_second = make([]Word, len(feedbacks))
		for f in feedbacks {
			state = state_init(&res)
			guess := Guess {
				word = res.best_first,
				fb   = f,
			}
			state_update(&res, &state, guess)
			res.best_second[f] = res.f(&res, state.candidates)
			state_deinit(&state)
		}
	}

	return res
}

solver_deinit :: proc(s: ^Solver) {
	delete(s.guessable_words)
	delete(s.possible_words)
	delete(s.feedback_table)
	delete(s.backing_feedback_table)
	if s.precomputed do delete(s.best_second)
}

feedback :: proc(guess: Word, answer: Word) -> Feedback {
	counts: [26]u8
	colors: [WORD_LEN]u8 // 0 gray 1 yellow 2 green
	for i in 0 ..< WORD_LEN {
		if guess[i] == answer[i] {
			colors[i] = 2
		} else {
			counts[answer[i] - 'a'] += 1
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

state_update :: proc(s: ^Solver, state: ^State, guess: Guess) {
	new_candidates := candidates_update(s, state.candidates, guess)
	delete(state.candidates)
	state.candidates = new_candidates
	append(&state.guesses, guess)
	if guess.fb != CORRECT_FEEDBACK do state.try += 1
}

read_line :: proc(buf: []byte) -> (res: string, ok: bool) {
	n, err := os.read(os.stdin, buf)
	if err != nil || n == 0 do return "", false
	return strings.trim(string(buf[:n]), "\r\n"), true
}

state_init :: proc(s: ^Solver) -> State {
	state: State
	state.candidates = make([]int, len(s.possible_words))
	for &b, i in state.candidates {
		b = i
	}
	return state
}

state_deinit :: proc(state: ^State) {
	delete(state.candidates)
}

solve_word :: proc(s: ^Solver, answer: Word) -> (tries: int, elapsed: time.Duration) {
	tick_start := time.tick_now()
	state := state_init(s)
	defer state_deinit(&state)

	fb: Feedback
	for len(state.candidates) > 1 {
		guess_word: Word
		if s.precomputed && state.try == 0 {
			guess_word = s.best_first
		} else if s.precomputed && state.try == 1 {
			guess_word = s.best_second[state.guesses[0].fb]
		} else do guess_word = s.f(s, state.candidates)

		fb = feedback(guess_word, answer)
		guess := Guess{guess_word, fb}
		state_update(s, &state, guess)
	}

	if len(state.candidates) == 0 {
		fmt.eprintln("Impossible word. Exitting...")
		return
	}

	found := s.guessable_words[state.candidates[0]]
	assert(found == answer)

	elapsed_tick := time.tick_since(tick_start)
	return state.try + 1, elapsed_tick
}

interact_gui_spec :: proc(s: ^Solver) {
	state: State
	running: bool
	buf: [256]byte
	guess_word: Word
	for true {
		if running {
			if s.precomputed && state.try == 0 {
				guess_word = s.best_first
			} else if s.precomputed && state.try == 1 {
				guess_word = s.best_second[state.guesses[0].fb]
			} else do guess_word = s.f(s, state.candidates)
			fmt.println(string(guess_word[:]))
		}

		line, ok := read_line(buf[:])
		if !ok do continue

		if line == "quit" {
			if running do state_deinit(&state)
			return
		}

		// TODO: actually work with the other parameters
		if len(line) >= len("newgame") && line[:len("newgame")] == "newgame" {
			if running do state_deinit(&state)
			running = true
			state = state_init(s)
		} else if line == "done" {
			if running {
				state_deinit(&state)
			}
			running = false
		} else if running {
			fb, ok := feedback_from_string(line)
			if !ok {
				fmt.println("quit")
				return
			}
			guess := Guess{guess_word, fb}
			state_update(s, &state, guess)
		}
	}
}

interactive_solve :: proc(s: ^Solver) {
	state := state_init(s)
	defer state_deinit(&state)

	read_buf: [256]byte

	for len(state.candidates) > 1 {
		guess_word := s.f(s, state.candidates)
		fmt.println(string(guess_word[:]))
		fb: Feedback; ok: bool
		for !ok {
			fb_str, read_ok := read_line(read_buf[:])
			if !read_ok {
				fmt.eprintln("Read error")
				continue
			}
			fb, ok = feedback_from_string(fb_str)
			if ok do break
			fmt.eprintln("Bad feedback string")
			fmt.eprintln("'w' for wrong")
			fmt.eprintln("'e' for elsewhere")
			fmt.eprintln("'c' for correct")
		}
		guess := Guess{guess_word, fb}
		state_update(s, &state, guess)
	}
	if len(state.candidates) == 0 {
		fmt.eprintln("Impossible word, exitting")
		return
	}
	res := string(s.guessable_words[state.candidates[0]][:])
	fmt.println(res, "done")
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
	copy(res, ar[:])
	return res
}

benchmark :: proc(s: ^Solver, words: []Word) -> (avg: f32, elapsed: time.Duration) {
	total_time: time.Duration
	total_tries: int
	for answer in words {
		tries, time_taken := solve_word(s, answer)
		total_time += time_taken
		total_tries += tries
	}
	avg_tries := f32(total_tries) / f32(len(words))
	fmt.eprintln("All guesses took:", total_time)
	fmt.eprintln("Total tries: ", total_tries)
	fmt.eprintln("Average tries per word: ", avg_tries)
	return avg_tries, total_time
}

entry :: proc() -> int {
	wordles := read_word_file("wordles.txt")
	defer delete(wordles)
	nonwordles := read_word_file("nonwordles.txt")
	defer delete(nonwordles)

	tick := time.tick_now()
	solver := solver_init(wordles, nonwordles, true, minmax)
	fmt.eprintln("Initializing solver took:", time.tick_since(tick))
	defer solver_deinit(&solver)

	// interactive_solve(&solver)
	benchmark(&solver, solver.possible_words[:100])
	interact_gui_spec(&solver)

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

	fmt.eprintln(":3")

	exit_code = entry()
}
