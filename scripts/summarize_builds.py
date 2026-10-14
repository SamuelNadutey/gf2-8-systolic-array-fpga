"""Summarize routed reports from isolated complete-system builds."""
import argparse
import json
import re
from pathlib import Path

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("directories", type=Path, nargs="+")
    args = parser.parse_args()
    rows = []
    for directory in args.directories:
        util = (directory / "utilization_routed.rpt").read_text()
        timing = (directory / "timing_routed.rpt").read_text()
        def count(label):
            found = re.search(r"\|\s*" + re.escape(label) + r"\s*\|\s*(\d+)", util)
            if not found: raise ValueError(f"Missing {label}")
            return int(found.group(1))
        found = re.search(r"^\s*(-?\d+\.\d+)\s+(-?\d+\.\d+)\s+(\d+)\s+(\d+)\s+(-?\d+\.\d+)\s+(-?\d+\.\d+)\s+(\d+)\s+(\d+)", timing, re.M)
        if not found: raise ValueError("Missing timing summary")
        config = dict(line.split("=",1) for line in (directory / "configuration.txt").read_text().splitlines() if "=" in line)
        row = {"n":int(config["N"]), "part":config["part"], "vivado":config["Vivado"], "clock_mhz":100,
               "luts":count("Slice LUTs"), "registers":count("Slice Registers"), "bram_tiles":count("Block RAM Tile"), "dsps":count("DSPs"),
               "setup_wns_ns":float(found[1]), "setup_tns_ns":float(found[2]), "setup_failing_endpoints":int(found[3]),
               "hold_whs_ns":float(found[5]), "hold_ths_ns":float(found[6]), "hold_failing_endpoints":int(found[7])}
        row["timing_met"] = row["setup_wns_ns"] >= 0 and row["hold_whs_ns"] >= 0 and row["setup_failing_endpoints"] == 0 and row["hold_failing_endpoints"] == 0
        rows.append(row)
    print(json.dumps(rows, indent=2))

if __name__ == "__main__": main()
