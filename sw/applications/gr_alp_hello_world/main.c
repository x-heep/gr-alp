// System library headers
#include <stdio.h>
#include <stdlib.h>

// X-ALP runtime (provides printf)
#include "printf.h"

// Main body
// ---------
int main(void)
{
    // Simply print a message on the standard output, mapped to the UART peripheral
    printf("Hello World from the GR-ALP template repo on X-ALP!\n");
    return EXIT_SUCCESS;
}
