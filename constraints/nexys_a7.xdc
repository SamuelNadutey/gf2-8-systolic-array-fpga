## This file is a general .xdc for the Nexys A7 targeting your custom Matrix Accelerator
## To use it in a project:
## - uncomment the lines corresponding to used pins
## - rename the used ports (in each line, after get_ports) according to the top level signal names in the project

# --- 1. Clock Signal ---
# 100 MHz oscillator on pin E3
set_property -dict { PACKAGE_PIN E3    IOSTANDARD LVCMOS33 } [get_ports { clk_100mhz }];
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports { clk_100mhz }];

# --- 2. Buttons ---
# Using the Center Button (BTNC) for the active-high reset
set_property -dict { PACKAGE_PIN N17   IOSTANDARD LVCMOS33 } [get_ports { reset_btn }];

# --- 3. LEDs ---
# LED 0 (Far right) for led_ready
set_property -dict { PACKAGE_PIN H17   IOSTANDARD LVCMOS33 } [get_ports { led_ready }];
# LED 1 (Next to it) for led_busy
set_property -dict { PACKAGE_PIN K15   IOSTANDARD LVCMOS33 } [get_ports { led_busy }];

# --- 4. USB-RS232 Interface (UART) ---
# Data coming FROM the PC (TX on PC side -> RX on FPGA side)
set_property -dict { PACKAGE_PIN C4    IOSTANDARD LVCMOS33 } [get_ports { uart_rx_pin }];

# Data going TO the PC (RX on PC side <- TX on FPGA side)
set_property -dict { PACKAGE_PIN D4    IOSTANDARD LVCMOS33 } [get_ports { uart_tx_pin }];

# --- 5. Configuration Options (Optional but recommended) ---
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
set_property CONFIG_MODE SPIx4 [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 33 [current_design]
# Nexys A7 configuration-bank voltage settings.
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
