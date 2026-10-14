"""Portable XSim regression. Run with --vivado-bin pointing to Vivado/bin."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "python"))
from gf_reference_model import emit_vectors, self_test

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--vivado-bin", type=Path, required=True)
    parser.add_argument("--kinds", nargs="+", choices=("core","uart","pipeline","accumulator","missing"), default=["core","uart","pipeline","accumulator","missing"])
    parser.add_argument("--outdir", type=Path, default=ROOT / "build" / "regression")
    args = parser.parse_args()
    out = args.outdir.resolve()
    out.mkdir(parents=True, exist_ok=True)
    assert self_test(), "Python reference known-answer test failed"
    manifest = {"sources": {}, "runs": []}
    sources = sorted((ROOT / "rtl").glob("*.sv")) + sorted((ROOT / "tb").glob("*.sv"))
    for source in sources + [ROOT / "python/gf_reference_model.py", ROOT / "scripts/run_regression.py"]:
        manifest["sources"][str(source.relative_to(ROOT))] = hashlib.sha256(source.read_bytes()).hexdigest()
    def run(tool, argv, cwd, log):
        suffix = ".bat" if os.name == "nt" else ""
        result = subprocess.run([str(args.vivado_bin / (tool + suffix)), *argv], cwd=cwd,
                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        (out / log).write_text(result.stdout, encoding="utf-8")
        if result.returncode: raise RuntimeError(f"{tool} failed: see {out / log}")
        return result.stdout
    for n in (4, 8, 16):
        for kind in args.kinds:
            if kind == "missing" and n != 4:
                continue
            count = {"core":100, "uart":3, "pipeline":3, "accumulator":2, "missing":100}[kind]
            with tempfile.TemporaryDirectory(prefix=f"gf256_{kind}_n{n}_") as tmp:
                cwd = Path(tmp)
                emit_vectors(n, count, str(cwd / "golden_vectors"))
                if kind == "missing":
                    (cwd / "golden_vectors" / f"C_n{n}_tb.hex").unlink()
                top = {"core": "tb_systolic_selfcheck", "uart": "tb_fpga_top", "pipeline": "tb_result_pipeline", "accumulator": "tb_accumulator", "missing": "tb_systolic_selfcheck"}[kind]
                label = f"{kind}_n{n}"
                wrapper = cwd / "regression_top.sv"
                wrapper.write_text(f"module regression_top; {top} #(.N({n})) test(); endmodule\n")
                run("xvlog", ["--sv", *map(str, sources), str(wrapper)], cwd, label + "_compile.txt")
                run("xelab", ["regression_top", "-s", label], cwd, label + "_elaborate.txt")
                output = run("xsim", [label, "-runall"], cwd, label + "_simulation.txt")
                if kind == "missing":
                    if "Golden vectors missing/incomplete" not in output:
                        raise RuntimeError("Missing expected-output data did not fail")
                elif "RESULT: PASS" not in output or "Fatal:" in output or "RESULT: FAIL" in output:
                    raise RuntimeError(f"{label} did not pass")
                manifest["runs"].append({"kind": kind, "n": n, "matrices": count, "elements": 0 if kind == "missing" else count*n*n, "expected_failure": kind == "missing"})
                print(f"PASS {label}: " + ("missing-data failure detected" if kind == "missing" else f"{count*n*n} elements"), flush=True)
    (out / "manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")

if __name__ == "__main__":
    main()
