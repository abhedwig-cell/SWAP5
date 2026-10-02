#!/usr/bin/env python3
import os,pathlib,re,shlex,statistics,subprocess,tempfile,json
ROOT=pathlib.Path(__file__).resolve().parents[2]
FC=shlex.split(os.environ.get("FC","gfortran"))
test=ROOT/"tests/performance/benchmark_bartholomeus_c3a.f90"
modules={}
for p in (ROOT/"src").rglob("*.f90"):
    txt=p.read_text()
    for n in re.findall(r"^\s*module\s+(\w+)\s*$",txt,re.M|re.I): modules[n.lower()]=p
ordered=[];seen=set()
def visit(p):
    if p in seen:return
    seen.add(p)
    for n in re.findall(r"^\s*use\s+(?:,\s*non_intrinsic\s*::\s*)?(\w+)",p.read_text(),re.M|re.I):
        q=modules.get(n.lower())
        if q:visit(q)
    ordered.append(p)
visit(test)
sources=[p for p in ordered if p!=test]
with tempfile.TemporaryDirectory(prefix="c3a-perf-") as td:
    b=pathlib.Path(td)
    flags=["-O3","-march=native","-ffree-line-length-none","-J"+str(b),"-I"+str(b)]
    objs=[]
    for p in sources:
        o=b/(p.stem+".o"); subprocess.run(FC+flags+["-c",str(p),"-o",str(o)],check=True);objs.append(str(o))
    exe=b/"bench"
    subprocess.run(FC+flags+objs+[str(test),"-o",str(exe)],check=True)
    vals=[]; outputs=[]
    for _ in range(7):
        out=subprocess.check_output([str(exe)],text=True);outputs.append(out)
        vals.append([float(x) for x in re.findall(r"C3A_PERF_NS_PER_EVAL=\s*([0-9.Ee+\-]+)",out)])
    regimes=["low_ctop","mid_ctop","high_ctop"]
    by_regime={name:[row[i] for row in vals] for i,name in enumerate(regimes)}
    result={"compiler":subprocess.check_output(FC+["--version"],text=True).splitlines()[0],
            "head":os.environ.get("GITHUB_SHA","not-specified"),"ns_per_eval_by_run":vals,
            "regimes":{name:{"values":v,"median_ns_per_eval":statistics.median(v),"min_ns_per_eval":min(v)}
                       for name,v in by_regime.items()},"outputs":outputs}
    print(json.dumps(result,indent=2))
    pathlib.Path(os.environ.get("C3A_PERF_RESULT","c3a_perf_result.json")).write_text(json.dumps(result,indent=2)+"\n")
