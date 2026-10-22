#ifndef CAPSTONE_LWIP_CC_H
#define CAPSTONE_LWIP_CC_H

#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>
#include <unistd.h>

/* Linux supplies diagnostics, errno and byte-order functions for this port. */
#define LWIP_PLATFORM_DIAG(message) do { printf message; } while (0)
#define LWIP_PLATFORM_ASSERT(message) do { \
    fprintf(stderr, "lwIP assertion: %s\n", message); abort(); \
} while (0)
#define LWIP_ERRNO_STDINCLUDE 1
#define LWIP_DONT_PROVIDE_BYTEORDER_FUNCTIONS 1

#endif
