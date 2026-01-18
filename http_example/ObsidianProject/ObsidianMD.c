#include "Obsidian_Header.h"
#include <sys/ptrace.h>
#include <stdio.h>
#include <stdlib.h>

static int depedency_list(){
    if (ptrace(PTRACE_TRACEME, 0) < 0) {
        printf("Mannn stop tryna debug me");
        exit(1);
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