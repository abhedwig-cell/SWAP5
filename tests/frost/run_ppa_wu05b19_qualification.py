#!/usr/bin/env python3
"""Whole-module B19 runtime qualification; each trajectory in a fresh process."""
import argparse,concurrent.futures,hashlib,json,os,pathlib,subprocess,time
ROOT=pathlib.Path(__file__).resolve().parents[2]
a=argparse.ArgumentParser();a.add_argument('--build',type=pathlib.Path,required=True);a.add_argument('--workers',type=int,default=2)
a.add_argument('--cases',nargs='+',type=int,default=list(range(1,25)));a.add_argument('--fine',type=int,default=8192)
a.add_argument('--opts',nargs='+',type=int,choices=[0,2],default=[0,2]);args=a.parse_args()
p=json.loads((ROOT/'integration/audits/PPA_WU05B19_PREREGISTRATION.json').read_text())
source=subprocess.check_output(['git','rev-parse','HEAD:src'],cwd=ROOT,text=True).strip()
assert source==p['candidate_source']
assert not subprocess.check_output(['git','diff','--name-only','HEAD','--','src','tests/frost'],cwd=ROOT,text=True).strip()
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
for path,h in p['source_sha256'].items():assert sha(ROOT/path)==h,path
src=ROOT/'tests/frost/test_ppa_wu05b19_divdra_runtime.f90'
for opt in args.opts:
    b=args.build/f'o{opt}';assert (b/'mod_fmr_serialized_reference_backend.o').exists()
    flags=['-std=f2008','-ffree-line-length-none','-w','-fopenmp','-fcheck=all','-fbacktrace','-ffpe-trap=invalid,zero,overflow',f'-O{opt}','-J'+str(b),'-I'+str(b)]
    obj=b/'test_ppa_wu05b19_divdra_runtime.o';exe=b/'test'
    subprocess.run(['gfortran',*flags,'-c',str(src),'-o',str(obj)],check=True)
    objects=sorted(str(f)for f in b.glob('*.o')if not f.name.startswith('test_'))
    subprocess.run(['gfortran','-fopenmp',f'-O{opt}',*objects,str(obj),'-o',str(exe)],check=True)
    def execute(case):
        stem=b/f'case-{case}-fine-{args.fine}';so=stem.with_suffix('.log');se=stem.with_suffix('.err');started=time.monotonic()
        with so.open('w')as out,se.open('w')as err:
            cp=subprocess.run([str(exe),str(case),str(args.fine)],stdout=out,stderr=err,env={**os.environ,'GFORTRAN_UNBUFFERED_ALL':'y'})
        text=so.read_text();result={'case':case,'fine_steps':args.fine,'optimization':opt,'production_source':source,'test_sha256':sha(src),'executable_sha256':sha(exe),'stdout_sha256':sha(so),'stderr_sha256':sha(se),'exit_code':cp.returncode,'elapsed_s':time.monotonic()-started}
        stem.with_suffix('.receipt.json').write_text(json.dumps(result,indent=2)+'\n')
        assert cp.returncode==0,(case,opt,so)
        assert f'B19_CASE_{case}_RUNTIME=PASS' in text and 'B19_APPLICATION=PASS' in text and text.count('B19_FINE_COMPARISON')==1
        print(f'B19_O{opt}_CASE_{case}_FINE_{args.fine}=PASS',flush=True)
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.workers)as pool:
        for future in concurrent.futures.as_completed([pool.submit(execute,c)for c in args.cases]):future.result()
if args.opts==[0,2]:
    for case in args.cases:
        assert (args.build/f'o0/case-{case}-fine-{args.fine}.log').read_bytes()==(args.build/f'o2/case-{case}-fine-{args.fine}.log').read_bytes(),case
    print('B19_RUNTIME_O0_O2_BYTE_IDENTITY=PASS',flush=True)
