#include "test.h"

void _exit () {}
int main () { _exit(); }

volatile int _val;

static int f1() {
	return 42;
}

int f2() {
	_val = 43;
	return _val;
}

int f3() {
	for(;;);
	return 42;
}

struct funs {
	int (*f1)();
	int (*f2)();
	int (*f3)();
	int (*f4)();
} funs;


int c_entry(int argc)
{
	funs.f1 = &f1;
	funs.f2 = &f2;
	funs.f3 = &f3;
	funs.f4 = &f4;

	#pragma platina callee "[test.c:f1, f2, test.c:f4]"
	return (*funs.f1)();
}
