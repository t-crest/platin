SRC              = test.c sched.c
ENTRY            = c_entry
BINARY           = test
TEST_CFLAGS      = -O0
TEST_PLATINFLAGS = \
				--modelfile ./Modelfile

test.o: test.c test.h
sched.o: sched.c test.h

include ../../Makefile.armv7m.in
