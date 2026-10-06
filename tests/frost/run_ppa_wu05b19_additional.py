#!/usr/bin/env python3
"""Complete additional B19 one-call owner/held/app guards on validated fresh modules."""
from pathlib import Path
import argparse,hashlib,json,subprocess,tempfile
ROOT=Path(__file__).resolve().parents[2]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
    ap=argparse.ArgumentParser();ap.add_argument('--compiled-manifest',required=True);ap.add_argument('--record',required=True);a=ap.parse_args()
    m=json.loads(Path(a.compiled_manifest).read_text());assert m['production_source']==subprocess.check_output(['git','rev-parse','HEAD:src'],cwd=ROOT,text=True).strip()
    for f,h in m['source_sha256'].items():assert sha(Path(f))==h,f
    b=Path(tempfile.mkdtemp(prefix='ppa-wu05b19-additional-'));objbase=Path(m['build']);harness=ROOT/'tests/frost/test_ppa_wu05b19_additional.f90'
    for o in(0,2):
        d=b/f'o{o}';d.mkdir();mods=objbase/f'o{o}'
        subprocess.run(['gfortran','-std=f2008','-ffree-line-length-none','-w','-fopenmp','-fcheck=all','-fbacktrace','-ffpe-trap=invalid,zero,overflow',f'-O{o}','-I',str(mods),str(harness),*[str(mods/(Path(p).stem+'.o'))for p in m['source_sha256']],'-o',str(d/'test')],check=True)
        with(d/'output.txt').open('w')as out,(d/'error.txt').open('w')as err:subprocess.run([str(d/'test')],stdout=out,stderr=err,check=True)
        assert (d/'output.txt').read_text().strip()=='B19_ADDITIONAL_PASS committed=756 held=84 invalid_application=28'
    assert (b/'o0/output.txt').read_bytes()==(b/'o2/output.txt').read_bytes()
    r=dict(work_unit='PPA-WU05B19',status='LOCAL_COMPLETE_ADDITIONAL_GUARDS_PASS_NOT_ADMITTED',build=str(b),production_source=m['production_source'],committed_native_calls_per_optimization=756,held_calls_per_optimization=84,invalid_application_cases_per_optimization=28,O0_O2_byte_identity=True,harness_sha256=sha(harness),driver_sha256=sha(Path(__file__)),source_sha256=m['source_sha256'],executables={f'o{o}':sha(b/f'o{o}/test')for o in(0,2)},outputs={f'o{o}':sha(b/f'o{o}/output.txt')for o in(0,2)})
    Path(a.record).write_text(json.dumps(r,indent=2)+'\n');print('B19_COMPLETE_ADDITIONAL_O0_O2=PASS',flush=True)
if __name__=='__main__':main()
