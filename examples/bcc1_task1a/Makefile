CFLAGS = $(shell ) -O2 -c -emit-llvm
CC     = patmos-clang

all: system

config.pml:
	platin pml-config --target patmos-unknown-unknown-elf -o config.pml -m 2k -M fifo8


app.bc: app.c config.pml
	$(CC) `platin tool-config -i config.pml -t clang` $< -o $@ -c -emit-llvm
	patmos-llvm-dis $@


app-split.bc: app.bc
	~/w/dosek/build/llvm-extractor $< -O app.structure -o $@ \
		-s TerminateTask -s ActivateTask
	patmos-llvm-dis $@



system: app-split.bc system.c
	$(CC) `platin tool-config -i config.pml -t clang` -o $@ -mserialize=system.pml  $<  system.c



clean:
	rm -f system *.ll *.bc *.structure config.pml system.pml
