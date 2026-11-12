"""Read-only observation of actual original numerical timestep rollback.

Uses original own14 and unchanged driver/physics. The new executable is recorded
as instrumentation, never rebound to the original native package's identity.
"""
import argparse
import contextlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import threading
import time
import traceback

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'app/hybrid_water'))
import daily_host as h
from daily_coupling import validate_bundle
from donor_sources import replace

FIELDS={
    'ICpBtDm':'original_restored', 'VlMpDmCp':'original_restored', 'WaUnMpDmCp':'original_restored',
    'FlEndSrpEvt':'event_history','ThtSrpRefDmCp':'event_history','SorpDmCp':'event_history',
    'TimAbsCumDmCp':'event_history','VlMpDyCp':'geometry_history','SubsidCp':'geometry_history',
    'FrMpWalWet':'geometry','ICpBtDmPot':'geometry','ICpTpWaSrDm':'geometry',
    'ZWaLevDm':'geometry','ZBtDm':'geometry','VlMpDm':'geometry','VlMp':'geometry',
    'ArMpTp':'geometry','ArMpTpDm':'geometry','ArMpSs':'geometry','KsMpSs':'geometry',
    'FrArMtrx':'geometry','WaSrMp':'stock','WaSrMpDm':'stock','WaUnMpDm':'stock','WaUnsat':'stock'}


def render(source,variables):
    definitions={}
    for line in (source.split('contains',1)[0]+'\n'+variables.split('module MOD_swap_mp\n',1)[1].split('end module',1)[0]).splitlines():
        m=re.match(r'\s*(real\(8\)|integer|logical)\s*,(.*?)save\s*::\s*(\w+)\s*=',line,re.I)
        if m:
            dims=re.search(r'dimension\(([^)]+)\)',m[2],re.I)
            definitions[m[3].lower()]=(m[1],dims[1].lower().split(',') if dims else [])
    decl=[];capture=[];checks=[];schema=[]
    for number,(name,category) in enumerate(FIELDS.items(),1):
        kind,dims=definitions[name.lower()]
        assert set(dims)<={'madm','macp'}
        section='('+','.join('1:'+{'madm':'NumDm','macp':'NumNod'}[d] for d in dims)+')' if dims else ''
        decl.append(f'      {kind}'+(', allocatable' if dims else '')+f' :: {name}'+('('+','.join(':' for _ in dims)+')' if dims else ''))
        capture.append(f'         rollback_before%{name} = {name}{section}')
        before=f'rollback_before%{name}';after=name+section
        comparison=f'{before} .neqv. {after}' if kind.lower()=='logical' else f'{before} /= {after}'
        if dims:
            counter=f'count({comparison})'
            maximum=f'maxval(abs(real({after},8)-real({before},8)))' if kind.lower()!='logical' else f'real(changes({number}),8)'
        else:
            counter=f'merge(1,0,{comparison})'
            maximum=f'abs(real({after},8)-real({before},8))' if kind.lower()!='logical' else f'real(changes({number}),8)'
        checks+= [f'         changes({number}) = {counter}',f'         maxima({number}) = {maximum}',
            f'         if (changes({number}) > 0 .and. .not. witnessed({number})) then',
            f"            open(newunit=unit,file='rollback-{name}.txt',status='new',action='write')",
            f"            write(unit,*) 'ORIGIN', {before}",f"            write(unit,*) 'RESTORED', {after}",
            '            close(unit)',f'            witnessed({number}) = .true.','         end if']
        schema.append({'field':name,'kind':kind,'dimensions':dims,'category':category})
    declarations='   type rollback_observation_state\n'+'\n'.join(decl)+'\n   end type\n'+f'''   type(rollback_observation_state), save :: rollback_before
   logical, save :: rollback_seen = .false., witnessed({len(FIELDS)}) = .false.
   integer, save :: rollback_observation_count = 0
'''
    routine='''
   subroutine observe_numerical_rollback(task)
      use MOD_grid, only: numnod
      use variables, only: t1900,dt
      use hybrid_day_window, only: budget_retries
      integer, intent(in) :: task
'''+f'      integer :: unit, changes({len(FIELDS)})\n      real(8) :: maxima({len(FIELDS)})\n'+'''      if (task == 1) then
'''+ '\n'.join(capture)+'''
         rollback_seen = .true.
      else if (task == 2) then
         if (.not. rollback_seen) error stop 'Rollback without observed origin'
         rollback_observation_count = rollback_observation_count+1
'''+ '\n'.join(checks)+'''
         open(newunit=unit,file='numerical-rollback.txt',status='unknown',position='append',action='write')
         write(unit,*) 'REJECT',rollback_observation_count,t1900,dt,budget_retries,IDecMpRat,FlDecMpRat
         write(unit,*) 'COUNTS',changes
         write(unit,*) 'MAXIMA',maxima
         close(unit)
      end if
   end subroutine observe_numerical_rollback
'''
    source=replace(source,'   contains\n',declarations+'\n   contains\n'+routine)
    a=source.index('      SUBROUTINE MACROSTATEVAR (task)');b=source.index('    end subroutine MacroStateVar',a)
    source=source[:a]+replace(source[a:b],'      return','      call observe_numerical_rollback(task)\n      return')+source[b:]
    return source,schema


def main():
    p=argparse.ArgumentParser(description=__doc__)
    for name in ('bundle','reference','checkpoint','control','output'):p.add_argument('--'+name,type=Path,required=True)
    a=p.parse_args();a.output.mkdir(parents=True,exist_ok=False)
    report={'status':'RUNNING','new_full_runs':0,'window':[14,16],'cap_seconds':20,
        'source':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()}
    def persist():(a.output/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n')
    persist()
    try:
        meta,case=validate_bundle(a.bundle,a.reference,h.ANDELST)
        receipt=h.verify_checkpoint(a.checkpoint,14,meta['binding'],a.output/'origin')
        control=json.loads((a.control/'RESULT.json').read_text())
        assert control['status']=='OWN_RESTART_WINDOW_COMPLETE'
        assert control['build']==meta and control['origin_day']==14 and control['end_day']==16
        report.update(original_build=meta,origin_sha256=h.sha(a.checkpoint))
        build=a.output/'build';shutil.copytree(a.bundle,build)
        variables=(a.reference/'build/swap-selected/variables.f90').read_text(encoding='cp1252')
        source,schema=render((build/'macropore.f90').read_text(encoding='cp1252'),variables)
        (build/'macropore.f90').write_text(source,encoding='cp1252');report['fields']=schema
        identity=meta['identity'];objects=a.reference/'build/swap-obj';ttutil=a.reference/'build/ttutil-obj'
        assert h.sha(Path(shutil.which('gfortran')))==identity['compiler_sha256']
        for n,sha in identity['donor_objects'].items():assert h.sha(objects/n)==sha
        commands=[['gfortran',*identity['donor_flags'],'-I',str(objects),'-I',str(ttutil),'-c',name] for name in ['macropore.f90','headcalc.f90','swap_main.f90']]
        replacements={Path(n).with_suffix('.o').name:build/Path(n).with_suffix('.o').name for n in identity['donor_generated']}
        commands.append(['gfortran','-o',str(h.executable(build,'day_donor')),
            *(str(replacements.get(f.name,f)) for f in sorted(objects.glob('*.o'))),str(build/'hybrid_step_budget.o'),str(ttutil/'libttutil.a')])
        logs=[]
        for command in commands:
            started=time.perf_counter();r=subprocess.run(command,cwd=build,capture_output=True,text=True,timeout=30)
            logs.append({'command':command,'seconds':time.perf_counter()-started,'exit_code':r.returncode,'stderr':r.stderr})
            (a.output/'BUILD_LOG.json').write_text(json.dumps(logs,indent=2)+'\n')
            assert r.returncode==0,r.stderr
        report['observer_identity']={'script_sha256':h.sha(Path(__file__)),'generated_macro_sha256':h.sha(build/'macropore.f90'),
            'executable_sha256':h.sha(h.executable(build,'day_donor')),'purpose':'Read-only observation, no original checkpoint rebinding/publication'}
        out=a.output/'observation';out.mkdir();workers=[];expired=threading.Event();requests=[]
        original_start=h.start_process;original_send=h.send
        def start(*args,**kwargs):
            x=original_start(*args,**kwargs);workers.append(x[0]);return x
        def send(worker,message):
            if message=='16 -1':requests.append(message);message='16 35811'
            return original_send(worker,message)
        def timeout():
            expired.set()
            for w in workers:
                if w.poll() is None:w.kill()
        h.start_process=start;h.send=send;started=time.perf_counter();timer=threading.Timer(20,timeout);timer.start();rows=[]
        try:
            with contextlib.ExitStack() as stack:
                host=h.DailyHost(stack,h.executable(build,'day_donor'),h.executable(a.bundle,'day_kernel'),case,out,
                    [h.ColumnStart(day=14,origin=a.output/'origin',receipt=receipt,name='original')],
                    runtime=True,checkpoint_enabled=True,binding=None)
                for expected in control['rows']:
                    row=host.step(1);rows.append(row)
                    assert {k:v for k,v in row.items() if k!='revision'}=={k:v for k,v in expected.items() if k!='revision'}
                host.close()
        finally:
            timer.cancel();h.start_process=original_start;h.send=original_send
            for w in workers:
                if w.poll() is None:w.kill()
                w.wait(timeout=5)
            report.update(seconds=time.perf_counter()-started,expired=expired.is_set(),rows=rows);persist()
        assert not expired.is_set() and len(requests)==1 and len(rows)==2
        import zipfile
        with zipfile.ZipFile(a.control/'accepted-column-1-day-16.zip') as z:
            for n in h.CHECKPOINT_FILES:assert (out/'original'/n).read_bytes()==z.read(n)
        log=out/'original/numerical-rollback.txt';lines=log.read_text().splitlines()
        assert len(lines)%3==0 and len(lines)>0
        records=[(lines[i].split(),list(map(int,lines[i+1].split()[1:])),list(map(float,lines[i+2].split()[1:]))) for i in range(0,len(lines),3)]
        report['rollback_count']=len(records)
        report['field_results']=[{**field,'changed_rejections':sum(c[j]>0 for _,c,_ in records),
            'maximum_changed_elements':max(c[j] for _,c,_ in records),'maximum_difference':max(m[j] for _,_,m in records)} for j,field in enumerate(schema)]
        report['native_endpoint_hashes']={n:h.sha(out/'original'/n) for n in h.CHECKPOINT_FILES}
        report['status']='READ_ONLY_PARENT_AND_FULL_NATIVE_EXACT_ACTUAL_NUMERICAL_ROLLBACK_OBSERVED'
    except Exception:
        report['status']='FAILED';report['error']=traceback.format_exc()
    persist();print(json.dumps({k:report[k] for k in ['status','seconds','rollback_count'] if k in report}));return 0 if report['status'].startswith('READ_ONLY_') else 2


if __name__=='__main__':raise SystemExit(main())
