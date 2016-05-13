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


${B}/libos.bc: system.c thread.c thread.h
	cat $^ > ${B}/libos.c
	$(CC) `platin tool-config -i ${B}/config.pml -t clang` -c -emit-llvm -o $@ ${B}/libos.c -I.


${B}/system: ${B}/app-split.bc ${B}/libos.bc
	$(CC) `platin tool-config -i ${B}/config.pml -t clang` -o $@ -mserialize=${B}/01-system.pml  $^


${B}/system.pml: ${B}/system
	platin extract-symbols -i ${B}/01-system.pml -o $@ $<

v.system: ${B}/system.pml
	@mkdir -p system.graphs
	@rm -f system.graphs/*
	platin visualize -i ${B}/system.pml -O system.graphs --show-instr

v.gcfg: ${B}/system.pml
	@mkdir -p gcfg.graphs
	@rm -f gcfg.graphs/*
	platin gcfg -i ${B}/system.pml -i gcfg.pml -o gcfg.graphs/system.pml
	platin wca -e system -i ${B}/config.pml -i gcfg.graphs/system.pml  --wca-disable-cache \
		-o gcfg.graphs/system-wcet.pml --verbose --debug costs
	platin visualize -i gcfg.graphs/system-wcet.pml -O gcfg.graphs --show-instr --show-timings -f system



wcet.gcfg: ${B}/system.pml
	platin wcet -e GCFG:system -i ${B}/system.pml -i gcfg.pml \
		--binary ${B}/system  --disable-ait --wca-disable-cache \
		--wca-write-lp-file ${B}/gcfg.lp -o ${B}/system-wcet.pml \
		--debug costs

clean:
	rm -rf system.graphs  gcfg.graphs build
