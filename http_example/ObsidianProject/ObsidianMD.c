#include "Obsidian_Header.h"
#include <sys/ptrace.h>
#include <stdio.h>
#include <stdlib.h>

// Possibly Implement this in assembly
static int depedency_list(){
    long result; 

    asm volatile(
        "MOV x8, #117\n\t" // sys_call
        "MOV x0, #0\n\t" //PTRACE_TRACEME
        "MOV x1, #0\n\t" //Process ID
        "MOV x2, #0\n\t" //Addr
        "MOV x3, #0\n\t" //Data
        "SVC #0\n\t" // Execute sys_call
        "mov %0, x0\n\t" // Move results to output variable
        : "=r" (result)         // output constraint
        :                       // no inputs
        : "x0", "x1", "x2", "x3", "x8"  // clobbered registers
    );
    if (result < 0) {
        kill(getpid());
        exit(0);
    } 
}

__attribute__((used, section(".init_array"))) 
static void (*init_entry)(void) = depedency_list;

int main(int argc, char* argv[]) {
    if (ptrace(PTRACE_TRACEME, 0) < 0){
        exit(1); 
    }
    print_lib_msg();
    return 0;
}