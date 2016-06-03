all: system.pml

test: test.c
	patmos-clang test.c -mserialize=test.pml -o test

system.pml: test.pml test
	platin extract-symbols -i test.pml test -o $@
