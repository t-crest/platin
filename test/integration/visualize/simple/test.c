void _exit (int e) {}
int main () { _exit(42); }

int choosy(int a) {
  if (a > 0) {
    return -a;
  } else {
    return a;
  }
}

int bar(int i) {
  return i + 2;
}

int loopy(int a) {
  int res = a;
  for(int i = 0; i < 42; i++) {
    #pragma platina lbound "42"
    res += bar(i);
  }
  return res;
}

int c_entry(int argc)
{
  int c = choosy(argc);
	return loopy(c);
}
