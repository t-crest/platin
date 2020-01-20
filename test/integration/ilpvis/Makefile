SRC              = test.c
ENTRY            = c_entry
BINARY           = test
TEST_CFLAGS      = -O0
TEST_PLATINFLAGS = \
        --visualize-ilp \
        --outdir .

include ../Makefile.armv7m.in

clean::
	rm -f ilp.svg srchints.json constraints.json
