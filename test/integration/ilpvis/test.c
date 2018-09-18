void _exit () {}
int main () { return 42; }

int callee() {
	while (1);
}

int c_entry(int argc)
{
	if (argc == 0) {
		return 5;
	} else {
		callee();
	}

	if (0) {
		return 6;
	}
	return 0;
}
