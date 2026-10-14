"""Time two Python GF(2^8) implementations and show analytical core latency.

The hardware figures are cycle-derived at a 100 MHz constraint. This is an
illustrative kernel-only comparison, not measured end-to-end FPGA speedup,
sustained throughput, or an energy comparison.

Run: python python/cpu_benchmark.py
"""
import time

# ---- GF(2^8) with the AES polynomial (0x11B) : the same field the FPGA uses ----
def gf_mul(a, b):
    """Table-free shift-and-reduce multiply over GF(2^8)."""
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

# ---- Python log/antilog lookup baseline (generator 3) ----
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
    """Multiply using Python log/antilog lookups."""
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

# ---- Fixed illustrative matrices, stored row-major in Python ----
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

# ---- compute and print the row-major result ----
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

# Analytical compute latency, excluding data transfers; not measured FPGA throughput.
cycles = 3*N + 1
latency_ns = cycles*10
interval_cycles = 3*N + 2
print(f"Python naive: {sw_naive_us:.2f} us; lookup: {sw_lut_us:.2f} us")
print(f"Analytical core latency at 100 MHz: {latency_ns} ns")
print(f"No-stall core initiation interval: {interval_cycles} cycles")
print("This contrasts host software timing with a cycle-derived kernel latency.")
print("It is not an end-to-end hardware speedup or an energy measurement.")
