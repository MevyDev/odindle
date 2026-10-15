alias b := build
alias r := run
alias br := build-release
alias rr := run-release
alias t := test

build:
    odin build ./src -out:./out/debug -debug -vet-shadowing

run:
    odin run ./src -out:./out/debug -debug -vet-shadowing

test:
    odin test ./tests -debug

build-release:
    odin build ./src -o:speed -out:./out/release -vet-shadowing

run-release:
    odin run ./src -o:speed -out:./out/release -vet-shadowing
