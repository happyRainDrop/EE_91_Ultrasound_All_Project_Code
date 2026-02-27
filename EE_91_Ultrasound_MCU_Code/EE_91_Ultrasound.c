#include <stdio.h>
#include "pico/stdlib.h"
#include "hardware/pio.h"
#include "hardware/adc.h"
#include "hardware/uart.h"
#include "hardware/clocks.h"

#include "transmit_pulse.pio.h"

#ifndef TRIG_ADC_PIN
#define TRIG_ADC_PIN 2
#endif

#ifndef CLEAR_MEM_PIN       // This pin sends a HIGH to FPGA
#define CLEAR_MEM_PIN 1    // when we want to clear the memory!
#endif

int TRIG_ADC_CHAR = 'p';  // send 'p' over serial to trigger
int TRIG_CLEAR_MEM = 'm';
int READ_TELEMETRY_CHAR = 'x';


void send_pulse_PIO(PIO pio, uint sm, uint pin, uint offset) {
    /*
    Explaination of inputs:
    - PIO pio = pio0 or pio1 (There are 2 PIOs on the Raspberry Pi Pico W)
    - uint sm: There are 4 state machines on each PIO, so this is 0-3
    - uint offset: where the PIO program is loaded in instruction memory
    -             comes from pio_add_program(pio, &my_pio_program)
    - uint pin: This pin will be set as a PIO-controllable GPIO.
    */
    transmit_pulse_program_init(pio, sm, offset, pin);
    pio_sm_set_enabled(pio, sm, true);
}

void send_pulse_train(PIO pio, uint sm) {
    for (int i = 0; i < 64; i++) {
        // retrigger PIO program
        // pio_sm_put_blocking(pio, sm, 0);
        pio->txf[sm] = (clock_get_hz(clk_sys) / (2 * 1000000)) - 3;
        // wait 200us
        sleep_us(200);
    }
    return;
}

// UART defines
// By default the stdout UART is `uart0`, so we will use the second one
#define BAUD_RATE 115200

int main() {
    // Initialization -- Serial
    stdio_init_all();
    uint64_t start_time_us = time_us_64();

    // Init outputs
    gpio_init(TRIG_ADC_PIN);
    gpio_init(TRIG_ADC_PIN+1);
    gpio_init(TRIG_ADC_PIN+2);
    gpio_init(CLEAR_MEM_PIN);
    gpio_set_dir(TRIG_ADC_PIN, GPIO_OUT);
    gpio_set_dir(TRIG_ADC_PIN+1, GPIO_OUT); // INA
    gpio_set_dir(TRIG_ADC_PIN+2, GPIO_OUT); // INB
    gpio_set_dir(CLEAR_MEM_PIN, GPIO_OUT);

    // Initial output values
    gpio_put(CLEAR_MEM_PIN, 0);
    gpio_put(TRIG_ADC_PIN, 0);
    gpio_put(TRIG_ADC_PIN+1, 0);
    gpio_put(TRIG_ADC_PIN+2, 1);

    // Init ADCs
    adc_gpio_init(26); // Prepare GP26 for ADC use
    adc_select_input(0); // Select ADC channel 0 (corresponding to GP26)
    adc_gpio_init(27); // Prepare GP26 for ADC use
    adc_select_input(1); // Select ADC channel 0 (corresponding to GP26)
    adc_gpio_init(28); // Prepare GP26 for ADC use
    adc_select_input(2); // Select ADC channel 0 (corresponding to GP26)

    // Init PIO, load program
    PIO pio = pio0;
    uint sm = pio_claim_unused_sm(pio, true);
    uint offset = pio_add_program(pio, &transmit_pulse_program);
    send_pulse_PIO(pio, sm, TRIG_ADC_PIN, offset);

    while (true) {

        int c = getchar_timeout_us(0); 

        if (c != PICO_ERROR_TIMEOUT) {
            // Character received, print it back
           // printf("Received: %c\n", (char)c);
            
            // Example of action based on input
            if (c == 'p') {
                send_pulse_train(pio, sm);
                printf("DONE\n");
                // break;
            } else if (c == 'm') {
                gpio_put(CLEAR_MEM_PIN, 1);
                sleep_us(50);
                gpio_put(CLEAR_MEM_PIN, 0);
                printf("CLEAR\n");
            } else if (c == 'x') {
                printf("Mock ADC readings...\n");
            }
        }

        if (time_us_64() - start_time_us > 1000000) {
            /*
            // read ADCs
            adc_select_input(0);
            uint16_t a = adc_read();

            adc_select_input(1);
            uint16_t b = adc_read();

            adc_select_input(2);
            uint16_t cval = adc_read();

            printf("%u %u %u\n", a, b, cval);
            */
            // reset time
            start_time_us = time_us_64();

        }
    }

}
