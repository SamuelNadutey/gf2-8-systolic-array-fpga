import serial
import time

# --- CONFIGURATION ---
# Change this to match your port (e.g., 'COM3' for Windows, '/dev/ttyUSB1' for Linux)
COM_PORT = 'COM5' 
BAUD_RATE = 115200

# --- THE DATA ---
# Matrix A: Row-Major (Left-to-Right, Top-to-Bottom)
matrix_A = [
    0x06, 0x09, 0x02, 0x01,
    0x03, 0x04, 0x06, 0x02,
    0x07, 0x03, 0x01, 0x05,
    0x02, 0x02, 0x00, 0x01
]



# Matrix B: Column-Major (Top-to-Bottom, Left-to-Right)
matrix_B = [
    0x07, 0x02, 0x09, 0x02,
    0x00, 0x04, 0x03, 0x01,
    0x06, 0x01, 0x06, 0x03,
    0x02, 0x06, 0x02, 0x01
]


def run_hardware_test():
    print(f"Connecting to FPGA on {COM_PORT} at {BAUD_RATE} baud...")
    
    try:
        # Open the serial connection
        with serial.Serial(COM_PORT, BAUD_RATE, timeout=2) as fpga:
            time.sleep(1) # Allow connection to stabilize
            
            # --- 1. SEND MATRIX A ---
            print("\nSending Command 'A' and Matrix A Data...")
            fpga.write(b'A') 
            fpga.write(bytearray(matrix_A))
            time.sleep(0.1) # Tiny pause for hardware to latch
            
            # --- 2. SEND MATRIX B ---
            print("Sending Command 'B' and Matrix B Data...")
            fpga.write(b'B')
            fpga.write(bytearray(matrix_B))
            
            # --- 3. CATCH THE RESULTS ---
            print("\nWaiting for hardware computation...")
            result_bytes = fpga.read(16)
            
            if len(result_bytes) == 16:
                print("\n[SUCCESS] Received 16 bytes from Systolic Array!")
                print("\n--- Output Matrix C (GF(2^8) Arithmetic) ---")
                for row in range(4):
                    row_data = result_bytes[row*4 : row*4 + 4]
                    formatted_row = "  ".join([f"{val:3d}" for val in row_data])
                    print(f"[ {formatted_row} ]")
            else:
                print(f"\n[ERROR] Hardware timeout! Only received {len(result_bytes)} bytes.")
                
    except serial.SerialException as e:
        print(f"\n[ERROR] Could not open {COM_PORT}.")
        print("Check if the port is correct and ensure no other terminal (like PuTTY) is using it.")
        print(e)

if __name__ == "__main__":
    run_hardware_test()