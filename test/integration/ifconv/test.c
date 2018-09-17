void _exit () {}
int main () { return 0; }

int foo(int j) {
	int i = 42;
	if (j == 0) {
		i = 1337;
	}

	return i;
}

int c_entry(int argc)
{
	return foo(42);
}
