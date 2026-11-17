"""Actual generic drainage isolation, transaction and native refusal controls."""
import contextlib,hashlib,json,struct,subprocess,sys,zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tools/solute'),str(ROOT/'app/hybrid_water')]
from daily_coupling import CoupledDailyColumn,validate_bundle


def controls(m,build,reference,project,out,full,data):
    meta,case=validate_bundle(build,reference,project)
    foreign=out/'foreign-policy';foreign.mkdir();changed=json.loads((build/'BUILD.json').read_text());changed['identity']['time_step_policy']='foreign';(foreign/'BUILD.json').write_text(json.dumps(changed))
    try:validate_bundle(foreign,reference,project)
    except ValueError as error:assert 'Bundle time-step policy differs' in str(error)
    else:raise AssertionError('Foreign drainage execution policy accepted')
    isolated=out/'isolated';isolated.mkdir();origin=out/'isolation-origin'
    receipt=m.h.verify_checkpoint(full/'accepted-column-1-day-2.zip',2,meta['binding'],origin)
    with contextlib.ExitStack() as stack:
        host=m.h.DailyHost(stack,m.h.executable(build,'day_donor'),m.h.executable(build,'day_kernel'),case,isolated,
                           [m.h.ColumnStart(name='fresh'),m.h.ColumnStart(day=2,origin=origin,receipt=receipt,name='restored')],runtime=True,checkpoint_enabled=True,project=project)
        for offset in range(3):
            for column,index in [(2,offset+2),(1,offset)]: assert m.physical([host.step(column)])==m.physical([data[index]])
        host.close()
    failed=out/'mass-refused';failed.mkdir()
    with contextlib.ExitStack() as stack:
        host=m.h.DailyHost(stack,m.h.executable(build,'day_donor'),m.h.executable(build,'day_kernel'),case,failed,[m.h.ColumnStart()],runtime=True,checkpoint_enabled=True,project=project)
        stocks=host.columns[0].stocks.copy();send=m.h.send
        def inconsistent(process,line):
            v=line.split()
            if process is host.host and len(v)==project.nodes+12:v[2]=str(float(v[2])+1);line=' '.join(v)
            return send(process,line)
        try:m.h.send=inconsistent;rejected=host.step(1)
        finally:m.h.send=send
        assert not rejected['committed'] and rejected['revision']==0 and host.columns[0].stocks==stocks and host.columns[0].day==0 and not list(failed.glob('accepted-*.zip'))
        host.close()
    external=CoupledDailyColumn(build,reference,out/'external',project,'pond-history')
    first=external.prepare();external.discard(first);assert external.day==external.revision==0 and external.checkpoint is None
    replay=external.prepare();assert replay.budget==first.budget;external.accept(replay)
    accepted=external.checkpoint;digest=m.sha(accepted);second=external.prepare();external.discard(second);assert external.day==1 and m.sha(accepted)==digest
    repeat=external.prepare();assert repeat.budget==second.budget;external.accept(repeat)
    recovered=CoupledDailyColumn(build,reference,out/'recovered',project,'pond-history',origin=external.checkpoint,day=2)
    third=recovered.prepare();assert m.physical([{k:v for k,v in third.budget.items() if k!='candidate_only'}|{'committed':True}])==m.physical([data[2]]);recovered.discard(third)
    with zipfile.ZipFile(full/'accepted-column-1-day-199.zip') as z:members={n:z.read(n) for n in z.namelist()}
    attacks=[]
    for name,offset,fmt,value in [('foreign-format',0,'8s',b'S5BAD000'),('foreign-nodes',8,'i',1),('foreign-clock',12,'d',0.),('nonfinite-season',36,'d',float('nan'))]:
        altered=dict(members);raw=bytearray(altered['macro.bin']);struct.pack_into('='+fmt,raw,offset,value);altered['macro.bin']=bytes(raw);manifest=json.loads(altered['checkpoint.json']);manifest['files']['macro.bin']=hashlib.sha256(raw).hexdigest();altered['checkpoint.json']=json.dumps(manifest).encode();package=out/(name+'.zip')
        with zipfile.ZipFile(package,'w') as z:
            for n,b in altered.items():z.writestr(n,b)
        target=out/(name+'-refused');cmd=[sys.executable,'-B',str(ROOT/'tools/solute/run_water.py'),'--model',m.e.MODEL,'--experimental-project',str(project.input_directory),'--reference-work',str(reference),'--build-bundle',str(build),'--restart',str(package),'--restart-day','199','--days','200','--output',str(target)]
        r=subprocess.run(cmd,capture_output=True,text=True,timeout=30);(out/(name+'.stderr')).write_text(r.stderr);diagnostic=''.join(p.read_text(errors='replace') for p in target.rglob('donor.stderr'));assert r.returncode!=0 and not list(target.glob('accepted-*.zip')) and ('Nonfinite nonmacro seasonal clock' in diagnostic if name=='nonfinite-season' else 'Foreign nonmacro checkpoint' in diagnostic),(name,r.stderr,diagnostic)
        attacks.append(dict(name=name,returncode=r.returncode,accepted_days=0,diagnostic=diagnostic))
    return dict(foreign_policy_refused=True,independent_origins=True,inconsistent_mass_refused=True,external_discard_replay_exact=True,external_disk_recovery=True,native_refusals=attacks)
