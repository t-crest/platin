void _exit () {}
int main () { _exit(); }

volatile int j = 0;

int c_entry(int argc)
{
  int i = 0;
  while(j) {
    #pragma platina lbound "NUM_TASKS - set_min(NEXT_SCHED_PRIO_SET)"
    i++;
  }
  return i;
}
