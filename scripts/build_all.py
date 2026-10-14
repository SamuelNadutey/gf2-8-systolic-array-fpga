"""Archive complete builds separately, including source hashes."""
import argparse,datetime,hashlib,json,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def main():
    p=argparse.ArgumentParser()
    p.add_argument("--vivado",type=Path,required=True)
    p.add_argument("--part",default="xc7a50tcsg324-1")
    p.add_argument("--sizes",type=int,nargs="+",default=[4,8,16])
    args=p.parse_args()
    stamp=datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    for n in args.sizes:
        out=ROOT/"build"/f"implementation_{stamp}_n{n}";out.mkdir(parents=True)
        files=[*sorted((ROOT/"rtl").glob("*.sv")),ROOT/"constraints/nexys_a7.xdc",ROOT/"scripts/build_vivado.tcl"]
        hashes={str(f.relative_to(ROOT)):hashlib.sha256(f.read_bytes()).hexdigest() for f in files}
        (out/"source_manifest.json").write_text(json.dumps(hashes,indent=2))
        print(f"Building N={n}: {out}",flush=True)
        with (out/"console.txt").open("w") as log:
            result=subprocess.run([str(args.vivado),"-mode","batch","-source",str(ROOT/"scripts/build_vivado.tcl"),"-tclargs",str(n),args.part,str(out)],cwd=out,stdout=log,stderr=subprocess.STDOUT)
        if result.returncode: raise RuntimeError(f"Build N={n} failed: {out/'console.txt'}")
        print(f"Completed N={n}",flush=True)
if __name__=="__main__":main()
