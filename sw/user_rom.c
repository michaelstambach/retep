
#include "uart.h"
#include "print.h"
#include "config.h"
#include "util.h"


int main() {
    uart_init();
    printf("Hello World from Croc!\n");
    uart_write_flush();

    volatile uint32_t* user_rom = (uint32_t*)(USER_ROM_BASE_ADDR);

    printf("user rom contents:\n");
    for (int i = 0; i < 30; i++) {
        printf("at %x: %x\n", i, *(user_rom + i));
    }

    uart_write_flush();

    return 0;
}

