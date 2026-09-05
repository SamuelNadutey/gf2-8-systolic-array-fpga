"""
cpu_matmul.py  --  CPU software twin of test_accelerator.py, for the live demo.

Computes the SAME GF(2^8) matrix multiplication that the FPGA does, on the CPU,
prints the result in the SAME format (so it lines up next to the board output),
and times it to give a fair CPU-vs-FPGA THROUGHPUT comparison.

IMPORTANT: the fair comparison is throughput / compute latency, NOT the
wall-clock round trip of test_accelerator.py -- that is dominated by the UART
link, not the accelerator. This script reports the CPU's compute figures; the
FPGA's core figures come from its clock and cycle count (168 MHz, 13 cycles).

Run:  python cpu_matmul.py
"""
import time

# ---- GF(2^8) with the AES polynomial (0x11B) : the same field the FPGA uses ----
def gf_mul(a, b):
    """Shift-and-reduce multiply in GF(2^8) -- the honest, table-free method.
    This is the software TWIN of the hardware multiplier (baseline 1)."""
    acc = 0
    for _ in range(8):
        if b & 1:
            acc ^= a
        hi = a & 0x80
        a = (a << 1) & 0xFF
        if hi:
            a ^= 0x1B
        b >>= 1
    return acc

# ---- optimised software baseline: 64 KB log/antilog tables (generator 3) ----
EXP = [0] * 512
LOG = [0] * 256
_x = 1
for _i in range(255):
    EXP[_i] = _x
    LOG[_x] = _i
    _x = gf_mul(_x, 3)          # multiply by the generator
for _i in range(255, 512):
    EXP[_i] = EXP[_i - 255]

def gf_mul_lut(a, b):
    """Table-based multiply: one add + two lookups. This is what a *tuned*
    software implementation would use (baseline 2)."""
    if a == 0 or b == 0:
        return 0
    return EXP[LOG[a] + LOG[b]]

def gf_matmul(A, B, n, mul=gf_mul):
    C = [[0] * n for _ in range(n)]
    for i in range(n):
        for j in range(n):
            acc = 0
            for k in range(n):
                acc ^= mul(A[i][k], B[k][j])
            C[i][j] = acc
    return C

# ---- the SAME matrices test_accelerator.py sends (A row-major, B row-major) ----
A = [[0x06, 0x09, 0x02, 0x01],
     [0x03, 0x04, 0x06, 0x02],
     [0x07, 0x03, 0x01, 0x05],
     [0x02, 0x02, 0x00, 0x01]]

B = [[0x07, 0x00, 0x06, 0x02],
     [0x02, 0x04, 0x01, 0x06],
     [0x09, 0x03, 0x06, 0x02],
     [0x02, 0x01, 0x03, 0x01]]

N = 4
MACS = N * N * N   # 64 multiply-accumulates per 4x4 multiply

# ---- compute and print C (same layout as test_accelerator.py) ----
C = gf_matmul(A, B, N)
print("--- CPU Output Matrix C (GF(2^8) Arithmetic) ---")
for row in C:
    print("[ " + "  ".join(f"{v:3d}" for v in row) + " ]")

# ---- time both software baselines ----
def bench(mul, reps):
    gf_matmul(A, B, N, mul)                       # warm-up
    t0 = time.perf_counter()
    for _ in range(reps):
        gf_matmul(A, B, N, mul)
    dt = time.perf_counter() - t0
    return dt / reps * 1e6, (reps * MACS) / dt / 1e6   # us/mult, MMAC/s

sw_naive_us, sw_naive_mmac = bench(gf_mul,     30000)   # shift-and-reduce
sw_lut_us,   sw_lut_mmac   = bench(gf_mul_lut, 30000)   # tuned lookup table

# ---- FPGA figures (from cycle count x clock period) ----
CYC = 3 * N + 1                           # 13 cycles at N=4
fpga_100_ns   = CYC / 100e6 * 1e9         # 130 ns : actual board clock
fpga_100_mmac = (100e6 / CYC) * MACS / 1e6
fpga_max_ns   = CYC / 168e6 * 1e9         # 77 ns : at F_max (headroom)
fpga_max_mmac = (168e6 / CYC) * MACS / 1e6

# speed-up is computed on the ACTUAL board time: 13 cycles x 10 ns = 130 ns
su_naive = (sw_naive_us * 1000.0) / fpga_100_ns   # us -> ns, divided by 130 ns
su_lut   = (sw_lut_us   * 1000.0) / fpga_100_ns

print()
print(f"{'':24}{'time/mult':>13}{'MMAC/s':>12}")
print(f"{'CPU  (naive Python)':24}{sw_naive_us:10.1f} us{sw_naive_mmac:12.3f}")
print(f"{'CPU  (lookup table)':24}{sw_lut_us:10.1f} us{sw_lut_mmac:12.3f}")
print(f"{'FPGA array (100 MHz)':24}{fpga_100_ns:10.0f} ns{fpga_100_mmac:12.1f}")
print()
print("=================  NUMBERS FOR THE SLIDE  =================")
print("  Board time = 13 cycles x 10 ns (100 MHz) = 130 ns")
print(f"  CPU  (naive Python) : {sw_naive_us:6.0f} us/multiply   ({sw_naive_mmac:.2f} MMAC/s)")
print(f"  CPU  (lookup table) : {sw_lut_us:6.1f} us/multiply   ({sw_lut_mmac:.2f} MMAC/s)")
print(f"  FPGA array          :    130 ns/multiply   ({fpga_100_mmac:.0f} MMAC/s)")
print(f"  SPEED-UP vs naive   : {su_naive:6.0f} x")
print(f"  SPEED-UP vs tuned   : {su_lut:6.0f} x")
print(f"  Power               :  78 mW  (vs tens of watts for a CPU)")
print("==========================================================")
print()
print("Notes: FPGA time is compute latency (13 cycles x clock period), NOT the")
print("UART round trip. The board runs at 100 MHz -> 130 ns. (77 ns / 827 MMAC/s")
print("is the F_max = 168 MHz potential, not what the board does.)")
