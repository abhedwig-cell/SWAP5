"""Bounded real original-project waterhost, restart, isolation and refusal proof.

Donor physics remains O2; O0/O2 refers to the actual SWAP5 transaction kernel.
No full trajectory or native thermal-profile qualification is performed.
"""
import argparse
import contextlib
import copy
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import threading
import time
import zipfile

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'app/hybrid_water'))
import daily_host as host
from check_hybrid_budget_protocol import check as check_protocol

p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--reference',type=Path,required=True)
p.add_argument('--output',type=Path,required=True)
p.add_argument('--project',choices=['grass','andelst','hupsel'],required=True)
p.add_argument('--optimization',choices=['O0','O2'],required=True)
p.add_argument('--reuse-build',type=Path)
p.add_argument('--reuse-control',type=Path)
p.add_argument('--reuse-resume',type=Path)
p.add_argument('--reuse-terminal',type=Path)
p.add_argument('--andelst-baseline',type=Path,help='Same-platform old donor cut/terminal/resumed controls')
a=p.parse_args()
if a.project=='andelst' and a.andelst_baseline is None:p.error('Andelst requires actual same-platform canonical controls')
a.output=a.output.resolve();a.output.mkdir()
a.reference=a.reference.resolve()
project={'grass':host.GRASSGROWTH,'andelst':host.ANDELST,'hupsel':host.HUPSEL}[a.project]
events=[]
original_run=subprocess.run

def execute(command,*args,**kwargs):
    start=time.monotonic()
    try:
        result=original_run(command,*args,**kwargs)
        events.append({'command':list(map(str,command)),'cwd':str(kwargs.get('cwd','')),
                       'seconds':time.monotonic()-start,'returncode':result.returncode})
        return result
    except Exception as error:
        events.append({'command':list(map(str,command)),'seconds':time.monotonic()-start,'error':repr(error)})
        raise
    finally:
        (a.output/'EVENTS.json').write_text(json.dumps(events,indent=2)+'\n')
subprocess.run=execute
profile=dict(budget_retry=a.project!='grass',shared_pond_transfer=a.project=='andelst',
             refresh_macro_final=a.project=='andelst')
if a.reuse_build:
    old=json.loads((a.reuse_build/'BUILD.json').read_text());identity=old['identity'];inputs=old['inputs']
    assert old['binding']['case']==project.case
    assert identity['host']==host.sha(Path(host.__file__))
    assert identity['adapter']==host.sha(ROOT/'app/hybrid_water/donor_adapter.f90')
    assert identity['driver']==host.sha(ROOT/'app/hybrid_water/main.f90')
    assert identity['kernel_flags'][0]=='-'+a.optimization
    for name,digest in identity['kernel_sources']:assert host.sha(ROOT/name)==digest
    for name,digest in identity['donor_generated'].items():assert host.sha(a.reuse_build/name)==digest
    for name,digest in identity['donor_objects'].items():assert host.sha(a.reference/'build/swap-obj'/name)==digest
    assert host.sha(a.reference/'build/ttutil-obj/libttutil.a')==identity['ttutil_library']
    donor=host.executable(a.reuse_build,'day_donor');kernel=host.executable(a.reuse_build,'day_kernel')
    case=a.reference/'distribution/SWAP_4.3.1/cases'/project.case
    assert all(host.sha(case/name)==digest for name,digest in inputs.items())
else:
    donor,kernel,case,inputs,identity=host.build(a.reference,a.output,runtime_checkpoint=True,
                                              kernel_opt=a.optimization,project=project,**profile)
binding=host.checkpoint_identity(inputs,identity,project=project,**profile)
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
metadata=dict(project=project.__dict__,inputs=inputs,identity=identity,binding=binding,
              executable_sha256={'donor':sha(donor),'kernel':sha(kernel)})
(a.output/'BUILD.json').write_text(json.dumps(metadata,indent=2)+'\n')
print(check_protocol(kernel),flush=True)

# Compile the actual state owner and its complete current kernel closure cold.
unit=a.output/'state-contract';unit.mkdir()
sources=[ROOT/name for name,digest in identity['kernel_sources']]
assert all(sha(path)==digest for path,(_,digest) in zip(sources,identity['kernel_sources']))
state_exe=host.executable(unit,'state-contract')
old_state=a.reuse_build/'state-contract'/state_exe.name if a.reuse_build else None
if old_state and old_state.exists():
    old_events=json.loads((a.reuse_build/'EVENTS.json').read_text())
    assert any(e.get('command')==[str(old_state)] and e.get('returncode')==0 for e in old_events)
    events.append({'state_contract':'INHERITED_UNCHANGED_OWNER_AND_DRIVER',
                   'executable_sha256':sha(old_state),'prior_events_sha256':sha(a.reuse_build/'EVENTS.json')})
else:
    execute(['gfortran',*identity['kernel_flags'],*map(str,sources),str(ROOT/'app/hybrid_water/donor_adapter.f90'),
             str(Path(__file__).with_name('test_generic_hybrid_state.f90')),'-o',str(state_exe)],cwd=unit,check=True)
    execute([str(state_exe)],cwd=unit,check=True,timeout=10)

started=[]
real_start=host.start_process
def tracked(*args):
    process,log=real_start(*args);started.append(process);return process,log
host.start_process=tracked

@contextlib.contextmanager
def bounded(label):
    expired=[]
    def stop():
        expired.append(True)
        for process in started:
            if process.poll() is None:process.kill()
    timer=threading.Timer(60,stop);timer.daemon=True;timer.start();start=time.monotonic()
    try:
        yield
        assert not expired,'Native case exceeded selected cap'
        events.append({'case':label,'seconds':time.monotonic()-start,'status':'PASS'})
    except Exception as error:
        events.append({'case':label,'seconds':time.monotonic()-start,'status':'FAILED','error':repr(error),
                       'censored':bool(expired)})
        raise
    finally:
        timer.cancel();(a.output/'EVENTS.json').write_text(json.dumps(events,indent=2)+'\n')

def run_case(name,end=4,**kwargs):
    out=a.output/name;out.mkdir()
    with bounded(name):
        result=host.run(donor,kernel,case,out,end,runtime=True,project=project,**kwargs)
        assert result['first_refusal'] is None,result
    return out,result

def rows(out):return [json.loads(line) for line in (out/'daily.jsonl').read_text().splitlines()]
def physical(row):return {k:v for k,v in row.items() if k not in ('revision','column')}
def csv_rows(out):return host.records((out/'original/result_output.csv').read_text().splitlines())

if a.reuse_control:
    continuous=a.reuse_control.resolve()
    if (continuous/'RESULT.json').exists():result=json.loads((continuous/'RESULT.json').read_text())
    else:
        prior=json.loads((continuous.parent/'EVENTS.json').read_text())
        assert any(e.get('case')=='continuous' and e.get('status')=='PASS' for e in prior)
        accepted=rows(continuous)
        assert [r['day'] for r in accepted]==[1,2,3,4] and all(r['committed'] for r in accepted)
        result={'committed_days':len(accepted),'first_refusal':None}
else:continuous,result=run_case('continuous',publish_day=2,checkpoint_binding=binding)
assert result['committed_days']==4
raw=rows(continuous)
assert all(len(r['pressure_head_cm'])==project.nodes and abs(r['independent_residual_cm'])<=project.water_tolerance for r in raw)
if a.reuse_terminal:control=a.reuse_terminal.resolve()
else:control,_=run_case('terminal-control',publish_day=4,checkpoint_binding=binding)
assert rows(control)==raw and csv_rows(control)==csv_rows(continuous)
origin=a.output/'verified-origin'
receipt=host.verify_checkpoint(continuous/'accepted-column-1-day-2.zip',2,binding,origin)
if a.reuse_resume:resumed=a.reuse_resume.resolve()
else:resumed,_=run_case('resumed',checkpoint_day=2,origin=origin,origin_receipt=receipt,
                      publish_day=4,checkpoint_binding=binding)
assert list(map(physical,rows(resumed)))==list(map(physical,raw[2:]))
assert csv_rows(resumed)[-2:]==csv_rows(continuous)[-2:]
for name in host.CHECKPOINT_FILES:
    if a.project!='andelst' or name=='result.end':
        assert (control/'original'/name).read_bytes()==(resumed/'original'/name).read_bytes(),name
    if a.project=='andelst':
        assert (control/'original'/name).read_bytes()==(a.andelst_baseline/'terminal/original'/name).read_bytes()
        assert (resumed/'original'/name).read_bytes()==(a.andelst_baseline/'resumed/original'/name).read_bytes()

if a.project=='hupsel':
    gift,_=run_case('gift-seven',end=7,publish_day=5,checkpoint_binding=binding)
    gift_terminal,_=run_case('gift-terminal',end=7,publish_day=7,checkpoint_binding=binding)
    gift_origin=a.output/'gift-origin'
    gift_receipt=host.verify_checkpoint(gift/'accepted-column-1-day-5.zip',5,binding,gift_origin)
    gift_own,_=run_case('gift-own',end=7,checkpoint_day=5,origin=gift_origin,
                        origin_receipt=gift_receipt,publish_day=7,checkpoint_binding=binding)
    assert list(map(physical,rows(gift_own)))==list(map(physical,rows(gift)[5:]))
    assert max(abs(r['solute_independent_residual_mg_cm2']) for r in rows(gift))<=1e-10
    for name in host.CHECKPOINT_FILES:
        assert (gift_terminal/'original'/name).read_bytes()==(gift_own/'original'/name).read_bytes()

# Distinct physical boundary histories interleave exactly against their controls.
repeated=a.output/'repeated-publication';repeated.mkdir()
with bounded('repeated-publication'),contextlib.ExitStack() as stack:
    current=host.DailyHost(stack,donor,kernel,case,repeated,[host.ColumnStart()],
                          checkpoint_enabled=True,runtime=True,binding=binding,project=project)
    staged=[]
    for day in range(1,5):
        staged.append(current.step(1,checkpoint=day in (2,4)))
        if day==2:
            old_package=repeated/'accepted-column-1-day-2.zip';old_bytes=old_package.read_bytes()
            # A foreign working file may not be silently deleted or advanced.
            stage=current.columns[0].directory/'macro.bin';saved=stage.read_bytes()
            stage.write_bytes(saved+b'foreign')
            try:current.step(1,checkpoint=True)
            except ValueError:pass
            else:raise AssertionError('Unowned staging removed')
            assert current.columns[0].day==2 and stage.read_bytes()==saved+b'foreign'
            stage.write_bytes(saved)
            # An occupied next target also refuses before advancing/deleting.
            occupied=repeated/'accepted-column-1-day-3.zip';occupied.write_bytes(b'occupied')
            try:current.step(1,checkpoint=True)
            except FileExistsError:pass
            else:raise AssertionError('Occupied target overwritten')
            assert occupied.read_bytes()==b'occupied' and current.columns[0].day==2
            assert stage.read_bytes()==saved
            occupied.unlink()
    current.close()
assert staged==raw and old_package.read_bytes()==old_bytes
with zipfile.ZipFile(repeated/'accepted-column-1-day-4.zip') as package:
    for name in host.CHECKPOINT_FILES:
        assert package.read(name)==(control/'original'/name).read_bytes()

# Refusal after an earlier publication leaves its accepted package intact.
refused_pub=a.output/'refused-publication';refused_pub.mkdir()
with bounded('refused-publication'),contextlib.ExitStack() as stack:
    current=host.DailyHost(stack,donor,kernel,case,refused_pub,
                          [host.ColumnStart(name='one'),host.ColumnStart(name='two')],
                          checkpoint_enabled=True,runtime=True,binding=binding,project=project)
    for day in (1,2):
        assert current.step(1,checkpoint=day==2)['committed']
        assert current.step(2)['committed']
    saved_package=(refused_pub/'accepted-column-1-day-2.zip').read_bytes()
    real_send=host.send
    def corrupt_published(process,text):
        values=text.split()
        if process is current.host and len(values)==12+project.nodes:
            values[2]=str(float(values[2])+0.01);text=' '.join(values)
        real_send(process,text)
    host.send=corrupt_published
    try:assert not current.step(1,checkpoint=True)['committed']
    finally:host.send=real_send
    assert current.columns[0].day==2 and current.columns[0].revision==2
    assert (refused_pub/'accepted-column-1-day-2.zip').read_bytes()==saved_package
    assert not (refused_pub/'accepted-column-1-day-3.zip').exists()
    assert physical(current.step(2))==physical(raw[2])
    current.close()

mixed,_=run_case('mixed',end=2,variants=('original','shifted'))
plain,_=run_case('plain',end=2)
shifted,_=run_case('shifted',end=2,variants=('shifted',))
for column,expected in [(1,rows(plain)),(2,rows(shifted))]:
    assert [physical(r) for r in rows(mixed) if r['column']==column]==list(map(physical,expected))
assert list(map(physical,rows(plain)))!=list(map(physical,rows(shifted)))

# A corrupt mass receipt must refuse one candidate without advancing another.
fault=a.output/'refusal';fault.mkdir()
with bounded('refusal'),contextlib.ExitStack() as stack:
    current=host.DailyHost(stack,donor,kernel,case,fault,[host.ColumnStart(name='one'),host.ColumnStart(name='two')],
                           runtime=True,project=project)
    real_send=host.send
    def corrupt(process,text):
        values=text.split()
        if process is current.host and len(values)==12+project.nodes:
            values[2]=str(float(values[2])+0.01);text=' '.join(values)
        real_send(process,text)
    before=copy.deepcopy((current.columns[0].stocks,current.columns[0].pressure,current.columns[0].day))
    host.send=corrupt
    try:refused=current.step(1)
    finally:host.send=real_send
    assert not refused['committed'] and refused['revision']==0
    assert before==(current.columns[0].stocks,current.columns[0].pressure,current.columns[0].day)
    assert physical(current.step(2))==physical(rows(plain)[0])
    try:current.step(1)
    except ValueError:pass
    else:raise AssertionError('Refused column accepted another request')
    current.close()
assert not list(fault.glob('accepted-*.zip'))

# Registry/framing/grid/clock rejection, without any physical model execution.
for name,arguments,data in [
 ('foreign-model',['UNKNOWN'],'2\n'),
 ('foreign-protocol',[project.model,'wrong'],'2\n'),
 ('zero-grid',[project.model,'explicit-project'],'1\n0 29220\n'),
 ('nonfinite-clock',[project.model,'explicit-project'],'1\n113 NaN\n')]:
    test=execute([str(kernel),*arguments],input=data,text=True,capture_output=True,timeout=10)
    assert test.returncode!=0 and 'DAILY_ACCEPTED' not in test.stdout,name
    (a.output/(name+'.log')).write_text(test.stdout+test.stderr)

# Foreign outer binding refuses before creating the extraction directory.
try:host.verify_checkpoint(continuous/'accepted-column-1-day-2.zip',2,{**binding,'case':'foreign'},a.output/'foreign-origin')
except ValueError:pass
else:raise AssertionError('Foreign binding accepted')
assert not (a.output/'foreign-origin').exists()
if a.project!='andelst':
    for label,offset in [('mode',0),('grid',8),('clock',12)]:
        bad=a.output/('bad-'+label);bad.mkdir()
        for name in host.CHECKPOINT_FILES:(bad/name).write_bytes((origin/name).read_bytes())
        payload=bytearray((bad/'macro.bin').read_bytes());payload[offset]^=1;(bad/'macro.bin').write_bytes(payload)
        out=a.output/('refused-'+label);out.mkdir()
        with bounded('bad-'+label):
            try:host.run(donor,kernel,case,out,3,checkpoint_day=2,origin=bad,origin_receipt=receipt,
                         runtime=True,project=project)
            except RuntimeError:pass
            else:raise AssertionError('Foreign inner auxiliary state accepted')
        assert not list(out.glob('accepted-*.zip'))

# Nonfinite or unbalanced solute frames fail before a kernel candidate commits.
if a.project=='hupsel':
    for label in ['solute-mass','solute-nonfinite','uptake-shape']:
        out=a.output/label;out.mkdir()
        with bounded(label),contextlib.ExitStack() as stack:
            current=host.DailyHost(stack,donor,kernel,case,out,[host.ColumnStart()],runtime=True,project=project)
            initial_stock=current.columns[0].solute_stock
            original_receive=host.receive
            def corrupt_solute(process,transcript,prefixes):
                key,response=original_receive(process,transcript,prefixes)
                if 'HYBRID_SOLUTE_LEDGER' in response:
                    if label=='solute-mass':response['HYBRID_SOLUTE_LEDGER'][0]='0.01'
                    elif label=='solute-nonfinite':response['HYBRID_SOLUTE_LEDGER'][0]='NaN'
                    else:response['HYBRID_UPTAKE'].pop()
                return key,response
            host.receive=corrupt_solute
            try:
                try:current.step(1)
                except ValueError:pass
                else:raise AssertionError('Invalid solute/uptake frame accepted')
            finally:host.receive=original_receive
            assert current.columns[0].day==current.columns[0].revision==0
            assert current.columns[0].solute_stock==initial_stock
        assert 'DAILY_ACCEPTED' not in (out/'kernel.stdout').read_text()
        assert not list(out.glob('accepted-*.zip'))

baseline='NOT_APPLICABLE'
if a.project=='andelst':
    assert raw==rows(a.andelst_baseline/'cut'),'Changed same-platform canonical Andelst prefix'
    baseline='EXACT_ADMITTED_ANDELST_FOUR_DAY_RECEIPTS'
report=dict(status='GENERIC_HYBRID_ORIGINAL_PREFIX_RESTART_ISOLATION_REFUSAL_PASS',project=a.project,
            kernel_optimization=a.optimization,donor_optimization='O2',days=4,baseline=baseline,
            maximum_water_residual_cm=max(abs(r['independent_residual_cm']) for r in raw),
            exact_native_restart_payloads=list(host.CHECKPOINT_FILES) if a.project!='andelst' else ['result.end'],
            auxiliary_state_scope='Both payloads exact own restart' if a.project!='andelst' else
                'Complete cold and resumed macro payloads exactly preserve canonical same-platform controls; existing cold/resumed byte difference is not newly qualified',
            distinct_instance_control=True,refusal_isolation=True,source_sha256={str(ROOT/'app/hybrid_water'/n):sha(ROOT/'app/hybrid_water'/n)
                for n in ['daily_host.py','donor_sources.py','donor_adapter.f90','main.f90']},
            build_sha256=sha(a.output/'BUILD.json'),events_sha256=sha(a.output/'EVENTS.json'),
            scope='Bounded original water route only; not native1e-5C heat, full project or whole science.')
(a.output/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report))
