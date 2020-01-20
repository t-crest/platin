void _exit () {}
int main () { return 0; }

volatile int i = 0;
int f() {
  while(1) {
    #pragma platina lbound "1"
    if (!i) break;
  }
  return 42;
}

int (*volatile ptr)(int);

int pointed(int i) {
  return i + 1;
}

int pointed2(int i) {
  return i - 1;
}

int (*volatile ptr)(int) = 0;

void repointer(void) {
  ptr = &pointed;
}
int g() {
  int a = 0;
  #pragma loopbound min 4 max 4
  for (int j=0; j < 4; j++) {
    a += f();
  }
  a += f();
  #pragma platina callee "[pointed]"
  a += (*ptr)(a);
  return a;
}

int h() {
  int a = f();
  a += 2;
  a *= 43;
  return a;
}

int c_entry(int argc)
{
  ptr = &pointed;
  switch (argc) {
    case 0:
      argc = f();
      break;
    case 1:
      ptr = &pointed2;
      argc = g();
      break;
    case 2:
      argc = h();
      break;
    default:
      argc = 42;
  }
	return argc;
}
