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
    p.add_argument('--stable',action='store_true')
    a=p.parse_args();a.output.mkdir();a.build_root.mkdir(parents=True,exist_ok=False)
    q=json.loads((a.profile_root/'RESULT.json').read_text());build=Path(q['build_root']);project=m.e.load(Path(q['input_root']));meta,case=m.validate_bundle(build,a.reference_work,project)
    name='hybrid_extended_drain_terminal';original=build/(name+'.f90');source=original.read_text(encoding='cp1252')
    if a.stable:
        from extended_trial_receipt import render
        source=render(source)
    old=next(line for line in source.splitlines() if line.startswith('    use variables,only:tcum,dt'))
    fields=list(dict.fromkeys([*old.split(':',1)[1].split(','),'dtmin','t1900']))
    source=source.replace(old,'    use variables,only:'+','.join(fields),1)
    source=source.replace('    real(8) :: terms(28)', '''    use MOD_meteo,only:graidt,nraidt,aintcdt
    use MOD_irrigation,only:nird,gird
    use plant_interface,only:sw_inter,sicact,siccap,crsflx_in,crsflx_out
    use variables,only:isicbeg,ivolbeg,thetm1,theta
    use MOD_grid,only:numnod,dz
    real(8) :: terms(28)''',1)
    old='    call terminal_water_terms(terms)';assert source.count(old)==1
    # Use the separate error unit: HeadCalc also evaluates this function
    # inside its stdout WRITE diagnostics, where recursive stdout I/O refuses.
    source=source.replace(old,old+"\n    if(t1900>=38309d0)write(0,'(a,30(1x,es25.17e3))')'EXTENDED_COMPLETE_FLOOR_TERMS',tcum,dt,terms",1)
    source=source.replace(old,old+"\n    if(t1900>=38309d0)write(0,'(a,16(1x,es25.17e3))')'EXTENDED_GROSS_NET_DIAGNOSTIC',dt,graidt,nraidt,aintcdt,gird,nird,sicact,siccap,crsflx_in,crsflx_out,isicbeg,ivolbeg,sum(thetm1(1:numnod)*dz(1:numnod)),sum(theta(1:numnod)*dz(1:numnod)),sum((theta(1:numnod)-thetm1(1:numnod))*dz(1:numnod)),real(sw_inter,8)",1)
    path=a.build_root/(name+'.f90');path.write_text(source,encoding='cp1252')
    provider=a.reference_work/'build/swap-obj';ttutil=a.reference_work/'build/ttutil-obj/libttutil.a'
    flags=['gfortran',*meta['identity']['donor_flags'],'-I',str(build),'-I',str(provider),'-J',str(a.build_root)]
    commands=[flags+['-c',str(path),'-o',str(a.build_root/(name+'.o'))]]
    head=a.build_root/'headcalc.f90';body=(build/'headcalc.f90').read_text(encoding='cp1252')
    assert body.count('      if(dt<=dtmin)then')==1
    head.write_text(body.replace('      if(dt<=dtmin)then','      if(t1900>=38309d0)then',1),encoding='cp1252')
    commands.append(flags+['-c',str(head),'-o',str(a.build_root/'headcalc.o')])
    objects={f.name:f for f in provider.glob('*.o')};objects.update({f.name:f for f in build.glob('*.o')});objects[name+'.o']=a.build_root/(name+'.o')
    objects['headcalc.o']=a.build_root/'headcalc.o'
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
    (a.output/'headcalc.f90').write_bytes(head.read_bytes())
    assert sha(package)==before
    report=dict(status='ACTUAL_SEPARATE_READ_ONLY_DIAGNOSTIC_REPLAY',production_build_sha256=sha(build/'BUILD.json'),production_executable_sha256=sha(m.h.executable(build,'day_donor')),diagnostic_executable_sha256=sha(exe),original_terminal_source_sha256=sha(original),diagnostic_source_sha256=sha(path),object_sha256={str(f):sha(f) for f in objects.values()},compile=logs,origin_sha256=before,origin_day=a.origin_day,end_day=a.end_day,returncode=r.returncode,actual_day_returns=sum(line.startswith('HYBRID_DAY_RETURN ') for line in r.stdout.splitlines()),qualification=False)
    (a.output/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf8');print(report['status'],report['returncode'],report['actual_day_returns'])

if __name__=='__main__':main()
