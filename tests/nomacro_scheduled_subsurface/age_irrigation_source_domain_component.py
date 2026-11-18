"""Actual original module storage for the distinct fixed age-source domain."""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import subprocess
import time
ROOT=Path(__file__).resolve().parents[2]
DRIVER="program component\nuse MOD_grid,only:numnod\nuse MOD_swap_base,only:swmacro,swsolu,swirfix,swhyst\nuse hybrid_age_irrigation_source_domain\nuse,intrinsic::ieee_arithmetic,only:ieee_value,ieee_quiet_nan\nimplicit none\ncharacter(500)::action,path,arg\ninteger::unit,layout,before(5),marker\nreal(8)::age\ncall get_command_argument(1,action);call get_command_argument(2,path)\ncall get_command_argument(3,arg);read(arg,*)layout\nnumnod=3;swmacro=0;swsolu=2;swirfix=1;swhyst=merge(2,0,layout==7)\ncall hybrid_age_irrigation_source_register(3)\nselect case(trim(action))\ncase('bad-nodes');numnod=0\ncase('bad-macro');swmacro=1\ncase('bad-kind');swsolu=1\ncase('bad-fixed');swirfix=0\ncase('bad-hys');swhyst=3\ncase('bad-layout');layout=8\nend select\nbefore=[numnod,swmacro,swsolu,swirfix,swhyst]\nif(index(trim(action),'age-')==1)then\n select case(trim(action))\n case('age-zero');age=0d0\n case('age-positive');age=20d0\n case('age-upper');age=1000d0\n case('age-negative');age=-1d0\n case('age-overflow');age=1001d0\n case('age-nan');age=ieee_value(1d0,ieee_quiet_nan)\n end select\n call hybrid_age_irrigation_source_assert(age)\nelse if(trim(action)=='write'.or.index(trim(action),'bad-')==1)then\n open(newunit=unit,file=trim(path),access='stream',form='unformatted',status='new')\n call hybrid_age_irrigation_source_checkpoint(unit,.false.,layout)\n write(unit)int(z'12345678');close(unit)\nelse\n open(newunit=unit,file=trim(path),access='stream',form='unformatted',status='old')\n call hybrid_age_irrigation_source_checkpoint(unit,.true.,layout)\n read(unit)marker;close(unit)\n if(marker/=int(z'12345678'))error stop 'Age source domain consumed foreign stream bytes'\nend if\nif(any(before/=[numnod,swmacro,swsolu,swirfix,swhyst]))error stop 'Domain mutated original live flags'\nwrite(*,'(a)')'ACTUAL_ORIGINAL_AGE_IRRIGATION_SOURCE_DOMAIN_PASS'\nend program\n"


def main():
 p=argparse.ArgumentParser()
 for key in ('reference-work','output'):p.add_argument('--'+key,type=Path,required=True)
 a=p.parse_args();a.output=a.output.resolve();a.output.mkdir();provider=a.reference_work/'build';objects=provider/'swap-obj';tt=provider/'ttutil-obj';source=ROOT/'app/hybrid_water/age_irrigation_source_domain.f90';sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
 q=dict(status='RUNNING',source_sha256=sha(source),provider_objects={p.name:sha(p) for p in objects.glob('*.o')},library_sha256=sha(tt/'libttutil.a'),profiles={})
 def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
 def call(cmd,cwd,label):
  t=time.monotonic();r=subprocess.run(list(map(str,cmd)),cwd=cwd,capture_output=True,text=True,timeout=60);(cwd/(label+'.stdout')).write_text(r.stdout);(cwd/(label+'.stderr')).write_text(r.stderr);return dict(returncode=r.returncode,seconds=time.monotonic()-t,stdout=r.stdout,stderr=r.stderr)
 try:
  for opt in ('O0','O2'):
   build=a.output/opt;build.mkdir();(build/'driver.f90').write_text(DRIVER);(build/source.name).write_bytes(source.read_bytes());flags=['-'+opt,'-ffree-line-length-none','-fcheck=all','-fbacktrace','-ffp-contract=off','-J'+str(build),'-I'+str(build),'-I'+str(objects),'-I'+str(tt)]
   r=call(['gfortran',*flags,'-c',source,build/'driver.f90'],build,'compile');assert r['returncode']==0,r
   closure=[p for p in sorted(objects.glob('*.o')) if p.stem.lower()!='swap_main'];exe=build/'component.exe';linked=[build/(source.stem+'.o'),build/'driver.o',*closure,tt/'libttutil.a'];r=call(['gfortran','-o',exe,*linked],build,'link');assert r['returncode']==0,r
   record=dict(flags=flags,source_sha256=sha(build/source.name),actual_original_storage=True,executable_sha256=sha(exe),actual_link_closure={str(p):sha(p) for p in linked},contexts={},invalid_live=[],age_values={});q['profiles'][opt]=record
   for layout in range(2,8):
    name='layout'+str(layout);path=build/(name+'.bin');r=call([exe,'write',path,layout],build,name+'-write');assert r['returncode']==0,r
    h=[1,3,0,2,1,2 if layout==7 else 0,layout];raw=path.read_bytes();assert raw==struct.pack('<15i',*h,*h,0x12345678)
    r=call([exe,'read',path,layout],build,name+'-read');assert r['returncode']==0,r;refused=[]
    attacks={}
    for field in range(7):
     bad=bytearray(raw)
     for offset in (field*4,28+field*4):struct.pack_into('<i',bad,offset,h[field]+1)
     attacks['field'+str(field)]=bytes(bad)
    bad=bytearray(raw);struct.pack_into('<i',bad,28,2);attacks['witness']=bytes(bad);attacks['truncated']=raw[:55]
    for label,data in attacks.items():
     target=build/(name+'-'+label+'.bin');target.write_bytes(data);r=call([exe,'read',target,layout],build,name+'-'+label);assert r['returncode']!=0 and 'original irrigation age domain' in r['stderr'],r;refused.append(dict(attack=label,**r))
    record['contexts'][name]=dict(exact_fifty_six_byte_headers=True,stream_position_exact=True,live_flags_unchanged=True,refusals=refused)
   for action in ('bad-nodes','bad-macro','bad-kind','bad-fixed','bad-hys','bad-layout'):
    r=call([exe,action,build/(action+'.bin'),2],build,action);assert r['returncode']!=0 and 'Invalid original irrigation age domain' in r['stderr'],r;record['invalid_live'].append(dict(attack=action,**r))
   for action in ('age-zero','age-positive','age-upper','age-negative','age-overflow','age-nan'):
    r=call([exe,action,'unused',2],build,action);assert (r['returncode']==0)==(action in ('age-zero','age-positive','age-upper')),r;record['age_values'][action]=r
   save();print(opt,'ACTUAL_AGE_SOURCE_DOMAIN_SIX_LAYOUTS_60_NATIVE_REFUSALS_AND_AGE_RANGE_PASS',flush=True)
  assert q['provider_objects']=={p.name:sha(p) for p in objects.glob('*.o')} and q['library_sha256']==sha(tt/'libttutil.a')
  q['status']='AGE_IRRIGATION_SOURCE_DOMAIN_O0_O2_TWELVE_LAYOUTS_120_NATIVE_AND_SIX_AGE_REFUSALS_PASS'
 except Exception as error:q.update(status='FAILED',error=repr(error));raise
 finally:save()


if __name__=='__main__':main()
