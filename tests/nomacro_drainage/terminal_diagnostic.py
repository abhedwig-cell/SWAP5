"""Read-only receipt instrumentation in a separate actual compiled replay.

The producing bundle and BUILD remain immutable. This is a separately linked
diagnostic executable, never used for public qualification or rebinding.
"""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import zipfile

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'nomacro_scheduled_subsurface'))
import implicit_conductivity_runtime as prior
m=prior.m

def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()

def main():
    p=argparse.ArgumentParser()
    for k in ('profile-root','reference-work','build-root','output'):p.add_argument('--'+k,type=Path,required=True)
    p.add_argument('--origin-day',type=int,default=532);p.add_argument('--end-day',type=int,default=1054)
    a=p.parse_args();a.output.mkdir();a.build_root.mkdir(parents=True,exist_ok=False)
    q=json.loads((a.profile_root/'RESULT.json').read_text());build=Path(q['build_root']);project=m.e.load(Path(q['input_root']));meta,case=m.validate_bundle(build,a.reference_work,project)
    name='hybrid_extended_drain_terminal';original=build/(name+'.f90');source=original.read_text(encoding='cp1252')
    old='    use variables,only:tcum,dt';assert source.count(old)==1
    source=source.replace(old,old+',dtmin',1)
    old='    call terminal_water_terms(terms)';assert source.count(old)==1
    source=source.replace(old,old+"\n    if(dt<dtmin)write(*,'(a,30(1x,es25.17e3))')'EXTENDED_COMPLETE_FLOOR_TERMS',tcum,dt,terms",1)
    path=a.build_root/(name+'.f90');path.write_text(source,encoding='cp1252')
    provider=a.reference_work/'build/swap-obj';ttutil=a.reference_work/'build/ttutil-obj/libttutil.a'
    flags=['gfortran',*meta['identity']['donor_flags'],'-I',str(build),'-I',str(provider),'-J',str(a.build_root)]
    commands=[flags+['-c',str(path),'-o',str(a.build_root/(name+'.o'))]]
    objects={f.name:f for f in provider.glob('*.o')};objects.update({f.name:f for f in build.glob('*.o')});objects[name+'.o']=a.build_root/(name+'.o')
    exe=a.build_root/'diagnostic.exe';commands.append(['gfortran','-o',str(exe),*(str(objects[n]) for n in sorted(objects)),str(ttutil)])
    logs=[]
    for command in commands:
        r=subprocess.run(command,cwd=a.build_root,capture_output=True,text=True);logs.append(dict(command=command,returncode=r.returncode,stdout=r.stdout,stderr=r.stderr));assert r.returncode==0,r.stderr
    origin=a.output/'origin';package=a.profile_root/'trajectory'/f'accepted-column-1-day-{a.origin_day}.zip';before=sha(package)
    receipt=m.h.verify_checkpoint(package,a.origin_day,meta['binding'],origin)
    directory=a.output/'column';m.h.prepare_column(case,directory,m.h.ColumnStart('original',a.origin_day,origin,receipt),True,True,project)
    inputs=''.join(f'{day} -1\n' for day in range(a.origin_day+1,a.end_day+1))+'0 -1\n'
    r=subprocess.run([str(exe),'./swap.swp'],input=inputs,cwd=directory,capture_output=True,text=True,timeout=180)
    (a.output/'diagnostic.stdout').write_text(r.stdout,encoding='utf8');(a.output/'diagnostic.stderr').write_text(r.stderr,encoding='utf8')
    (a.output/'diagnostic.exe').write_bytes(exe.read_bytes());(a.output/path.name).write_bytes(path.read_bytes())
    assert sha(package)==before
    report=dict(status='ACTUAL_SEPARATE_READ_ONLY_DIAGNOSTIC_REPLAY',production_build_sha256=sha(build/'BUILD.json'),production_executable_sha256=sha(m.h.executable(build,'day_donor')),diagnostic_executable_sha256=sha(exe),original_terminal_source_sha256=sha(original),diagnostic_source_sha256=sha(path),object_sha256={str(f):sha(f) for f in objects.values()},compile=logs,origin_sha256=before,origin_day=a.origin_day,end_day=a.end_day,returncode=r.returncode,actual_day_returns=sum(line.startswith('HYBRID_DAY_RETURN ') for line in r.stdout.splitlines()),qualification=False)
    (a.output/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf8');print(report['status'],report['returncode'],report['actual_day_returns'])

if __name__=='__main__':main()
