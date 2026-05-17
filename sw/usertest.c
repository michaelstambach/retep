
#include "uart.h"
#include "print.h"
#include "config.h"
#include "util.h"

static volatile int irq_fired      = 0;

void croc_interrupt_handler(uint32_t cause) {
    printf("interrupt happened with cause %x\n", cause);
    irq_fired = 1;
}

void test_interrupt_reg(uint32_t* user_reg) {
    printf("enabling interrupts\n");
    set_interrupt_enable(1, 20);
    set_global_irq_enable(1);

    printf("initial reg value: %x\n", *user_reg);

    *user_reg = 0x10000;

    printf("updated reg value: %x\n", *user_reg);

    printf("later reg value: %x\n", *user_reg);

    for (volatile int i = 1000; i != 0; i--);

    printf("final reg value: %x\n", *user_reg);

    printf("irq fired: %x\n", irq_fired);
    uart_write_flush();

    set_interrupt_enable(0, 20);
    set_global_irq_enable(0);
}


int main() {
    uart_init();
    printf("Hello World from Croc!\n");
    uart_write_flush();

    printf("enabling interrupts\n");
    set_interrupt_enable(1, 20);
    set_global_irq_enable(1);

    volatile uint32_t* user_reg = (uint32_t*)(USER_ROM_BASE_ADDR);
    volatile uint32_t** dma_addr_reg = (volatile uint32_t **)user_reg + 1;
    volatile uint32_t* dma_value_reg = user_reg + 2;

    uint32_t testval = 0x42;

    printf("initial reg value: %x\n", *dma_value_reg);

    *dma_addr_reg = &testval;

    for (volatile int i = 1000; i != 0; i--);

    printf("updated reg value: %x\n", *dma_value_reg);

    uart_write_flush();

    set_interrupt_enable(0, 20);
    set_global_irq_enable(0);

    return 0;
}

