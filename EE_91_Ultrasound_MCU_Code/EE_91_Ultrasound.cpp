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

/*
//  X motor: BLUE = 6, PINK = 7, YELLOW = 8, ORANGE = 9
//  Z motor: BLUE = 10, PINK = 11, YELLOW = 12, ORANGE = 13
// Pink-orange are a coil, yellow-blue are a coil
// Pink is inverse of yellow. Orange is inverse of blue
// The vector is: (A, B, not A, not B) so (Pink, Orange, Yellow, Blue)
std::vector<uint> zMotorPins = {7, 9, 8, 6}; // 28bjy-48
std::vector<uint> xMotorPins = {11, 13, 12, 10};

StepMotorControl xMotor(StepMotorControl::BYJ_48, xMotorPins);
StepMotorControl zMotor(StepMotorControl::BYJ_48, zMotorPins);
//*/

const uint zMotorPins_NEMA[4] = {6,7,8,9};
const uint xMotorPins_NEMA[4] = {10,11,13,12};

const bool stepTable[4][4] = {
    {1,0,1,0},
    {0,1,1,0},
    {0,1,0,1},
    {1,0,0,1}
};

void stepMotorX(int step) {
    for(int i=0;i<4;i++)
        gpio_put(xMotorPins_NEMA[i], stepTable[step][i]);
}

void releaseMotorX() {
    for(int i=0;i<4;i++)
        gpio_put(xMotorPins_NEMA[i], 0);
}

void stepMotorZ(int step) {
    for(int i=0;i<4;i++)
        gpio_put(zMotorPins_NEMA[i], stepTable[step][i]);
}

void releaseMotorZ() {
    for(int i=0;i<4;i++)
        gpio_put(zMotorPins_NEMA[i], 0);
}

void runMotor(int steps, int delay_ms, bool clockwise, bool xMotor) {
    int stepIndex = 0;

    for(int s=0; s<steps; s++)
    {
        if (xMotor) stepMotorX(stepIndex);
        else stepMotorZ(stepIndex);

        if (clockwise) stepIndex++;
        else stepIndex--;

        if(stepIndex >= 4) stepIndex = 0;
        if (stepIndex < 0) stepIndex = 3;

        busy_wait_ms(delay_ms);
    }
}

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

    // Init motor GPIOs
    for (int i = 0; i < 4; i++) {
        gpio_init(xMotorPins_NEMA[i]);
        gpio_set_dir(xMotorPins_NEMA[i], GPIO_OUT);
        gpio_put(xMotorPins_NEMA[i], 0);

        gpio_init(zMotorPins_NEMA[i]);
        gpio_set_dir(zMotorPins_NEMA[i], GPIO_OUT);
        gpio_put(zMotorPins_NEMA[i], 0);
    }

    // Init ADCs
    adc_gpio_init(26); // Prepare GP26 for ADC use
    adc_select_input(0); // Select ADC channel 0 (corresponding to GP26)
    adc_gpio_init(27); // Prepare GP26 for ADC use
    adc_select_input(1); // Select ADC channel 0 (corresponding to GP26)
    adc_gpio_init(28); // Prepare GP26 for ADC use
    adc_select_input(2); // Select ADC channel 0 (corresponding to GP26)

    // Init motors
    // xMotor.motorInit();
    // zMotor.motorInit();

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
            } else if (c == 'a') { 
                // x motor to the left, looking head on
                runMotor(4, 10, true, true);
            } else if (c == 'b') {
                // x motor to the right, looking head on
                runMotor(4, 10, false, true);
            } else if (c == 'c') {
                // z motor to down, looking head on
                runMotor(4, 10, true, false);
            } else if (c == 'd') {
                // z motor to up, looking head on
                runMotor(4, 10, false, false);
            } else if (c == 'e') {
                releaseMotorX();
            } else if (c == 'f') {
                releaseMotorZ();
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
