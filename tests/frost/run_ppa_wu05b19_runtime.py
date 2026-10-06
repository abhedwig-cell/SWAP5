#!/usr/bin/env python3
"""B19 complete physical trajectories; source-bound whole modules and case receipts."""
from pathlib import Path
import argparse,concurrent.futures,hashlib,json,os,re,subprocess,tempfile
ROOT=Path(__file__).resolve().parents[2]
SOURCE='636e782080abdd2c0366f96317c4f59e8170dc53'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
    ap=argparse.ArgumentParser();ap.add_argument('--route',choices=['normal','low'],required=True)
    ap.add_argument('--workers',type=int,choices=[1,2,3],default=1);ap.add_argument('--record',required=True)
    ap.add_argument('--compiled-manifest');a=ap.parse_args()
    assert subprocess.check_output(['git','rev-parse','HEAD:src'],cwd=ROOT,text=True).strip()==SOURCE
    build=Path(tempfile.mkdtemp(prefix='ppa-wu05b19-runtime-'+a.route+'-'))
    if a.compiled_manifest:
        compiled=json.loads(Path(a.compiled_manifest).read_text());assert compiled['production_source']==SOURCE
        for f,h in compiled['source_sha256'].items():assert sha(Path(f))==h,f
        objbase=Path(compiled['build']);ordered=[Path(f)for f in compiled['source_sha256']]
    else:
        objbase=build/'whole-modules';objbase.mkdir();modules={};ordered=[];seen=set()
        for f in ROOT.joinpath('src').rglob('*.f90'):
            for m in re.finditer(r'^\s*module\s+(?!procedure\b)(\w+)',f.read_text(),re.I|re.M):modules[m[1].lower()]=f
        original=ROOT/'tests/fsi/fsi04_real_headcalc_stubs.f90';data=original.read_bytes()
        old=b'  real(8), parameter :: disnod(numnod+1) = 1.0d0';new=b'  real(8), parameter :: disnod(numnod+1) = [0.25d0, 0.50d0, 0.75d0, 1.0d0, 0.50d0]'
        assert data.count(old)==1;stub=objbase/'consistent_stubs.f90';stub.write_bytes(data.replace(old,new))
        for m in re.finditer(r'^\s*module\s+(?!procedure\b)(\w+)',stub.read_text(),re.I|re.M):modules[m[1].lower()]=stub
        def visit(name):
            if name in seen or name not in modules:return
            seen.add(name);p=modules[name]
            for n in re.findall(r'^\s*use\s*(?:,\s*non_intrinsic\s*)?(?:::)?\s*(\w+)',p.read_text(),re.I|re.M):visit(n.lower())
            if p not in ordered:ordered.append(p)
        for n in ['mod_fmr_serialized_multiswap_runtime','mod_fmr_committed_restart','mod_fmr_production_application_bootstrap']:visit(n)
        ordered.append(ROOT/'src/legacy/b1_10_port/headcalc.f90')
        for o in(0,2):
            d=objbase/f'o{o}';d.mkdir()
            flags=['-std=f2008','-ffree-line-length-none','-w','-fopenmp','-fcheck=all','-fbacktrace','-ffpe-trap=invalid,zero,overflow',f'-O{o}','-J',str(d),'-I',str(d)]
            for p in ordered:subprocess.run(['gfortran',*flags,'-c',str(p),'-o',str(d/(p.stem+'.o'))],check=True)
    harness=ROOT/'tests/frost/test_ppa_wu05b19_divdra_runtime.f90';receipts={};tasks=[]
    for o in(0,2):
        d=build/f'o{o}';d.mkdir();mods=objbase/f'o{o}'
        subprocess.run(['gfortran','-std=f2008','-ffree-line-length-none','-w','-fopenmp','-fcheck=all','-fbacktrace','-ffpe-trap=invalid,zero,overflow',f'-O{o}','-I',str(mods),str(harness),*[str(mods/(p.stem+'.o'))for p in ordered],'-o',str(d/'test')],check=True)
        for family in range(1,7):tasks.append((o,family,d))
    def execute(task):
        o,family,d=task;out=d/f'family-{family}.txt';err=d/f'family-{family}.err'
        with out.open('w')as so,err.open('w')as se:
            r=subprocess.run([str(d/'test'),str(family),a.route],stdout=so,stderr=se,env={**os.environ,'GFORTRAN_UNBUFFERED_ALL':'y'})
        receipt=dict(route=a.route,optimization=o,family=family,production_source=SOURCE,harness_sha256=sha(harness),executable_sha256=sha(d/'test'),stdout_sha256=sha(out),stderr_sha256=sha(err),exit_code=r.returncode,complete_case=r.returncode==0)
        (d/f'family-{family}.receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
        assert r.returncode==0,(receipt,err.read_text()[-2000:])
        text=out.read_text();n=2 if a.route=='normal'else 6
        assert text.count('B19_PRIMARY ')==n and text.count('B19_FINE ')==n and text.count('B19_RUNTIME_PASS ')==1
        print(f'B19_{a.route.upper()}_O{o}_FAMILY_{family}_COMPLETE=PASS',flush=True)
        return f'o{o}/family-{family}',receipt
    with concurrent.futures.ThreadPoolExecutor(max_workers=a.workers)as pool:
        for future in concurrent.futures.as_completed([pool.submit(execute,t)for t in tasks]):
            k,r=future.result();receipts[k]=r
    for family in range(1,7):assert (build/f'o0/family-{family}.txt').read_bytes()==(build/f'o2/family-{family}.txt').read_bytes(),family
    result=dict(work_unit='PPA-WU05B19',status='LOCAL_COMPLETE_PRIMARY_RUNTIME_PASS_NOT_ADMITTED',route=a.route,production_source=SOURCE,whole_module_sources=len(ordered),source_sha256={str(p):sha(p)for p in ordered},harness_sha256=sha(harness),driver_sha256=sha(Path(__file__)),build=str(build),whole_cases=12,primary_trajectories_per_optimization=12 if a.route=='normal'else 36,reference_steps=8192 if a.route=='normal'else 65536,O0_O2_stdout_byte_identity=True,case_receipts=receipts)
    Path(a.record).write_text(json.dumps(result,indent=2)+'\n');print(f'B19_{a.route.upper()}_ALL_PRIMARY_RUNTIME=PASS BUILD={build}',flush=True)
if __name__=='__main__':main()
