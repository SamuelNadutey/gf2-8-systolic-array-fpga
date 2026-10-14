"""Reference-checked UART board test; records observations, not synthesis metrics."""
import argparse
import json
from pathlib import Path
import random
import time
from gf_reference_model import matmul, transpose

def main(default_n=4):
    parser = argparse.ArgumentParser()
    parser.add_argument("--n", type=int, choices=(4,8,16), default=default_n)
    parser.add_argument("--port", required=True)
    parser.add_argument("--baud", type=int, default=115200)
    parser.add_argument("--count", type=int, default=100)
    parser.add_argument("--seed", type=int, default=2026)
    parser.add_argument("--timeout", type=float, default=10)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    if args.count < 1: parser.error("--count must be positive")
    import serial
    rng = random.Random(args.seed)
    records = []
    with serial.Serial(args.port, args.baud, timeout=args.timeout) as link:
        time.sleep(1)
        link.reset_input_buffer()
        for index in range(args.count):
            a = [[rng.randrange(256) for _ in range(args.n)] for _ in range(args.n)]
            b = [[rng.randrange(256) for _ in range(args.n)] for _ in range(args.n)]
            expected = bytes(x for row in matmul(a,b) for x in row)
            start = time.perf_counter()
            link.write(b"A" + bytes(x for row in a for x in row) + b"B" + bytes(x for row in transpose(b) for x in row))
            link.flush()
            actual = link.read(args.n*args.n)
            record = {"index": index, "a": a, "b": b, "expected_hex": expected.hex(),
                      "received_hex": actual.hex(), "uart_round_trip_seconds": time.perf_counter()-start,
                      "pass": actual == expected}
            records.append(record)
            print(f"N={args.n} matrix={index} {'PASS' if record['pass'] else 'FAIL'}", flush=True)
            if not record["pass"]: break
    passed = len(records)==args.count and all(r["pass"] for r in records)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps({"n":args.n,"baud":args.baud,"seed":args.seed,"requested_count":args.count,
                                          "pass":passed,"observations":records},indent=2),encoding="utf-8")
    raise SystemExit(0 if passed else 1)

if __name__ == "__main__": main()
