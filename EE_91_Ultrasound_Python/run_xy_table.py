'''
This file works with the FPGA program EE91_ReadADC_Serial.

It sends a start byte to trigger the FPGA to leave 
idle mode and collect a burst of successive samples.
When the FPGA is done collecting samples, it transmits 
the samples over serial as a string, where
the samples are then saved by this program.

It then plots the samples over time.
'''
import serial.tools.list_ports
import time, sys
import os, csv
import matplotlib.pyplot as plt
import numpy as np

NUM_ADC_CHANNELS = 10
BYTES_PER_READ = 1
NUM_READINGS_PER_PULSE = 1
BYTES_PER_PACKET = BYTES_PER_READ*NUM_READINGS_PER_PULSE
BAUD_RATE_FPGA = 1000000
SAMPLING_RATE = 50000000 # in Hz

BAUD_RATE_PI_PICO = 115200
PI_PICO_CONFIRMATION_MSG = "DONE"

# Trigger constants
TRIGGER_ADC_BYTE = b'p' # triggers pi pico
TRIGGER_CLEAR_MEM_BYTE = b'm'
TRIGGER_TRANSMISSION_BYTE = b'2' # triggers FPGA
TRIGGER_X_LEFT = b'a'
TRIGGER_X_RIGHT = b'b'
TRIGGER_Z_UP = b'd'
TRIGGER_Z_DOWN = b'c'
RELEASE_X_MOTOR = b'e'
RELEASE_Z_MOTOR = b'f'

# Outdated -- laptop FPGA control
TRIGGER_ADC_BYTE_FPGA_SERIAL = b'1'
CLEAR_MEM_BYTE_FPGA_SERIAL = b'3'           # triggers FPGA

# Globals
ser_fpga = None
ser_pi_pico = None
verbose = False

# motor constants
NUM_IMG_ROWS = 60   # these go up/down
NUM_IMG_COLS = 60    # these go left/right
TEST_MODE = False  # don't spin motors in test mode

# Connectivity functions
def find_fpga_port():
    '''
    Returns, as a string, the COM port of the FPGA.
    '''
    '''
    # Comment out this stuff because now we have 2 COM ports
    ports = serial.tools.list_ports.comports()
    for port in ports:
        # print(port)
        # Check for common COM indicators
        if ("Serial" in port.description or "usbmodem" in port.device) and "Bluetooth" not in port.description:
            return port.device
    return None
    '''
    return "COM12"

def find_pi_pico_port():
    return "COM13"

def connect_fpga_serial():
    '''
    Sets up serial connection between laptop and FPGA
    '''
        # Connect to serial
    global ser_fpga
    port = None
    try:
        port = find_fpga_port()
        print(f"FPGA Port: {port}")
    except Exception as e:
        print("Error: no Alchitry connected.")
        return
    ser_fpga = serial.Serial(port, baudrate=BAUD_RATE_FPGA, timeout=5)

    # Give time for USB/FPGA UART to initialize
    time.sleep(0.1)   # 100 ms is usually enough

def connect_pi_pico_serial():
    '''
    Sets up serial connection between laptop and Pi Pico 
    '''
        # Connect to serial
    global ser_pi_pico
    port = None
    try:
        port = find_pi_pico_port()
        print(f"Pi Pico Port: {port}")
    except Exception as e:
        print("Error: no Pi Pico connected.")
        return
    ser_pi_pico = serial.Serial(port, baudrate=BAUD_RATE_PI_PICO, timeout=5)

    # Give time for USB/FPGA UART to initialize
    time.sleep(0.1)   # 100 ms is usually enough

# Echo reading functions
def clear_mem():
    '''
    Tells FPGA to set memory to all 0s.
    (Vital because FPGA adds ADC readings to existing readings in memory.)
    '''
    global ser_pi_pico
    global ser_fpga
    global verbose

    TRIGGER_TIMEOUT = 0.50   # seconds

    # Clear buffers
    ser_pi_pico.reset_input_buffer()
    ser_fpga.reset_input_buffer()

    start_time = time.time()

    while True:
        # Send the trigger to Pico
        ser_pi_pico.write(TRIGGER_CLEAR_MEM_BYTE)

        # Wait for Pico to say "CLEAR"
        while True:
            if ser_pi_pico.in_waiting:
                line = ser_pi_pico.readline().decode(errors="ignore").strip()

                if line == "CLEAR":
                    if (verbose): print("Pico told FPGA to CLEAR memory")
                    return True   # SUCCESS

                # Any other text from Pico — optional debugging:
                if (verbose): print(f"\tPico says: {line}")

            # Timeout — resend trigger
            if time.time() - start_time > TRIGGER_TIMEOUT:
                if (verbose): print("No CLEAR received — resending trigger...")
                start_time = time.time()
                break  # break out to resend trigger

            time.sleep(0.002)

def read_ADC():
    '''
    Tells FPGA to take an ADC reading.
    It does this by clearing FPGA mem then triggering the pi pico.

    The pi pico, when triggered,
    will then send pulses to the transmit circuit
    and also send a trigger pulse to the FPGA to read ADC.

    It knows this works because Pi Pico will say "DONE" when done.
    Clear memory and resend the ADC byte if Pi Pico never says "DONE."
    '''
    global ser_pi_pico
    global ser_fpga

    TRIGGER_TIMEOUT = 0.3   # seconds

    # Clear buffers
    ser_pi_pico.reset_input_buffer()
    ser_fpga.reset_input_buffer()

    start_time = time.time()

    while True:
        # Send the trigger to Pico
        clear_mem()
        ser_pi_pico.write(TRIGGER_ADC_BYTE)

        # Wait for Pico to say "DONE"
        while True:
            if ser_pi_pico.in_waiting:
                line = ser_pi_pico.readline().decode(errors="ignore").strip()

                if line == "DONE" or line == "Recieved: p":
                    if (verbose): print("Pico says it is DONE triggering the ADC and transmit circuit.")
                    duration = time.time() - start_time
                    if (verbose): print(f"📝 Finished reading ADC in {duration:.3f} seconds.")
                    return True   # SUCCESS

                # Any other text from Pico — optional debugging:
                if (verbose): print(f"Pico says: {line}")

            # Timeout — resend trigger
            if time.time() - start_time > TRIGGER_TIMEOUT:
                if (verbose): print("No DONE received — resending trigger...")
                start_time = time.time()
                break  # break out to resend trigger

            # time.sleep(0.002)

def read_pulse_from_serial():
    """
    Assumes FPGA is connected to laptop through a USB serial connection.
    Sends byte to trigger a start of reading. Then, we will try to read.
    
    The 1 byte we get from FPGA:
    Nonzero = sees a wall. Return 0
    Zero = sees something blocking a wall. Return 1
    """
    global verbose
    start_time = time.time()

    global ser_fpga
    total_bin_buf = bytearray()

    # Clear any leftover bytes
    ser_fpga.reset_input_buffer()

    TIMEOUT_SECONDS = 0.005                 # wait this long before retrying
    start_time = time.time()
    data = None
    while True:

        # Resend trigger if we have to when getting no data
        while data is None:
            # Wait for response
            while ser_fpga.in_waiting <= 0:
                if time.time() - start_time > TIMEOUT_SECONDS:
                    if (verbose): print("resend transmission byte...")

                    ser_fpga.reset_input_buffer()
                    total_bin_buf = bytearray()
                    ser_fpga.flush()
                    ser_fpga.write(TRIGGER_TRANSMISSION_BYTE)

                    start_time = time.time()  # reset timeout
                    break                     # break out to resend trigger
                time.sleep(0.01)              # small delay reduces CPU load

            # If bytes arrived, read them
            if ser_fpga.in_waiting > 0:
                break

        # Read bytes that arrive
        if ser_fpga.in_waiting > 0:
            # print(f"got {ser_fpga.in_waiting} bytes, total {ser_fpga.in_waiting+len(total_bin_buf)} bytes")
            data = ser_fpga.read(ser_fpga.in_waiting)
            total_bin_buf.extend(data)
            data = None
            if (len(total_bin_buf) >= BYTES_PER_PACKET):
                print(total_bin_buf[0])
                return (total_bin_buf[0] == 0)

# Motor moving functions
def moveMotor(isXMotor, leftOrUp):
    '''
    Tell pico to move the specified motor in the specified direction
    '''
    global ser_pi_pico
    global verbose

    if TEST_MODE: 
        return

    TRIGGER_TIMEOUT = 0.10   # seconds

    # Clear buffers
    ser_pi_pico.reset_input_buffer()

    start_time = time.time()

    while True:

        trig_byte = ""
        check_message = ""
        if (isXMotor and leftOrUp):
            trig_byte = TRIGGER_X_LEFT
            check_message = "LEFT"
        elif (isXMotor and not leftOrUp):
            trig_byte = TRIGGER_X_RIGHT
            check_message = "RIGHT"
        elif (not isXMotor and leftOrUp):
            trig_byte = TRIGGER_Z_UP
            check_message = "UP"
        elif (not isXMotor and not leftOrUp):
            trig_byte = TRIGGER_Z_DOWN
            check_message = "DOWN"

        # Send the trigger to Pico
        ser_pi_pico.write(trig_byte)

        # Wait for Pico to say "LEFT" or "RIGHT" or "UP" or "DOWN"
        while True:
            if ser_pi_pico.in_waiting:
                line = ser_pi_pico.readline().decode(errors="ignore").strip()

                if line == check_message:
                    if (verbose): print(f"Pico said we moved {line}")
                    return True   # SUCCESS

                # Any other text from Pico — optional debugging:
                if (verbose): print(f"\tPico says: {line}")

            # Timeout — resend trigger
            if time.time() - start_time > TRIGGER_TIMEOUT:
                if (verbose): print(f"No motor message received — resending trigger...")
                start_time = time.time()
                break  # break out to resend trigger

            time.sleep(0.002)

def releaseMotors():
    # Release x motor

    TRIGGER_TIMEOUT = 0.10   # seconds
    xReleased = False
    start_time = time.time()
    while not xReleased:

        trig_byte = RELEASE_X_MOTOR
        check_message = "RELEASEX"

        # Send the trigger to Pico
        ser_pi_pico.write(trig_byte)

        # Wait for Pico to say "LEFT" or "RIGHT" or "UP" or "DOWN"
        while True:
            if ser_pi_pico.in_waiting:
                line = ser_pi_pico.readline().decode(errors="ignore").strip()

                if line == check_message:
                    if (verbose): print(f"Pico said we released {line}")
                    xReleased = True   # SUCCESS

                # Any other text from Pico — optional debugging:
                if (verbose): print(f"\tPico says: {line}")

            # Timeout — resend trigger
            if time.time() - start_time > TRIGGER_TIMEOUT:
                if (verbose): print(f"No motor message received — resending trigger...")
                start_time = time.time()
                break  # break out to resend trigger

            time.sleep(0.002)
    
    zReleased = False
    start_time = time.time()
    while not zReleased:

        trig_byte = RELEASE_Z_MOTOR
        check_message = "RELEASEZ"

        # Send the trigger to Pico
        ser_pi_pico.write(trig_byte)

        # Wait for Pico to say "LEFT" or "RIGHT" or "UP" or "DOWN"
        while True:
            if ser_pi_pico.in_waiting:
                line = ser_pi_pico.readline().decode(errors="ignore").strip()

                if line == check_message:
                    if (verbose): print(f"Pico said we released {line}")
                    zReleased = True   # SUCCESS

                # Any other text from Pico — optional debugging:
                if (verbose): print(f"\tPico says: {line}")

            # Timeout — resend trigger
            if time.time() - start_time > TRIGGER_TIMEOUT:
                if (verbose): print(f"No motor message received — resending trigger...")
                start_time = time.time()
                break  # break out to resend trigger

            time.sleep(0.002)

    return
    
if __name__ == "__main__":
    try:
        connect_fpga_serial()
        connect_pi_pico_serial()
        binary_matrix = np.zeros((NUM_IMG_ROWS, NUM_IMG_COLS))
        releaseMotors()
        input("Please reset the X-Y stage and press ENTER when done.")

        print("10 seconds until starting scan, please get in position.")
        time.sleep(10)  
        print("Starting scan.")

        # Start the motor a little bit up from the floor
        for i in range(10):
            moveMotor(isXMotor=False, leftOrUp=True)

        for i in range(NUM_IMG_COLS):

            # Move z to top smoothly
            for k in range(NUM_IMG_ROWS):
                moveMotor(isXMotor=False, leftOrUp=True)

            # Move x over by one
            moveMotor(isXMotor=True, leftOrUp=True)
            print(f"  row {i}")

            for j in range(NUM_IMG_ROWS):
                moveMotor(isXMotor=False, leftOrUp=False)

                startTime = time.time()
                read_ADC()
                seesObject = read_pulse_from_serial()
                #print(f" that took {(time.time()-startTime):.3f} seconds.")
                #if seesObject: print("AHHHHHHH")

                row = NUM_IMG_ROWS - 1 - j
                col = NUM_IMG_COLS - 1 - i
                binary_matrix[row][col] = seesObject

        releaseMotors()
        plt.imshow(np.array(binary_matrix), cmap='gray', vmin=0, vmax=1, origin='lower')
        plt.axis('off')
        plt.show()


        
        #'''        
        # Done, close
        ser_fpga.close()
        ser_pi_pico.close()

    except KeyboardInterrupt:
        releaseMotors()
        ser_fpga.close()
        ser_pi_pico.close()
        sys.exit(0)