# Ultrasonic Scanner
### Ruth Berkun
### Caltech EE 91: Senior Project

# Introduction
This is all the code for my EE 91 project, a single-element sweeping ultrasound.
When submerged in water parallel to a wall, it is capable of producing a binary image (wall vs something blocking wall) or of producing a depth line (reporting back raw echoes).

# Instructions for Use
## Prerequisites
### Software
- Python3 installed
- A means of uploading code to Alchitry Cu (AlchitryLabs recommended)
- A means of uploading code to Raspberry Pi Pico W (VS Code Micro Pico Device Controller recommended)
### Hardware
- PCB from gerbers ([link](https://drive.google.com/file/d/1rJHKgWHlnU2blR5DU76npWDKohpl21Ps/view?usp=sharing))
- All **bolded** parts on this [BOM](https://docs.google.com/spreadsheets/d/1aMoMTGk82CAZRaWrAcZ8WpMZopPuZ8ezVm7O83u8szA/edit?usp=sharing) (unbolded parts were for prototyping only)
- Additional material not listed on BOM: DRV8871 motor drivers

## One-Shot Mode
Use this mode to get a depth line from the ultrasonic transducer.
- Upload the build file from "EE91_Ultrasound_FPGA_Code_FullSerial" to the Alchitry Cu.
- Upload the code in "EE_91_Ultrasound_MCU_Code" to the Raspberry Pi Pico W
- Make sure both the Alchitry Cu and Raspberry Pi Pico W are connected to your laptop via USB
- Run "read_fpga_serial_binary.py" 

## Imaging Mode
Use this mode if you would like to create a binary image of an object blocking the aquarium wall.
- Upload the build file from "EE91_Ultrasound_FPGA_Code_EchoNoEcho" to the Alchitry Cu.
- Upload the code in "EE_91_Ultrasound_MCU_Code" to the Raspberry Pi Pico W
- Make sure both the Alchitry Cu and Raspberry Pi Pico W are connected to your laptop via USB
- Run "run_xy_table.py"

# Supplementary Material
This Google Drive [link](https://drive.google.com/drive/folders/1ddJYKygTI0TEoiVJLxRauG0LaF8H0M0x?usp=drive_link) contains documents with worklogs and reports.

This [page](https://sites.google.com/view/rberkun/class-projects/ultrasonic-scanner) on my portfolio outlines my project and contains the video demo and poster.
