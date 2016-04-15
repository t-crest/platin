#include <stdlib.h>

#define MAX_SIZE 100

volatile int counter;

void OSEKOS_ActivateTask(void);
void OSEKOS_TerminateTask(void);


#define compute() \
    do { counter++; } while(0)

void Handler11() {
    compute();
    OSEKOS_ActivateTask();
    compute();
    OSEKOS_TerminateTask();
}




int main(int argc, char** argv) {
  srand(0);
  counter = rand();

  Handler11();

  return 0;
}
