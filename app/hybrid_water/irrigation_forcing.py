"""Bounded opt-in original no-macro surface-event consumer and incremental build."""
import copy
import json
from pathlib import Path
import shutil
import subprocess

import daily_host as h
from donor_sources import replace

INPUT = 'hybrid-irrigation-day.in'


def render(source):
    # This logical is automatic per invocation, not part of the saved physics.
    source = replace(source, '      real(8)::afgen',
                     '      logical::hybrid_external_handled\n      real(8)::afgen')
    source = replace(source, '         ! fixed irrigations events',
                     '         call hybrid_external_fixed(hybrid_external_handled)\n'
                     '         if (.not.hybrid_external_handled) then\n'
                     '         ! fixed irrigations events')
    source = replace(source, '         ! scheduled timing within desired period?',
                     '         end if ! explicit external fixed event\n'
                     '         ! scheduled timing within desired period?')
    procedure = '''
   subroutine hybrid_external_fixed(handled)
      use variables,only:t1900
      use MOD_swap_base,only:swirfix,swsolu
      use ieee_arithmetic,only:ieee_is_finite
      implicit none
      logical,intent(out)::handled
      integer::unit,ios,enabled
      real(8)::clock,depth,concentration,rate
      character(len=16)::version
      character(len=1)::extra
      inquire(file='hybrid-irrigation-day.in',exist=handled)
      if(.not.handled)return
      open(newunit=unit,file='hybrid-irrigation-day.in',status='old',action='read',iostat=ios)
      if(ios/=0)error stop 'Unreadable external irrigation'
      read(unit,*,iostat=ios)version,clock,enabled,depth,concentration,rate
      if(ios/=0)error stop 'Incomplete external irrigation'
      read(unit,*,iostat=ios)extra
      close(unit)
      if(ios>=0)error stop 'Trailing external irrigation input'
      if(version/='S5IRR001')error stop 'Foreign external irrigation protocol'
      if(.not.all(ieee_is_finite([clock,depth,concentration,rate]))) &
         error stop 'Nonfinite external irrigation'
      if(clock/=t1900.or.schedule/=0.or.swirfix/=1.or.swsolu/=1) &
         error stop 'Foreign external irrigation clock or mode'
      if(enabled/=0.and.enabled/=1)error stop 'Invalid external irrigation switch'
      if(enabled==0)then
         if(any([depth,concentration,rate]/=0d0))error stop 'Nonzero disabled irrigation'
      else
         if(depth<0.01d0.or.depth>100d0.or.concentration<0d0.or.concentration>1000d0.or. &
            rate<=0d0.or.rate>100d0)error stop 'External irrigation outside original range'
         if(depth/(24d0*rate)>1d0)error stop 'External irrigation exceeds one day'
      end if
      ! Retain the original future table; suppress an original same-date event once.
      if(nirri<1.or.nirri>mairg)error stop 'Invalid original irrigation cursor'
      if(abs(irdate(nirri)-t1900)<1d-3)nirri=nirri+1
      if(enabled==1)then
         ! Original read_irrigation_fixed conversions, followed by task3 assignments.
         depth=0.1d0*depth
         rate=0.1d0*24d0*rate
         isua=1
         gird=rate
         cirr=concentration
         dt_irr_event=depth/rate
         irrigevent=1
      end if
      write(*,'(a,1x,f16.8,1x,i0,3(1x,es25.17e3))') &
         'HYBRID_IRRIGATION_INPUT',clock,enabled,depth,concentration,rate
   end subroutine
'''
    return replace(source, 'end module MOD_irrigation', procedure+'\nend module MOD_irrigation')


def build_bundle(base, reference, target, project=h.HUPSEL):
    """Compile one module; preserve the validated original kernel and other objects."""
    from daily_coupling import validate_bundle
    base,reference,target=map(Path,(base,reference,target))
    if project not in (h.HUPSEL,h.SALTFARM):raise ValueError('Unsupported surface irrigation project')
    meta,_=validate_bundle(base,reference,project)
    identity=copy.deepcopy(meta['identity'])
    if 'irrigation_extension' in identity:raise ValueError('Already extended irrigation bundle')
    if subprocess.check_output(['gfortran','-dumpmachine'],text=True).strip()!=identity['target']:
        raise ValueError('Different compiler target')
    if h.sha(Path(shutil.which('gfortran')))!=identity['compiler_sha256']:
        raise ValueError('Different incremental compiler')
    objects=reference/'build/swap-obj';ttutil=reference/'build/ttutil-obj'
    for name,digest in identity['donor_objects'].items():
        if h.sha(objects/name)!=digest:raise ValueError('Foreign original donor object: '+name)
    if h.sha(ttutil/'libttutil.a')!=identity['ttutil_library']:raise ValueError('Foreign original TTUTIL library')
    target.mkdir()
    for p in base.iterdir():
        if p.is_file() and (p.suffix.lower() in ('.o','.mod','.smod','.f90') or p.name.startswith('day_')):
            shutil.copyfile(p,target/p.name)
    generated=target/'irrigation.f90'
    generated.write_text(render(generated.read_text(encoding='cp1252')),encoding='cp1252')
    commands=[['gfortran',*identity['donor_flags'],'-I',str(objects),'-I',str(ttutil),'-c','irrigation.f90']]
    replacements={Path(n).with_suffix('.o').name:target/Path(n).with_suffix('.o').name
                  for n in identity['donor_generated']}
    commands.append(['gfortran','-o',str(h.executable(target,'day_donor')),
        *(str(replacements.get(p.name,p)) for p in sorted(objects.glob('*.o'))),
        *([str(target/'hybrid_step_budget.o')] if meta['binding']['budget_retry'] else []),str(ttutil/'libttutil.a')])
    logs=[]
    for command in commands:
        completed=subprocess.run(command,cwd=target,capture_output=True,text=True,timeout=90)
        logs.append({'command':command,'exit_code':completed.returncode,'stdout':completed.stdout,'stderr':completed.stderr})
        (target/'INCREMENTAL_BUILD.json').write_text(json.dumps(logs,indent=2)+'\n')
        if completed.returncode:raise ValueError('Incremental irrigation build failed')
    identity['donor_generated']['irrigation.f90']=h.sha(generated)
    identity['irrigation_extension']={'source_sha256':h.sha(Path(__file__)),'protocol':'S5IRR001',
        'original_irrigation_sha256':meta['identity']['donor_generated']['irrigation.f90'],
        'object_sha256':h.sha(target/'irrigation.o')}
    meta['identity']=identity;meta['binding']={**meta['binding'],'build':identity}
    meta['executable_sha256']['donor']=h.sha(h.executable(target,'day_donor'))
    (target/'BUILD.json').write_text(json.dumps(meta,indent=2)+'\n')
    return target
