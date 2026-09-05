"""
test_accelerator_n16.py  --  N = 16 host test for the GF(2^8) systolic accelerator.

Identical flow to test_accelerator_n8.py but for a 16x16 array:
  * builds a deterministic A and B (seeded),
  * computes the golden C = A x B over GF(2^8) with the Python reference model,
  * sends A row-major and B COLUMN-major over UART,
  * reads back N*N result bytes,
  * prints the hardware C and reports PASS/FAIL against the golden.

Requires the N=16 bitstream (fpga_top built with N=16) on the board.

Note: at N=16 the UART moves 512 bytes in + 256 out, so the round trip is
~60 ms -- the wait is the serial link, not the accelerator (compute is ns).
"""
import sys, os, time, random
import serial

# --- CONFIGURATION ---
COM_PORT  = 'COM5'
BAUD_RATE = 115200
N         = 16
SEED      = 2026            # change to test a different matrix pair

# --- pull in the GF(2^8) reference model for the golden answer ---
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                "REVIEW_2026-07-17", "python_model"))
from gf_reference_model import GF256, matmul, transpose
gf = GF256()

# --- build a deterministic matrix pair ---
rnd = random.Random(SEED)
A = [[rnd.randrange(256) for _ in range(N)] for _ in range(N)]
B = [[rnd.randrange(256) for _ in range(N)] for _ in range(N)]

# golden result and the exact bytes to send
C_golden   = matmul(A, B, gf)
A_bytes    = [v for row in A for v in row]                  # A row-major
B_bytes    = [v for row in transpose(B) for v in row]       # B column-major
EXPECT     = N * N                                          # bytes to read back


def show(label, flat):
    print(label)
    for r in range(N):
        row = flat[r*N:(r+1)*N]
        print("[ " + " ".join(f"{v:3d}" for v in row) + " ]")


def run_hardware_test():
    print(f"N = {N}   (seed {SEED})   port {COM_PORT} @ {BAUD_RATE} baud")
    print(f"Sending {len(A_bytes)} bytes for A, {len(B_bytes)} for B; "
          f"expecting {EXPECT} bytes back.\n")
    try:
        with serial.Serial(COM_PORT, BAUD_RATE, timeout=10) as fpga:
            time.sleep(1)  # let the link settle

            print("Sending Command 'A' and Matrix A ...")
            fpga.write(b'A')
            fpga.write(bytearray(A_bytes))
            time.sleep(0.1)

            print("Sending Command 'B' and Matrix B ...")
            fpga.write(b'B')
            fpga.write(bytearray(B_bytes))

            print("\nWaiting for hardware computation ...")
            result = fpga.read(EXPECT)

            if len(result) != EXPECT:
                print(f"\n[ERROR] Timeout: got {len(result)} of {EXPECT} bytes.")
                return

            print(f"\n[SUCCESS] Received {EXPECT} bytes from the array.\n")
            hw = list(result)
            show("--- Hardware C ---", hw)

            golden_flat = [C_golden[i][j] for i in range(N) for j in range(N)]
            mism = [(k // N, k % N, golden_flat[k], hw[k])
                    for k in range(EXPECT) if golden_flat[k] != hw[k]]
            print()
            if not mism:
                print(f"[PASS] all {EXPECT} elements match the golden reference.")
            else:
                print(f"[FAIL] {len(mism)} of {EXPECT} elements differ:")
                for i, j, g, h in mism[:16]:
                    print(f"   C[{i}][{j}]  golden={g:3d}  hardware={h:3d}")
                if len(mism) > 16:
                    print(f"   ... and {len(mism)-16} more")

    except serial.SerialException as e:
        print(f"\n[ERROR] Could not open {COM_PORT}. Close any other terminal (PuTTY) using it.")
        print(e)


if __name__ == "__main__":
    run_hardware_test()
