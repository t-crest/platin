/*
 * Copyright (c) 2007-2009 POK team
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * 	* Redistributions of source code must retain the above copyright
 * 	  notice, this list of conditions and the following disclaimer.
 * 	* Redistributions in binary form must reproduce the above
 * 	  copyright notice, this list of conditions and the following
 * 	  disclaimer in the documentation and/or other materials
 * 	  provided with the distribution.
 * 	* Neither the name of the POK Team nor the names of its main
 * 	  author (Julien Delange) or its contributors may be used to
 * 	  endorse or promote products derived from this software
 * 	  without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * AS IS AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
 * FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
 * COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 * BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 * CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
 * ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

#include <stdio.h>
#include <string.h>

#include "thread.h"

context_t * arch_current_context;

// Used to create special threads context (idle and kernel threads)
void arch_context_create (context_t *ctx, void * stack_addr, uint32_t stack_size,
                         void * shadow_stack_addr, uint32_t shadow_stack_size,
                          void (*entry)())
{
    // Set context to 0
    memset (ctx, 0, sizeof (context_t));

    // Setting base function address to return to
    ctx->s7  = (uint32_t)entry;
    ctx->s8  = 0;


    // Setting stack pointer and spill pointer
    ctx->sgap			= 0;
    ctx->s6			= (uint32_t) (stack_addr+stack_size - 4);

    ctx->r31		= ((uint32_t) shadow_stack_addr) + shadow_stack_size - 4;
}

__attribute__((naked,noinline))
void arch_switch_to(context_t *to) {
    context_t *from = arch_current_context;
    arch_current_context = to;
    asm volatile (
        "swc  [%0 + 0] = $r20	    \n"
	"swc  [%0 + 1] = $r21	    \n"
	"swc  [%0 + 2] = $r22	    \n"
	"swc  [%0 + 3] = $r23	    \n"
	"swc  [%0 + 4] = $r24	    \n"
	"swc  [%0 + 5] = $r25	    \n"
	"swc  [%0 + 6] = $r26	    \n"
	"swc  [%0 + 7] = $r27	    \n"
	"swc  [%0 + 8] = $r28	    \n"
	"swc  [%0 + 9] = $r29	    \n"
	"swc  [%0 + 10] = $r30	    \n"
	"swc  [%0 + 11] = $r31	    \n"
	"mfs  $r9  = $s0	    \n"
	"mfs  $r10 = $s2		    \n"
	"mfs  $r11 = $s3		    \n"
	"mfs  $r12 = $s5		    \n"
	"mfs  $r13 = $s6		    \n"
	"mfs  $r14 = $s7		    \n"
	"mfs  $r15 = $s8		    \n"
	"sub  $r12 = $r12, $r13      \n"
        "sspill $r12	     \n"
	"swc  [%0 + 12] = $r9	    \n"
	"swc  [%0 + 13] = $r10	    \n"
	"swc  [%0 + 14] = $r11	    \n"
	"swc  [%0 + 15] = $r12	    \n"
	"swc  [%0 + 16] = $r13	    \n"
	"swc  [%0 + 17] = $r14	    \n"
	"swc  [%0 + 18] = $r15	    \n"
        // Restore from here
        "lwc $r20 = [%1 + 0]  \n"
	"lwc $r21 = [%1 + 1]  \n"
	"lwc $r22 = [%1 + 2]  \n"
	"lwc $r23 = [%1 + 3]  \n"
	"lwc $r24 = [%1 + 4]  \n"
	"lwc $r25 = [%1 + 5]  \n"
	"lwc $r26 = [%1 + 6]  \n"
	"lwc $r27 = [%1 + 7]  \n"
	"lwc $r28 = [%1 + 8]  \n"
	"lwc $r29 = [%1 + 9]  \n"
	"lwc $r30 = [%1 + 10] \n"
	"lwc $r31 = [%1 + 11] \n"
	"lwc $r9  = [%1 + 12] \n"
	"lwc $r10 = [%1 + 13] \n"
	"lwc $r11 = [%1 + 14] \n"
	"lwc $r12 = [%1 + 15] \n"
	"lwc $r13 = [%1 + 16] \n"
	"lwc $r14 = [%1 + 17] \n"
	"lwc $r15 = [%1 + 18] \n"
	"mts $s2 = $r10       \n"
	"mts $s5 = $r13       \n"
	"mts $s6 = $r13       \n"
	"mts $s7 = $r14       \n"
	"mts $s8 = $r15       \n"
	"sens $r12	     \n"
	"ret                  \n"
	"mts $s3 = $r11       \n"
	"mts $s0 = $r9        \n"
	"nop"
        : : "r" (from), "r"(to)
    );
}

/* Prints the context */
void arch_context_dump(context_t* ctx) {
#define __str(x) #x
#define P(x) printf(__str(x) " = %lx, ", ctx->x);
    P(sgap);
    P(s6);
    printf("\n");
}
