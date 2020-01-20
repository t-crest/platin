SRC         = test.c
ENTRY       = c_entry
BINARY      = test
TEST_CFLAGS = -O0

.DEFAULT_GOAL := platin-split-wcet

SPLITS := $(SRC:%.c=%.split.pml)
PLATINFLAGS_SPLITPML = $(patsubst %,-i %,$(SPLITS))

platin-split-wcet: $(BINARY) $(SPLITS)
	platin wcet $(PLATINFLAGS_WCA) $(PLATINSFLAGS_LINKING) $(PLATINFLAGS_SPLITPML)

%.split.pml : %.c.pml
	platin basicblocksplitter $(PLATINFLAGS_PML) -o $@

platin-split: $(SPLITS)

.PHONY: platin-split-wcet platin-split

clean::
	rm -f $(SPLITS)

include ../Makefile.armv7m.in
