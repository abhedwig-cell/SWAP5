"""Compile isolated research glue against exact repository sources, no downloads."""
import argparse
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path


def main():
    p=argparse.ArgumentParser()
    p.add_argument("--compiler",required=True)
    p.add_argument("--output",type=Path,required=True)
    a=p.parse_args(); root=Path(__file__).resolve().parents[3]
    source=(root/"tests/fgc/run_fgc46_real_multicell_live_modflow.sh").read_text()
    entries=re.search(r"MODULE_SRC=\(\n(.*?)\n\)",source,re.S).group(1).split()
    entries[0]="tests/fgc/strip01/research_grid_stubs.f90"
    entries[-1]="tests/fgc/strip01/research_swap.f90"
    entries=subprocess.check_output([sys.executable,"tests/support/augment_bartholomeus_backend_sources.py",*entries],
                                    cwd=root,text=True).splitlines()
    a.output.mkdir(parents=True,exist_ok=True); objects=[]
    for entry in entries:
        obj=a.output/(Path(entry).stem+".o")
        subprocess.run([a.compiler,"-std=f2008","-ffree-line-length-none","-fPIC","-fopenmp","-O2",
                        "-J",str(a.output),"-I",str(a.output),"-c",entry,"-o",str(obj)],cwd=root,check=True)
        objects.append(str(obj))
    subprocess.run([a.compiler,"-shared","-fopenmp",*objects,"-o",str(a.output/"libstrip01_swap.so")],check=True)
    (a.output/"source_hashes.json").write_text(json.dumps({e:hashlib.sha256((root/e).read_bytes()).hexdigest()
                                                        for e in entries},indent=2)+"\n")


if __name__=="__main__":
    main()
