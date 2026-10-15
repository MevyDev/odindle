package wordle_gui

import "core:c"
import "core:crypto"
import "core:fmt"
import "core:math/rand"
import "core:os"
import "core:strings"
import "core:thread"
import rl "vendor:raylib"

WINDOW_WIDTH :: 720
WINDOW_HEIGHT :: 720
WINDOW_TITLE :: "gayest wordle game"

BLOCK_SIZE :: 80
BLOCK_GAP :: 20

WORD_LEN :: 5
GUESS_COUNT :: 6
Word :: [WORD_LEN]byte

Resp :: enum {
	None,
	Wrong,
	Elsewhere,
	Correct,
}

word_set: map[Word]struct{}

Game :: struct {
	answer:    Word,
	try:       int, // 0-indexed
	guesses:   [GUESS_COUNT]Word,
	feedbacks: [GUESS_COUNT][WORD_LEN]Resp,
}

game := Game{}

wordles: []Word
nonwordles: []Word

string_from_feedback :: proc(feedback: [WORD_LEN]Resp) -> [WORD_LEN]byte {
	res: [WORD_LEN]byte
	for r, i in feedback {
		if r == .None do res[i] = '0'
		if r == .Wrong do res[i] = 'w'
		if r == .Elsewhere do res[i] = 'e'
		if r == .Correct do res[i] = 'c'
	}
	return res
}

feedback_give :: proc(guess: Word) -> [WORD_LEN]Resp {
	answer := game.answer
	counts: [26]u8
	res: [WORD_LEN]Resp
	for i in 0 ..< WORD_LEN {
		if guess[i] == answer[i] {
			res[i] = .Correct
		} else {
			counts[answer[i] - 'a'] += 1
		}
	}

	for i in 0 ..< WORD_LEN {
		c := guess[i] - 'a'
		if res[i] == .None {
			if counts[c] > 0 {
				res[i] = .Elsewhere
				counts[c] -= 1
			} else do res[i] = .Wrong
		}
	}
	return res
}

make_guess :: proc(guess: Word) -> [WORD_LEN]Resp {
	assert(game.try < GUESS_COUNT)
	game.guesses[game.try] = guess

	fb := feedback_give(guess)
	game.feedbacks[game.try] = fb

	game.try += 1

	return fb
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

random_word :: proc() -> Word {
	i := rand.int_max(len(wordles))
	return wordles[i]
}

word_from_string :: proc(s: string) -> (res: Word, ok: bool) {
	if len(s) != WORD_LEN do return Word{}, false
	r: Word
	for i in 0 ..< WORD_LEN {
		r[i] = s[i]
	}
	return r, true
}

newgame_thread :: proc() {
	for !newgame() {}
}

entry :: proc() -> int {
	rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, WINDOW_TITLE)
	rl.SetTargetFPS(60)

	wordles = read_word_file("wordles.txt")
	defer delete(wordles)
	nonwordles = read_word_file("nonwordles.txt")
	defer delete(nonwordles)

	defer delete(word_set)
	for word in wordles {
		map_insert(&word_set, word, struct{}{})
	}
	for word in nonwordles {
		map_insert(&word_set, word, struct{}{})
	}

	game.answer = random_word()
	word, _ := word_from_string("hello")
	make_guess(word)

	thread.create_and_start(newgame_thread)

	for !rl.WindowShouldClose() {
		rl.BeginDrawing()
		defer rl.EndDrawing()
		rl.ClearBackground(rl.DARKGRAY)

		for i in 0 ..< GUESS_COUNT {
			for j in 0 ..< WORD_LEN {
				rect := rl.Rectangle {
					x      = f32(j) * (BLOCK_SIZE + BLOCK_GAP),
					y      = f32(i) * (BLOCK_SIZE + BLOCK_GAP),
					width  = BLOCK_SIZE,
					height = BLOCK_SIZE,
				}

				col: rl.Color
				resp := game.feedbacks[i][j]
				if resp == .None do col = rl.GRAY
				if resp == .Wrong do col = rl.WHITE
				if resp == .Elsewhere do col = rl.SKYBLUE
				if resp == .Correct do col = rl.PINK
				rl.DrawRectangleRec(rect, col)

				c := game.guesses[i][j]
				if c == 0 do c = ' '
				rl.DrawTextCodepoint(
					rl.GetFontDefault(),
					rune(c),
					rl.Vector2{rect.x, rect.y},
					BLOCK_SIZE,
					rl.BLACK,
				)
			}
		}
	}

	fmt.println("quit")

	return 0
}
read_line :: proc(buf: []byte) -> (res: string, ok: bool) {
	n, err := os.read(os.stdin, buf)
	if err != nil || n == 0 do return "", false
	return strings.trim(string(buf[:n]), "\r\n"), true
}

newgame :: proc() -> (quit: bool) {
	fmt.printfln("newgame %d %d", WORD_LEN, GUESS_COUNT)
	game = Game{}
	game.answer = random_word()

	buf: [256]byte
	for true {
		line, ok := read_line(buf[:])
		if !ok {
			fmt.println("huh")
			continue
		}
		if line == "quit" do return true

		word, okword := word_from_string(line)
		if !okword {
			fmt.println("huh")
			continue
		}
		fmt.eprintln(">", string(word[:]))

		if word not_in word_set {
			fmt.println("huh")
			continue
		}

		fb := make_guess(word)
		if word == game.answer {
			break
		} else {
			fb_str := string_from_feedback(fb)
			fmt.println(string(fb_str[:]))
		}
		if game.try >= GUESS_COUNT {
			break
		}
	}
	fmt.println("done")
	return false
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
