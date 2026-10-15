# Wordle engine written in Odin

:3

## Protocol

### GUI

`newgame <word length> <guess_count>` - tells engine a new game is starting
`<feedback>` - `<word length>` letters, c = correct, e = elsewhere, w = wrong
`quit` - tells the engine it's quitting
`huh` - gui is confused by the word

### Engine

`<guess>` - word the engine guesses
`quit` - tells the gui the engine is stopping
