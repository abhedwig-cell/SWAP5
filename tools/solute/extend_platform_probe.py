"""Reuse one exact private donor for full-period and own-native continuation.

No recompilation, reference replacement, SWAP5-kernel qualification or old-state
rebinding. This determines whether a tested compiler profile merits promotion.
"""
import argparse,json,math,os,re,shutil,subprocess,sys,threading,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'app/hybrid_water'))
import daily_host as h
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--artifact',type=Path,required=True)
p.add_argument('--output',type=Path,required=True)
p.add_argument('--days',type=int,default=1096)
p.add_argument('--cut',type=int,default=365)
a=p.parse_args();a.output=a.output.resolve();a.output.mkdir()
source=a.artifact.resolve();exe=source/'probe/same-core/diagnostic.exe'
if os.name!='nt':exe.chmod(0o755)
meta=json.loads((source/'bundle/BUILD.json').read_text())
assert meta['project']['model']==h.HUPSEL.model
case=a.output/'inputs';case.mkdir()
for name in meta['inputs']:
    (case/name).parent.mkdir(exist_ok=True,parents=True)
    shutil.copyfile(source/'probe/same-core/case'/name,case/name)
origin=a.output/'origin';origin.mkdir();summaries={}
def run(mode,first):
    directory=a.output/mode
    if first:
        # Reuse the original restart preparation, avoiding a duplicate generated
        # output-format line in an already prepared private input directory.
        control=case/'swap.swp';data=control.read_text(encoding='cp1252')
        control.write_text(re.sub(r'(?m)^NUM_DECIMALS = 12\r?\n?','',data),encoding='cp1252')
        try:h.prepare_column(case,directory,h.ColumnStart(day=first,origin=origin),True,True,h.HUPSEL)
        finally:control.write_text(data,encoding='cp1252')
    else:shutil.copytree(case,directory)
    began=time.perf_counter();maximum_water=maximum_solute=0.;completed=first
    with (directory/'stderr').open('w') as err,(a.output/(mode+'-stdout')).open('w',encoding='utf-8') as log:
        process=subprocess.Popen([str(exe),'./swap.swp'],cwd=directory,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=err,text=True,encoding='cp1252')
        timer=threading.Timer(60,process.kill);timer.start()
        try:
            _,ready=h.receive(process,log,{'HYBRID_READY'})
            assert float(ready['HYBRID_READY'][0])==h.HUPSEL.start_clock+first
            stocks=list(map(float,ready['HYBRID_STOCK_FLUX'][:6]));solute=float(ready['HYBRID_SOLUTE_READY'][0])
            for day in range(first+1,a.days+1):
                checkpoint=day in (a.cut,a.days)
                h.send(process,f'{day} {h.HUPSEL.start_clock+day if checkpoint else -1}')
                _,r=h.receive(process,log,{'HYBRID_DAY_RETURN'})
                s=list(map(float,r['HYBRID_STOCK_FLUX']));q=list(map(float,r['HYBRID_EXTERNAL_FLUX']));v=list(map(float,r['HYBRID_SOLUTE_LEDGER']))
                assert s[6:]==stocks,(mode,day,'foreign water origin')
                residual=math.fsum([*q[:7],*(-x for x in q[7:]),*s[6:],*(-x for x in s[:6])])
                end,delta,rain,irrig,bottom,drain,decay,root,reported=v
                sr=math.fsum([end,-solute,-rain,-irrig,-bottom,drain,decay,root])
                maximum_water=max(maximum_water,abs(residual));maximum_solute=max(maximum_solute,abs(sr),abs(reported))
                if abs(residual)>1e-10 or abs(sr)>1e-10 or abs(reported)>1e-10:
                    raise ValueError(f'{mode} day{day} unchanged guard failed: water={residual!r} solute={sr!r}')
                completed=day;stocks=s[:6];solute=end
                if day==a.cut and not first:
                    for name in h.CHECKPOINT_FILES:shutil.copyfile(directory/name,origin/name)
            h.send(process,'0 -1')
            for line in process.stdout:log.write(line)
            assert process.wait(timeout=10)==100
        finally:
            timer.cancel()
            if process.poll() is None:process.kill()
            process.wait(timeout=5)
            summaries[mode]=dict(completed_day=completed,model_wall_seconds=time.perf_counter()-began,maximum_water_cm=maximum_water,maximum_solute_mg_cm2=maximum_solute)
            (a.output/'PROGRESS.json').write_text(json.dumps(summaries,indent=2)+'\n')
    frames={}
    for line in (a.output/(mode+'-stdout')).read_text().splitlines():
        if line.startswith(('RC1_HEAD ','RC1_HEAT ','RC1_HIST ','HYBRID_STOCK_FLUX ','HYBRID_EXTERNAL_FLUX ','HYBRID_SOLUTE_LEDGER ','HYBRID_UPTAKE ')):
            tag,*values=line.split();frames.setdefault(tag,[]).append(list(map(float,values)))
    assert all(len(rows)==a.days-first+1 for rows in frames.values())
    (a.output/(mode+'-frames.json')).write_text(json.dumps(frames)+'\n')
    return frames,directory
full,full_dir=run('full',0);origin_hashes={n:h.sha(origin/n) for n in h.CHECKPOINT_FILES}
resumed,resume_dir=run('resumed',a.cut)
for name in h.CHECKPOINT_FILES:
    assert h.sha(origin/name)==origin_hashes[name]
    assert (full_dir/name).read_bytes()==(resume_dir/name).read_bytes(),name
for key,rows in resumed.items():
    expected=full[key][a.cut+1:]
    actual=rows[1:]
    if key=='RC1_HIST':actual=[[v-u for u,v in zip(rows[0],row)] for row in actual];expected=[[v-u for u,v in zip(full[key][a.cut],row)] for row in expected]
    assert actual==expected,key
result=dict(status='PRIVATE_FULL_AND_OWN_NATIVE_PASS_NOT_PRODUCTION_QUALIFICATION',source_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),donor_sha256=h.sha(exe),days=a.days,cut=a.cut,origin_unchanged=True,exact_native_auxiliary=True,exact_physical_suffix=True,profiles=summaries,oxygen584_cm=full['HYBRID_UPTAKE'][584][3] if a.days>=584 else None)
(a.output/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result),flush=True)
