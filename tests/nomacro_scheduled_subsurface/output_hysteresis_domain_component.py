"""Native process-domain ABI against real original grid/base module storage."""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import subprocess
import time

ROOT=Path(__file__).resolve().parents[2]
DRIVER='''program domain_component
use MOD_grid,only:numnod
use MOD_swap_base,only:swmacro,swhyst,swsolu
use hybrid_output_hysteresis_domain
implicit none
character(500)::action,path,arg
integer::unit,before(4),after(4),marker
call get_command_argument(1,action);call get_command_argument(2,path)
call get_command_argument(3,arg);read(arg,*)swhyst
call get_command_argument(4,arg);read(arg,*)swsolu
numnod=3;swmacro=0
select case(trim(action))
case('bad-nodes');numnod=0
case('bad-macro');swmacro=1
case('bad-hys');swhyst=0
case('bad-kind');swsolu=3
end select
before=[numnod,swmacro,swhyst,swsolu]
if(trim(action)=='write'.or.index(trim(action),'bad-')==1)then
 open(newunit=unit,file=trim(path),access='stream',form='unformatted',status='new')
 call hybrid_output_hysteresis_checkpoint(unit,.false.)
 write(unit)int(z'12345678');close(unit)
else
 open(newunit=unit,file=trim(path),access='stream',form='unformatted',status='old')
 call hybrid_output_hysteresis_checkpoint(unit,.true.)
 read(unit)marker;close(unit)
 if(marker/=int(z'12345678'))error stop 'Original hysteresis domain consumed foreign stream bytes'
end if
after=[numnod,swmacro,swhyst,swsolu]
if(any(before/=after))error stop 'Domain codec mutated live original flags'
write(*,'(a)')'ACTUAL_ORIGINAL_HYSTERESIS_DOMAIN_PASS'
end program
'''


def main():
    p=argparse.ArgumentParser();p.add_argument('--reference-work',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();a.output=a.output.resolve();a.output.mkdir();provider=a.reference_work/'build';objects=provider/'swap-obj';tt=provider/'ttutil-obj'
    sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();source=ROOT/'app/hybrid_water/original_output_hysteresis_domain.f90'
    q=dict(status='RUNNING',scope='Original output process-domain metadata only; no physical state or equation',source_sha256=sha(source),profiles={},provider_objects={p.name:sha(p) for p in objects.glob('*.o')},library_sha256=sha(tt/'libttutil.a'))
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
    def call(cmd,cwd,label):
        start=time.monotonic();r=subprocess.run(list(map(str,cmd)),cwd=cwd,capture_output=True,text=True,timeout=60);(cwd/(label+'.stdout')).write_text(r.stdout);(cwd/(label+'.stderr')).write_text(r.stderr)
        return dict(returncode=r.returncode,seconds=time.monotonic()-start,stdout=r.stdout,stderr=r.stderr)
    try:
        for opt in ('O0','O2'):
            build=a.output/opt;build.mkdir();(build/'driver.f90').write_text(DRIVER);(build/source.name).write_bytes(source.read_bytes())
            flags=['-'+opt,'-ffree-line-length-none','-fcheck=all','-fbacktrace','-ffp-contract=off','-J'+str(build),'-I'+str(build),'-I'+str(objects),'-I'+str(tt)]
            r=call(['gfortran',*flags,'-c',source,build/'driver.f90'],build,'compile');assert r['returncode']==0,r['stderr']
            closure=[p for p in sorted(objects.glob('*.o')) if p.stem.lower()!='swap_main'];exe=build/'component.exe';r=call(['gfortran','-o',exe,build/(source.stem+'.o'),build/'driver.o',*closure,tt/'libttutil.a'],build,'link');assert r['returncode']==0,r['stderr']
            report=dict(flags=flags,source_sha256=sha(build/source.name),executable_sha256=sha(exe),actual_original_storage=True,link_closure={str(p):sha(p) for p in [build/(source.stem+'.o'),build/'driver.o',*closure,tt/'libttutil.a']},contexts={});q['profiles'][opt]=report
            for mode in (1,2):
                for kind in (0,1,2):
                    name='hys'+str(mode)+'-kind'+str(kind);raw=build/(name+'.bin');r=call([exe,'write',raw,mode,kind],build,name+'-write');assert r['returncode']==0,r
                    data=raw.read_bytes();header=[1,3,0,mode,kind];assert data==struct.pack('<11i',*header,*header,0x12345678)
                    r=call([exe,'read',raw,mode,kind],build,name+'-read');assert r['returncode']==0 and 'ACTUAL_ORIGINAL_HYSTERESIS_DOMAIN_PASS' in r['stdout'],r
                    attacks={}
                    for field,value in [(0,2),(1,4),(2,1),(3,3-mode),(4,(kind+1)%3)]:
                        bad=bytearray(data)
                        for offset in (4*field,20+4*field):struct.pack_into('<i',bad,offset,value)
                        attacks['foreign-field'+str(field)]=bytes(bad)
                    bad=bytearray(data);struct.pack_into('<i',bad,20,2);attacks['witness']=bytes(bad);attacks['truncated']=data[:39]
                    refused=[]
                    for label,body in attacks.items():
                        path=build/(name+'-'+label+'.bin');path.write_bytes(body);r=call([exe,'read',path,mode,kind],build,name+'-'+label);assert r['returncode']!=0 and 'original output hysteresis domain' in r['stderr'],r;refused.append(dict(attack=label,**r))
                    report['contexts'][name]=dict(exact_forty_byte_header=True,stream_position_exact=True,live_flags_unchanged=True,native_refusals=refused)
            report['invalid_live_domains']=[]
            for label in ('bad-nodes','bad-macro','bad-hys','bad-kind'):
                r=call([exe,label,build/(label+'.bin'),1,0],build,label);assert r['returncode']!=0 and 'Invalid original output hysteresis domain' in r['stderr'];report['invalid_live_domains'].append(dict(attack=label,**r))
            save();print(opt,'SIX_REAL_HYSTERESIS_DOMAIN_CONTEXTS_46_REFUSALS_PASS',flush=True)
        assert q['provider_objects']=={p.name:sha(p) for p in objects.glob('*.o')} and q['library_sha256']==sha(tt/'libttutil.a')
        q['status']='ORIGINAL_HYSTERESIS_DOMAIN_O0_O2_TWELVE_CONTEXTS_92_REFUSALS_PASS'
    except Exception as error:q.update(status='FAILED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
