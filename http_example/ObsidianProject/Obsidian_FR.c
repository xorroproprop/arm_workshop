#include <stdio.h>

// Obtain persistence and create reverse shell. We need to start adding 
// some anti-analysis that will evade detection from DFIR.

void print_lib_msg() {
    puts("evil msg from the library\n");
}