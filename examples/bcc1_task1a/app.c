#include <stdlib.h>

#define MAX_SIZE 100

volatile int counter;

void OSEKOS_ActivateTask(void);
void OSEKOS_TerminateTask(void);


// #define compute()                             \
//    for(; counter < 3; counter++)

#define compute() \
    if (counter % 2 == 0) {counter++; counter *= 23; counter = counter * counter;} else {counter += 3;}

void Handler11() {
    compute();
    OSEKOS_ActivateTask();
    compute();
    OSEKOS_TerminateTask();
}


void Handler12() {
    OSEKOS_ActivateTask();
    counter ++;
    OSEKOS_ActivateTask();
    counter ++;
}



int main(int argc, char** argv) {
  srand(0);
  counter = rand();

  Handler11();
  Handler12();

  return 0;
}
