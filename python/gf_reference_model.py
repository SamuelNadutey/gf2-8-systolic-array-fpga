"""
GF(2^8) reference model for the scalable systolic array matrix multiplier.

Satisfies the objective in section 1.3.2 of the proposal:
    "To develop a Python-based reference model that generates golden reference
     vectors for GF(2^8) matrix multiplication..."

Field: GF(2^8) with the AES irreducible polynomial
    P(x) = x^8 + x^4 + x^3 + x + 1   (0x11B, low byte 0x1B)

Validated against the published AES MixColumns known-answer test
(db 13 53 45 -> 8e 4d a1 bc); run this file to execute the self-test.

Usage:
    python gf_reference_model.py            # self-test + emit golden vectors
    python gf_reference_model.py --n 8      # generate for N=8
"""

import argparse
import random
import os

POLY_LOW = 0x1B          # low 8 bits of 0x11B
FIELD_BITS = 8


class GF256:
    """Arithmetic in GF(2^8) modulo the AES irreducible polynomial."""

    def __init__(self, poly_low=POLY_LOW, width=FIELD_BITS):
        self.poly_low = poly_low
        self.width = width
        self.mask = (1 << width) - 1

    def add(self, a, b):
        """Field addition is carry-less: a bitwise XOR."""
        return (a ^ b) & self.mask

    def xtime(self, a):
        """Multiply by x, reducing mod P(x) when the x^8 term overflows.

        This is the software twin of shift_reduce.sv.
        """
        hi = a & (1 << (self.width - 1))
        a = (a << 1) & self.mask
        return a ^ self.poly_low if hi else a

    def mul(self, a, b):
        """Shift-and-reduce multiplication; the twin of GF_multiplier.sv."""
        acc = 0
        for _ in range(self.width):
            if b & 1:
                acc ^= a
            a = self.xtime(a)
            b >>= 1
        return acc & self.mask


def matmul(A, B, gf=None):
    """C = A x B over GF(2^8). A is (n x k), B is (k x m)."""
    gf = gf or GF256()
    n, k, m = len(A), len(B), len(B[0])
    C = [[0] * m for _ in range(n)]
    for i in range(n):
        for j in range(m):
            acc = 0
            for t in range(k):
                acc = gf.add(acc, gf.mul(A[i][t], B[t][j]))
            C[i][j] = acc
    return C


def transpose(M):
    return [list(col) for col in zip(*M)]


# ---------------------------------------------------------------------------
# Known-answer tests
# ---------------------------------------------------------------------------

MIXCOLUMNS = [[2, 3, 1, 1],
              [1, 2, 3, 1],
              [1, 1, 2, 3],
              [3, 1, 1, 2]]

# FIPS-197 / Daemen & Rijmen worked examples
MIXCOLUMNS_KAT = [
    ([0xdb, 0x13, 0x53, 0x45], [0x8e, 0x4d, 0xa1, 0xbc]),
    ([0xf2, 0x0a, 0x22, 0x5c], [0x9f, 0xdc, 0x58, 0x9d]),
    ([0x01, 0x01, 0x01, 0x01], [0x01, 0x01, 0x01, 0x01]),
    ([0xc6, 0xc6, 0xc6, 0xc6], [0xc6, 0xc6, 0xc6, 0xc6]),
    ([0xd4, 0xd4, 0xd4, 0xd5], [0xd5, 0xd5, 0xd7, 0xd6]),
]


def self_test():
    gf = GF256()
    ok = True

    for vec, expect in MIXCOLUMNS_KAT:
        got = [c[0] for c in matmul(MIXCOLUMNS, [[v] for v in vec], gf)]
        status = "PASS" if got == expect else "FAIL"
        ok &= (got == expect)
        print(f"  [{status}] MixColumns {[hex(v) for v in vec]}"
              f" -> {[hex(v) for v in got]}")

    # Field axioms on random elements
    rnd = random.Random(0xA5)
    for _ in range(2000):
        a, b, c = (rnd.randrange(256) for _ in range(3))
        assert gf.mul(a, b) == gf.mul(b, a), "multiplication not commutative"
        assert gf.mul(a, gf.mul(b, c)) == gf.mul(gf.mul(a, b), c), "not associative"
        assert gf.mul(a, gf.add(b, c)) == gf.add(gf.mul(a, b), gf.mul(a, c)), "not distributive"
        assert gf.mul(a, 1) == a, "1 is not the identity"
        assert gf.mul(a, 0) == 0, "0 is not absorbing"
    print("  [PASS] commutativity / associativity / distributivity / identity (2000 triples)")
    return ok


# ---------------------------------------------------------------------------
# Golden vector generation
# ---------------------------------------------------------------------------

def emit_vectors(n, count, outdir, seed=2026):
    """Write golden vectors in two forms.

    hex files    - one matrix per line, row-major; human-readable
    tb hex files - one byte per line, all vectors concatenated. This is the
                   format $readmemh actually wants: it reads whitespace-
                   separated tokens and fills an unpacked array flat, so a
                   32-char line would load as a single value, not 16 bytes.
    stream files - byte order exactly as the UART host must send it

    IMPORTANT (see findings F9): the hardware expects matrix B COLUMN-MAJOR.
    The stream file therefore emits B transposed. Sending B row-major makes
    the array compute A x B_transpose, not A x B.
    """
    gf = GF256()
    rnd = random.Random(seed)
    os.makedirs(outdir, exist_ok=True)

    fa = open(os.path.join(outdir, f"A_n{n}.hex"), "w")
    fb = open(os.path.join(outdir, f"B_n{n}.hex"), "w")
    fc = open(os.path.join(outdir, f"C_n{n}.hex"), "w")
    fs = open(os.path.join(outdir, f"stream_n{n}.txt"), "w")
    ta = open(os.path.join(outdir, f"A_n{n}_tb.hex"), "w")
    tb_ = open(os.path.join(outdir, f"B_n{n}_tb.hex"), "w")
    tc = open(os.path.join(outdir, f"C_n{n}_tb.hex"), "w")

    fs.write(f"# Golden stream vectors, N={n}\n")
    fs.write("# 0x41 = load A, 0x42 = load B. A row-major, B COLUMN-major.\n")

    for idx in range(count):
        A = [[rnd.randrange(256) for _ in range(n)] for _ in range(n)]
        B = [[rnd.randrange(256) for _ in range(n)] for _ in range(n)]
        C = matmul(A, B, gf)

        for M, f, t in ((A, fa, ta), (B, fb, tb_), (C, fc, tc)):
            f.write("".join(f"{v:02x}" for row in M for v in row) + "\n")
            t.write("".join(f"{v:02x}\n" for row in M for v in row))

        Bt = transpose(B)
        a_bytes = [v for row in A for v in row]
        b_bytes = [v for row in Bt for v in row]
        c_bytes = [v for row in C for v in row]
        fs.write(f"\n# --- vector {idx} ---\n")
        fs.write("TX 41 " + " ".join(f"{v:02x}" for v in a_bytes) + "\n")
        fs.write("TX 42 " + " ".join(f"{v:02x}" for v in b_bytes) + "\n")
        fs.write("RX    " + " ".join(f"{v:02x}" for v in c_bytes) + "\n")

    for f in (fa, fb, fc, fs, ta, tb_, tc):
        f.close()
    print(f"  wrote {count} vectors for N={n} into {outdir}")


def check_tb_vector():
    """Reproduce the exact stimulus in tb_systolic.sv and show the correct answer.

    The testbench packs rows/cols with the concatenation MSB-first, and the
    skew shifter emits the LOW byte first, so stream order is the reverse of
    the written concat order.
    """
    A_concat = [[1, 2, 9, 6], [2, 6, 4, 3], [5, 1, 3, 7], [1, 0, 2, 2]]
    B_concat = [[2, 9, 2, 7], [1, 3, 4, 0], [3, 6, 1, 6], [1, 2, 6, 2]]

    A = [list(reversed(r)) for r in A_concat]
    Bcols = [list(reversed(c)) for c in B_concat]
    B = [[Bcols[j][k] for j in range(4)] for k in range(4)]

    golden = matmul(A, B)
    hardware = [[16, 35, 18, 63],
                [51, 24, 28, 16],
                [16, 10, 24, 3],
                [8, 9, 13, 8]]   # from fyp_project.sim/.../simulate.log

    print("\n  Golden C for the tb_systolic.sv stimulus:")
    for r in golden:
        print("    ", r)
    print("  What tb_systolic.sv printed:")
    for r in hardware:
        print("    ", r)

    diffs = [(i, j, golden[i][j], hardware[i][j])
             for i in range(4) for j in range(4) if golden[i][j] != hardware[i][j]]
    if not diffs:
        print("  MATCH")
    else:
        print(f"  MISMATCH in {len(diffs)} of 16 elements:")
        for i, j, g, h in diffs:
            print(f"    C[{i}][{j}]: golden={g}  hardware={h}  (xor delta={g ^ h})")
        print("  -> C[3][3] is the deepest PE and settles last; the missing")
        print("     term is exactly A[3][3]*B[3][3]. See finding F2.")
    return diffs


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--n", type=int, default=4, help="matrix dimension")
    ap.add_argument("--count", type=int, default=100, help="vectors to emit")
    ap.add_argument("--outdir", default="golden_vectors")
    ap.add_argument("--replay-historical", action="store_true", help="show the known mismatch from the original saved testbench log")
    args = ap.parse_args()
    if args.n < 2 or args.count < 1:
        ap.error("--n must be >=2 and --count must be positive")

    print("Self-test against AES MixColumns known-answer vectors:")
    ok = self_test()
    if args.replay_historical:
        print("\nReplaying the historical tb_systolic.sv stimulus:")
        check_tb_vector()
    print()
    for n in (args.n,) if args.n != 4 else (4, 8, 16):
        emit_vectors(n, args.count, args.outdir)
    print("\nSelf-test:", "PASS" if ok else "FAIL")

    raise SystemExit(0 if ok else 1)
