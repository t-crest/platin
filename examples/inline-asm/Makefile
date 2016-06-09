all: test system.pml

main main.pml: main.c
	patmos-clang $< -mserialize=main.pml -o main

system.pml: main
	platin extract-symbols -i main.pml main -o $@

test: main main.pml system.pml
	platin wcet -i main.pml --binary main --disable-ait
	platin wcet -i system.pml --binary main --disable-ait


.PHONY: system.pml
