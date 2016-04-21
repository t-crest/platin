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
	$(CC) `platin tool-config -i config.pml -t clang` -o $@ -mserialize=system-compiler.pml  $<  system.c
	platin extract-symbols -i system-compiler.pml -o system.pml $@

system_visualize: system
	@mkdir -p system.graphs
	platin visualize -i system.pml -O system.graphs --show-instr

gcfg_visualize: system
	@mkdir -p gcfg.graphs
	@rm -f gcfg.graphs/*
	platin gcfg -i system.pml -i gcfg.pml -o system-transformed.pml
	platin visualize -i system-transformed.pml -O gcfg.graphs --show-instr -f system



clean:
	rm -f system *.ll *.bc *.structure config.pml system.pml
	rm -rf system.graphs
