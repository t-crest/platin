CFLAGS = $(shell ) -O2 -c -emit-llvm
CC     = patmos-clang
B      = build

all: ${B}/system

${B}:
	mkdir -p ${B}

${B}/config.pml:
	mkdir -p ${B}
	platin pml-config --target patmos-unknown-unknown-elf -o $@ -m 2k -M fifo8


${B}/app.bc: app.c ${B}/config.pml
	$(CC) `platin tool-config -i ${B}/config.pml -t clang` $< -o $@ -c -emit-llvm
	cd ${B}; patmos-llvm-dis app.bc


${B}/app-split.bc: ${B}/app.bc
	cd ${B}; ~/w/dosek/build/llvm-extractor app.bc -O app.structure -o app-split.bc \
		-s TerminateTask -s ActivateTask
	cd ${B}; patmos-llvm-dis app-split.bc



${B}/system: ${B}/app-split.bc system.c
	$(CC) `platin tool-config -i ${B}/config.pml -t clang` -o $@ -mserialize=${B}/01-system.pml  $<  system.c
	platin extract-symbols -i ${B}/01-system.pml -o ${B}/system.pml $@

v.system: ${B}/system
	@mkdir -p system.graphs
	@rm -f system.graphs/*
	platin visualize -i ${B}/system.pml -O system.graphs --show-instr

v.gcfg: ${B}/system
	@mkdir -p gcfg.graphs
	@rm -f gcfg.graphs/*
	platin gcfg -i ${B}/system.pml -i gcfg.pml -o gcfg.graphs/system.pml
	platin visualize -i gcfg.graphs/system.pml -O gcfg.graphs --show-instr -f system

wcet.gcfg: ${B}/system
	platin wcet -e GCFG:system -i ${B}/system.pml -i gcfg.pml \
		--binary ${B}/system  --disable-ait --wca-disable-cache \
		--wca-write-lp-file ${B}/gcfg.lp -o ${B}system-wcet.pml \
		--debug ilp,ipet

clean:
	rm -rf system.graphs  gcfg.graphs build
