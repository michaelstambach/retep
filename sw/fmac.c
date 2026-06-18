#include "uart.h"
#include "print.h"
#include "config.h"
#include "util.h"

#define SUM_COUNT 1000

uint32_t test_input_sum[] = {1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,60,61,62,63,64,65,66,67,68,69,70,71,72,73,74,75,76,77,78,79,80,81,82,83,84,85,86,87,88,89,90,91,92,93,94,95,96,97,98,99,100};

uint16_t test_input_a[] = {1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,60,61,62,63,64,65,66,67,68,69,70,71,72,73,74,75,76,77,78,79,80,81,82,83,84,85,86,87,88,89,90,91,92,93,94,95,96,97,98,99,100};
uint16_t test_input_b[] = {100,99,98,97,96,95,94,93,92,91,90,89,88,87,86,85,84,83,82,81,80,79,78,77,76,75,74,73,72,71,70,69,68,67,66,65,64,63,62,61,60,59,58,57,56,55,54,53,52,51,50,49,48,47,46,45,44,43,42,41,40,39,38,37,36,35,34,33,32,31,30,29,28,27,26,25,24,23,22,21,20,19,18,17,16,15,14,13,12,11,10,9,8,7,6,5,4,3,2,1};

static volatile int irq_fired      = 0;

void croc_interrupt_handler(uint32_t cause) {
    // printf("interrupt happened with cause %x\n", cause);
    if (cause == 20) {
        volatile uint32_t*  fmac_state = (uint32_t*)(USER_FMAC_BASE_ADDR);
        irq_fired = 1;
        *fmac_state = 0;
    }
}


int main() {
    uart_init();
    printf("Hello World from Croc!\n");
    uart_write_flush();

    printf("enabling interrupts\n");
    set_interrupt_enable(1, 20);
    set_global_irq_enable(1);

    volatile uint32_t*  fmac_state = (uint32_t*)(USER_FMAC_BASE_ADDR);
    volatile void** fmac_src_a = (volatile void**)(USER_FMAC_BASE_ADDR) + 1;
    volatile void** fmac_src_b = (volatile void**)(USER_FMAC_BASE_ADDR) + 2;
    volatile uint32_t*  fmac_len   = (uint32_t*)(USER_FMAC_BASE_ADDR) + 3;
    volatile uint32_t*  fmac_result   = (uint32_t*)(USER_FMAC_BASE_ADDR) + 4;

    // timing
    uint32_t t0, t1, t2, t3;

    // Test 1: Simple sum
    // ==================

    // cpu calculation
    uint32_t cpu_sum = 0;
    asm volatile("csrr %0, mcycle" : "=r"(t0)::"memory");
    for (int i = 0; i < 100; i++) {
        cpu_sum += test_input_sum[i];
    }
    asm volatile("csrr %0, mcycle" : "=r"(t1)::"memory");

    *fmac_src_a = test_input_sum;
    *fmac_src_b = 0;
    *fmac_len = 100;

    //printf("starting conversion of %x elements at %x\n", *fmac_len, *fmac_src_a);

    // fmac calculation
    asm volatile("csrr %0, mcycle" : "=r"(t2)::"memory");
    *fmac_state = 1;
    while (!irq_fired) wfi();
    irq_fired = 0;
    asm volatile("csrr %0, mcycle" : "=r"(t3)::"memory");

    //printf("state=%x, result=%x\n", *fmac_state, *fmac_result);
    printf("results:\nsoftware %x, %x cycles\nhardware %x, %x cycles\n", cpu_sum, t1 - t0, *fmac_result, t3 - t2);

    // Test 2: Scalar product
    // ======================

    // cpu
    cpu_sum = 0;
    asm volatile("csrr %0, mcycle" : "=r"(t0)::"memory");
    for (int i = 0; i < 100; i++) {
        cpu_sum += test_input_a[i] * test_input_b[i];
    }
    asm volatile("csrr %0, mcycle" : "=r"(t1)::"memory");

    *fmac_src_a = test_input_a;
    *fmac_src_b = test_input_b;
    *fmac_len = 100;

    //printf("starting conversion of %x elements at %x and %x\n", *fmac_len, *fmac_src_a, *fmac_src_b);
    asm volatile("csrr %0, mcycle" : "=r"(t2)::"memory");
    *fmac_state = 1;
    while (!irq_fired) wfi();
    irq_fired = 0;
    asm volatile("csrr %0, mcycle" : "=r"(t3)::"memory");

    printf("results:\nsoftware %x, %x cycles\nhardware %x, %x cycles\n", cpu_sum, t1 - t0, *fmac_result, t3 - t2);

    uart_write_flush();

    return 0;
}

