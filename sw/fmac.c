
#include "uart.h"
#include "print.h"
#include "config.h"
#include "util.h"

uint32_t test_input_sum[] = {1, 2, 3, 4, 5, 6};

uint16_t test_input_a[] = {1, 2, 3, 4};
uint16_t test_input_b[] = {5, 6, 7, 8};


int main() {
    uart_init();
    printf("Hello World from Croc!\n");
    uart_write_flush();

    volatile uint32_t*  fmac_state = (uint32_t*)(USER_FMAC_BASE_ADDR);
    volatile void** fmac_src_a = (volatile void**)(USER_FMAC_BASE_ADDR) + 1;
    volatile void** fmac_src_b = (volatile void**)(USER_FMAC_BASE_ADDR) + 2;
    volatile uint32_t*  fmac_len   = (uint32_t*)(USER_FMAC_BASE_ADDR) + 3;


    *fmac_src_a = test_input_sum;
    *fmac_src_b = 0;
    *fmac_len = 6;

    printf("starting conversion of %x elements at %x\n", *fmac_len, *fmac_src_a);
    *fmac_state = 1;

    for (volatile int i = 0; i < 100; i++) {}

    printf("now state is %x\n", *fmac_state);

    *fmac_src_a = test_input_a;
    *fmac_src_b = test_input_b;
    *fmac_len = 4;

    printf("starting conversion of %x elements at %x and %x\n", *fmac_len, *fmac_src_a, *fmac_src_b);
    *fmac_state = 1;

    for (volatile int i = 0; i < 100; i++) {}

    printf("now state is %x\n", *fmac_state);

    uart_write_flush();

    return 0;
}

