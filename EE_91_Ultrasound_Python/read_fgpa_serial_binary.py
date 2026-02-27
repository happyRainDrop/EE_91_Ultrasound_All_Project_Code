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
import numpy as numpy

NUM_ADC_CHANNELS = 10
BYTES_PER_READ = 2
NUM_READINGS_PER_PULSE = 8000
BYTES_PER_PACKET = BYTES_PER_READ*NUM_READINGS_PER_PULSE
BAUD_RATE_FPGA = 1000000
SAMPLING_RATE = 50000000 # in Hz

BAUD_RATE_PI_PICO = 115200
PI_PICO_CONFIRMATION_MSG = "DONE"

# Trigger constants
TRIGGER_ADC_BYTE = b'p' # triggers pi pico
TRIGGER_CLEAR_MEM_BYTE = b'm'
TRIGGER_TRANSMISSION_BYTE = b'2' # triggers FPGA

# Outdated -- laptop FPGA control
TRIGGER_ADC_BYTE_FPGA_SERIAL = b'1'
CLEAR_MEM_BYTE_FPGA_SERIAL = b'3'           # triggers FPGA


# Globals
ser_fpga = None
ser_pi_pico = None
verbose = False
    # values when transducer images nothing
blank_arr = numpy.zeros(NUM_READINGS_PER_PULSE).tolist()

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
    start_time = time.time()

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
                    if (verbose): print(f"📝 Finished reading ADC in {duration:.1f} seconds.")
                    return True   # SUCCESS

                # Any other text from Pico — optional debugging:
                if (verbose): print(f"Pico says: {line}")

            # Timeout — resend trigger
            if time.time() - start_time > TRIGGER_TIMEOUT:
                if (verbose): print("No DONE received — resending trigger...")
                start_time = time.time()
                break  # break out to resend trigger

            time.sleep(0.002)


def read_pulse_from_serial():
    """
    Assumes FPGA is connected to laptop through a USB serial connection.
    Sends byte to trigger a start of reading.
    Then, saves the samples to the array this_pulse, which is returned
    this_pulse is an array of binary strings
    """
    global verbose
    start_time = time.time()

    global ser_fpga
    total_bin_buf = bytearray()
    this_pulse = []

    # Clear any leftover bytes
    ser_fpga.reset_input_buffer()

    TIMEOUT_SECONDS = 0.2                 # wait this long before retrying
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
                transmission_started = True
                break

        # Read bytes that arrive
        if ser_fpga.in_waiting > 0:
            #print(f"got {ser_fpga.in_waiting} bytes, total {ser_fpga.in_waiting+len(total_bin_buf)} bytes")
            data = ser_fpga.read(ser_fpga.in_waiting)
            total_bin_buf.extend(data)
            data = None
            if (len(total_bin_buf) >= BYTES_PER_PACKET):
                if (len(total_bin_buf) % 2 == 1):
                    total_bin_buf.pop() # pop off extra bytes at end
                #while (len(total_bin_buf) > BYTES_PER_PACKET):
                    #total_bin_buf.pop() # pop off extra bytes at end
                break

    
    for i in range(0, len(total_bin_buf), 2):
        # extract two bytes
        low  = total_bin_buf[i]
        high = total_bin_buf[i + 1]

        # combine into 16-bit number (little-endian)
        value = (high << 8) | low

        # convert to float and store
        this_pulse.append(float(value))

    duration = time.time() - start_time
    if verbose: print(f"📝 Finished reading serial in {duration:.1f} seconds.")
    return np.array(this_pulse)


def plot_adc_csv(filename, sampling_rate, subtract_blank = False):
    """
    Reads a CSV of binary ADC samples and plots them vs time.
    
    Parameters:
        filename (str): path to CSV file
        sampling_rate (float): samples per second
    """
    total_lines = 0
    parsed_lines = 0
    samples = []
    global blank_arr

    with open(filename, 'r') as f:
        for line in f:
            total_lines += 1
            line = line.strip()

            if line == "=============":
                # print(f"Breaking at file line {total_lines}")
                break

            if not line:
                continue

            try:
                my_sample = int(line)/64
                if subtract_blank:
                    my_sample -= blank_arr[parsed_lines]
                samples.append(my_sample)
                parsed_lines += 1
            except ValueError:
                print(f"Skipping invalid line {total_lines}: {repr(line)}")

    #print(f"Total lines read: {total_lines}")
    #print(f"Parsed samples: {parsed_lines}")


    if not samples:
        print("No samples found!")
        return

    # Generate time axis
    dt = 1000000 / sampling_rate  # timestep: us
    time = [i*dt for i in range(len(samples))]

    # Plot
    plt.figure(figsize=(10,4))
    plt.plot(time, samples, marker='o')
    plt.xlabel("Time [us]")
    plt.ylabel("ADC Value")
    plt.title("ADC Samples vs Time")
    plt.grid(True)
    plt.show()

import numpy as np
import matplotlib.pyplot as plt

def plot_adc_csv_ECHOES(filename, sampling_rate, subtract_blank=False):
    """
    Reads a CSV of binary ADC samples and plots them vs time.
    Any segment resembling a 5 MHz sine (even half-cycle) is plotted in red.
    """
    total_lines = 0
    parsed_lines = 0
    samples = []
    global blank_arr

    with open(filename, 'r') as f:
        for line in f:
            total_lines += 1
            line = line.strip()

            if line == "=============":
                break

            if not line:
                continue

            try:
                my_sample = int(line) / 64
                if subtract_blank:
                    my_sample -= blank_arr[parsed_lines]
                samples.append(my_sample)
                parsed_lines += 1
            except ValueError:
                print(f"Skipping invalid line {total_lines}: {repr(line)}")

    if not samples:
        print("No samples found!")
        return

    samples = np.array(samples)

    # Time axis
    dt = 1 / sampling_rate          # seconds
    time = np.arange(len(samples)) * dt * 1e6  # microseconds

    # ---- 5 MHz detection ----
    f_target = 5e6
    T = 1 / f_target
    half_cycle_samples = int((T / 2) * sampling_rate)

    # Require minimum window size
    if half_cycle_samples < 8:
        print("Sampling rate too low to detect 5 MHz.")
        half_cycle_samples = 8

    red_mask = np.zeros(len(samples), dtype=bool)

    for i in range(len(samples) - half_cycle_samples):
        window = samples[i:i + half_cycle_samples]

        # ---- Amplitude check first ----
        peak_to_peak = np.max(window) - np.min(window)
        amplitude = peak_to_peak / 2

        if amplitude < 10:
            continue  # Too small, skip

        # Normalize window
        window = window - np.mean(window)
        if np.std(window) == 0:
            continue
        window = window / np.std(window)

        # Generate 5 MHz sine template
        t_win = np.arange(half_cycle_samples) * dt
        sine_template = np.sin(2 * np.pi * f_target * t_win)
        sine_template = (sine_template - np.mean(sine_template)) / np.std(sine_template)

        # Correlation
        corr = np.correlate(window, sine_template) / half_cycle_samples

        if corr > 0.7:  # correlation threshold (tune if needed)
            red_mask[i:i + half_cycle_samples] = True

    # ---- Plot ----
    plt.figure(figsize=(10, 4))

    # Blue points (default)
    plt.plot(time[~red_mask], samples[~red_mask], 'bo', markersize=5)

    # Red points (5 MHz-like)
    plt.plot(time[red_mask], samples[red_mask], 'ro', markersize=5)

    plt.xlabel("Time [us]")
    plt.ylabel("ADC Value")
    plt.title("ADC Samples vs Time (5 MHz segments in red)")
    plt.grid(True)
    plt.show()

def set_blank_arr(blank_csv_path = "blank.csv"):
    """
    Populates blank_arr with entries from blank_csv_path
    """
    global blank_arr
    total_lines = 0
    parsed_lines = 0
    with open(blank_csv_path, 'r') as f:
        for line in f:
            total_lines += 1
            line = line.strip()

            if line == "=============":
                # print(f"Breaking at file line {total_lines}")
                break

            if not line:
                continue

            try:
                blank_arr[parsed_lines]=(int(line)/64)
                parsed_lines += 1
            except ValueError:
                print(f"Skipping invalid line {total_lines}: {repr(line)}")


if __name__ == "__main__":
    try:
        plot_adc_csv_ECHOES('blank.csv', SAMPLING_RATE)    
        connect_fpga_serial()
        connect_pi_pico_serial()
        
        # ser_fpga.flush()
        # ser_fpga.write(TRIGGER_ADC_BYTE_FPGA_SERIAL)   

        #'''
        for i in range(1):
            file_path = "output" + str(i) + ".csv"
            start_time = time.time()
            
            # Open the file in write mode
            with open(file_path, mode='w', newline='', encoding='utf-8') as file:
                writer = csv.writer(file)

                my_pulse = np.zeros(NUM_READINGS_PER_PULSE)
                NUM_EXTRA_READINGS = 1  # 64 x NUM_EXTRA_READINGS averages
                for j in range(NUM_EXTRA_READINGS):
                    read_ADC()
                    this_pulse = read_pulse_from_serial()
                    my_pulse = my_pulse + this_pulse
                my_pulse = my_pulse/NUM_EXTRA_READINGS

                # Write each string as a new row
                k = 0
                for value in my_pulse:
                    writer.writerow([str(int(value))])
                    k+=1

                writer.writerow(["============="]) # Needed for plot_adc_csv end marker
                duration = time.time() - start_time
                print(f"📝 Finished writing {k} lines to {file_path} in {duration:.1f} seconds.")

        # Plotting time
        set_blank_arr()
        for i in range(1):  
            file_path = "output" + str(i) + ".csv"  
            plot_adc_csv(file_path, SAMPLING_RATE)    
            plot_adc_csv_ECHOES(file_path, SAMPLING_RATE)


        #'''        
        # Done, close
        ser_fpga.close()
        ser_pi_pico.close()

    except KeyboardInterrupt:
        ser_fpga.close()
        ser_pi_pico.close()
        sys.exit(0)