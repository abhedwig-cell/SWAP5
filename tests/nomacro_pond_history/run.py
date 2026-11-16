"""Qualify the original complete scheduled-pond history owner through real APIs."""
import argparse, contextlib, hashlib, importlib.util, json, shutil, struct, subprocess, sys, time, zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tools/solute'),str(ROOT/'app/hybrid_water')]
spec=importlib.util.spec_from_file_location('original_mixtures',ROOT/'tests/nomacro_mixtures/run.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
from daily_coupling import CoupledDailyColumn,validate_bundle
import user_prepare


def controls(build,reference,project,out,full,data,*,policy_key="scheduled_pond_history"):
    meta,case=validate_bundle(build,reference,project)
    # Foreign format policy must fail before any output/private worker exists.
    foreign=out/'foreign-policy';foreign.mkdir();changed=json.loads((build/'BUILD.json').read_text())
    changed['identity'][policy_key]['policy']='foreign';(foreign/'BUILD.json').write_text(json.dumps(changed))
    try:validate_bundle(foreign,reference,project)
    except ValueError as error:assert ('Foreign original scheduled pond history' if policy_key=='scheduled_pond_history' else 'Foreign bounded original frost reference policy') in str(error)
    else:raise AssertionError('Foreign pond policy accepted')
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
    # Rehash the archive intentionally: test the real native domain, beyond ZIP hashes.
    with zipfile.ZipFile(full/'accepted-column-1-day-199.zip') as z:members={n:z.read(n) for n in z.namelist()}
    aux=members['macro.bin'];lookup=struct.unpack_from('=i',aux,len(aux)-4)[0]
    scheduled=bool(meta['identity'].get('scheduled_pond_history'));top_bytes=80 if scheduled else 72;top=len(aux)-lookup-top_bytes
    assert struct.unpack_from('=i',aux,top)[0]==(2 if scheduled else 1) and struct.unpack_from('=i',aux,top+top_bytes-4)[0]==top_bytes
    scalar_offset=top+(60 if scheduled else 28)
    attacks=[]
    for name,offset,fmt,value in [('old-format',0,'8s',(b'S5WML024' if not project.solute else b'S5CML027') if scheduled else b'S5WAT007'),('pond-nan' if scheduled else 'top-nan',scalar_offset,'d',float('nan')),('pond-negative' if scheduled else 'top-negative',scalar_offset,'d',-1.),('foreign-clock',top+4,'d',0.)]:
        altered=dict(members);raw=bytearray(aux);struct.pack_into('='+fmt,raw,offset,value);altered['macro.bin']=bytes(raw)
        manifest=json.loads(altered['checkpoint.json']);manifest['files']['macro.bin']=hashlib.sha256(raw).hexdigest();altered['checkpoint.json']=json.dumps(manifest).encode()
        package=out/(name+'.zip')
        with zipfile.ZipFile(package,'w') as z:
            for n,b in altered.items():z.writestr(n,b)
        target=out/(name+'-refused');command=[sys.executable,'-B',str(ROOT/'tools/solute/run_water.py'),'--model',m.e.MODEL,'--experimental-project',str(project.input_directory),'--reference-work',str(reference),'--build-bundle',str(build),'--restart',str(package),'--restart-day','199','--days','200','--output',str(target)]
        command.extend(['--experimental-time-step-policy',project.time_step_policy])
        r=subprocess.run(command,capture_output=True,text=True,timeout=30);(out/(name+'.stderr')).write_text(r.stderr)
        assert r.returncode!=0 and not list(target.glob('accepted-*.zip')),(name,r.stdout,r.stderr)
        diagnostic=''.join(p.read_text(errors='replace') for p in target.rglob('donor.stderr'))
        assert ('Foreign nonmacro checkpoint' in diagnostic if name=='old-format' else 'top history' in diagnostic.lower()),(name,diagnostic)
        attacks.append(dict(name=name,returncode=r.returncode,accepted_days=0,diagnostic=diagnostic))
    return dict(foreign_policy_refused=True,independent_origins=True,inconsistent_mass_refused=True,external_discard_replay_exact=True,external_disk_recovery=True,native_refusals=attacks)


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--configuration',choices=['water-surface-history','chemical-surface-history'],required=True);p.add_argument('--reference-work',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--compare-sealed-windows',action='store_true');a=p.parse_args()
    out=a.output.resolve();out.mkdir(parents=True,exist_ok=False);reference=a.reference_work.resolve()
    if not (reference/'PREPARED.json').exists():user_prepare.prepare(reference)
    user_prepare.validate(reference);inventory=m.fixtures(out);key=a.configuration;project=m.e.load(out/key);reports={};events=[]
    result=dict(status='RUNNING',source_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),configuration=key,inputs=inventory[key],profiles=reports,events=events,science='NOT_QUALIFIED',water_guard_cm=1e-10,solute_guard_mg_cm2=1e-10)
    def save():(out/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n')
    save()
    for opt in ('O0','O2'):
        build=out/(opt+'-build');cmd=[sys.executable,'-B',str(ROOT/'tools/solute/run_water.py'),'--model',m.e.MODEL,'--experimental-project',str(out/key),'--reference-work',str(reference),'--build-only','--kernel-opt',opt,'--donor-opt',opt,'--output',str(build)]
        start=time.perf_counter();r=subprocess.run(cmd,capture_output=True,text=True,timeout=180);events.append(dict(command=cmd,seconds=time.perf_counter()-start,returncode=r.returncode,stdout=r.stdout,stderr=r.stderr));save();assert r.returncode==0,r.stderr
        short=out/(opt+'-short');brief,rows=m.trajectory(build,reference,project,short,5,{2,4},30);brief['own']=m.own(build,reference,project,short,rows,2,4,out/(opt+'-short-own'))
        full=out/(opt+'-full');r,rows=m.trajectory(build,reference,project,full,1096,{2,4,199,201,365,367,530,532,1096},60)
        r['short']=brief;reports[opt]=r;save()
        r['own']=[m.own(build,reference,project,full,rows,start,end,out/(opt+f'-own{start}')) for start,end in ((2,4),(199,201),(365,367),(530,532))]
        if a.compare_sealed_windows:
            with zipfile.ZipFile(ROOT/'integration/nomacro-mixtures01/RAW_SURFACE.zip') as z:old=[json.loads(s) for s in z.read(key+'-'+opt+'-full/daily.jsonl').decode().splitlines()]
            assert m.physical(rows)==m.physical(old);r['all_1096_physical_rows_exact_to_failed_source']=True
        controlout=out/(opt+'-controls');controlout.mkdir();r['controls']=controls(build,reference,project,controlout,full,rows)
        print(key,opt,'FULL_NATIVE_BALANCE_AND_TRANSACTION_PASS',flush=True);save()
    result['status']='COMPLETE_SCHEDULED_POND_HISTORY_O0_O2_PASS';save()


if __name__=='__main__':main()
