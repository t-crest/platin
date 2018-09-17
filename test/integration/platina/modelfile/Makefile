CC=/home/noctux/Studium/Masterarbeit/build/bin/patmos-clang
CFLAGS=-nostdinc \
	   -isystem /srv/scratch/fo21qixo/swan/builds/patmos-llvm/bin/../lib/clang/3.8.0/include \
	   -mlittle-endian \
	   -Qunused-arguments \
	   -Wall -Wundef -Wstrict-prototypes -Wno-trigraphs \
	   -fno-strict-aliasing -fno-common -Werror-implicit-function-declaration \
	   -Wno-format-security -target arm-none-eabi -gcc-toolchain ./ \
	   -no-integrated-as -std=gnu89 -fno-dwarf2-cfi-asm -Wa,-mno-warn-deprecated \
	   -mabi=aapcs-linux -mfpu=vfp -marm -march=armv7-a \
	   -msoft-float -Uarm -fno-PIE \
	   -Wframe-larger-than=1024 -fno-stack-protector \
	   -Wno-unused-variable -Wno-format-invalid-specifier \
	   -Wno-gnu -Wno-asm-operand-widths \
	   -Wno-initializer-overrides -fno-builtin \
	   -Wno-tautological-compare -fomit-frame-pointer \
	   -g -Wdeclaration-after-statement -Wno-pointer-sign \
	   -fno-strict-overflow -Werror=implicit-int \
	   -Werror=strict-prototypes -Werror=date-time \
	   -Wno-initializer-overrides -Wno-unused-value \
	   -Wno-format -Wno-unknown-warning-option \
	   -Wno-sign-compare -Wno-format-zero-length \
	   -Wno-uninitialized \
	   -mllvm -mserialize-all -mserialize-auto \
	   -O0
LD=/usr/bin/arm-none-eabi-gcc
LDFLAGS=-mabi=aapcs-linux \
		-mfpu=vfp -funwind-tables \
		-march=armv7-a -msoft-float \
		-U arm -fno-PIE \
	  -g

ENTRY=c_entry
FILE=test

PLATINARCH=armv7-none-none-eabi
PLATINFLAGS=--analysis-entry $(ENTRY) \
			-i ./$(FILE).c.pml -i ./sched.c.pml -b $(FILE) \
			--disable-ait --enable-wca --report \
			--modelfile ./Modelfile \
			--link --qualify-machinecode \
			--debug ilp

export PATH := $(shell pwd):$(PATH)

.PHONY: clean platin-wcet platin-interact test

$(FILE): $(FILE).o sched.o
	$(LD) $(LDFLAGS) -o $@ $^
%.o : %.c
	$(CC) $(CFLAGS) -c -o $@ $<
	@sed -i s/armv7-none--eabi/$(PLATINARCH)/g $<.pml

test.o: test.c test.h
sched.o: sched.c test.h

platin-wcet: $(FILE)
	platin wcet $(PLATINFLAGS)

platin-interact: $(FILE)
	platin interact $(PLATINFLAGS)

clean:
	rm -f ./*.c.bc ./*.c.pml ./*.o ./$(FILE) ./gurobi.log
