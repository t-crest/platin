#include <stdlib.h>
#include <stdio.h>
#include "thread.h"

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

context_t Handler13_ctx;
uint8_t stack[4096];
uint8_t shadow_stack[4096];

context_t Handler12_ctx;
void Handler12() {
    volatile int data[100];
    data[95] = counter;
    printf("Handler 12: 1 %d %d\n", data[95], counter);

    OSEKOS_ActivateTask();
    arch_switch_to(&Handler13_ctx);


    printf("Handler 12: ");
    arch_context_dump(&Handler12_ctx);
    printf("Handler 13: ");
    arch_context_dump(&Handler13_ctx);

    printf("Handler 12: 2 %d %d\n", data[95], counter);
}


void Handler13() {
    counter++;
    printf("Handler 13: 2 %d\n", counter);


    printf("Handler 12: ");
    arch_context_dump(&Handler12_ctx);
    printf("Handler 13: ");
    arch_context_dump(&Handler13_ctx);

    arch_switch_to(&Handler12_ctx);
}


int main(int argc, char** argv) {
  srand(0);
  counter = rand();

  arch_context_create(&Handler13_ctx, stack, 4096, shadow_stack, 4096, Handler13);
  arch_current_context = &Handler12_ctx;

  Handler11();
  Handler12();

  return 0;
}
