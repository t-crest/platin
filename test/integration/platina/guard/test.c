void _exit () {}

int main(int argc, char const* argv[])
{
  (void) argc;
  (void) argv;
  return 0;
}

int c_entry(int argc)
{
	if (argc == 0) {
		return 5;
	} else {
		#pragma platina guard "False"
		while (1);
	}

	if (0) {
		return 6;
	}
	return 0;
}
