"""Execute and resume independent SWAP431 columns, auditing requested daily output."""
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor,as_completed
from collections import Counter
import argparse,csv,datetime as dt,hashlib,json,math,subprocess,time
import numpy as np

SCALARS='RAIN RUNOFF IRRIG DRN BOT EPOT EACT TPOT TACT EPD EIC DSTOR BALDEV GASST GWL'.split()
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def audit(case,manifest):
    with (case/'result_output.csv').open() as f:r=list(csv.DictReader(l for l in f if not l.startswith('*')))
    assert len(r)==1006,(case.name,len(r))
    assert all(x['DATE']==(dt.date(2023,12,31)+dt.timedelta(days=i)).isoformat() for i,x in enumerate(r))
    assert set(SCALARS+['WTOT','PD_VOL','IC_VOL'])<=r[0].keys()
    wc=[k for k in r[0] if k.startswith('WC[')];temp=[k for k in r[0] if k.startswith('T[')]
    assert len(wc)==len(temp)==5
    keys=list(r[0]);numbers=keys[1:];a=np.array([[float(x[k]) for k in numbers] for x in r],dtype='f8')
    assert np.isfinite(a).all()
    col={k:a[1:,numbers.index(k)] for k in numbers}
    for k in wc:assert np.all((col[k]>=0)&(col[k]<=1)),(case.name,k)
    for k in temp:assert np.all((col[k]>-60)&(col[k]<70)),(case.name,k)
    flux=col['RAIN']+col['IRRIG']+col['BOT']-sum(col[k] for k in ('RUNOFF','EACT','EPD','TACT','EIC','DRN'))
    residual=flux-col['DSTOR']-col['BALDEV'];assert np.max(np.abs(residual))<1e-6,(case.name,'native ledger',float(np.max(np.abs(residual))))
    assert abs(float(col['RAIN'].sum())-221.66)<1e-5
    storage=sum(a[:,numbers.index(k)] for k in ('WTOT','PD_VOL','IC_VOL'))
    jumps=flux-np.diff(storage)-col['BALDEV'];flags=[]
    for i in np.flatnonzero(np.abs(jumps)>1e-6):
        annual=r[i+1]['DATE'].endswith('01-01')
        harvest=manifest['crop_model']=='maize' and r[i+1]['DATE'].endswith('10-16')
        assert (annual or harvest) and i>0,(case.name,'state ledger',r[i+1]['DATE'],float(jumps[i]))
        paired=abs(jumps[i]+jumps[i-1])<2e-6
        canopy_reset=abs(jumps[i]-a[i,numbers.index('IC_VOL')])<1e-6
        assert paired or canopy_reset,(case.name,'unexplained annual ledger',float(jumps[i]))
        flags.append({'date':r[i+1]['DATE'],'transition':'annual' if annual else 'harvest','residual_cm':float(jumps[i]),'previous_day_residual_cm':float(jumps[i-1]),'interpretation':'two-day output accounting jump' if paired else 'crop-calendar canopy reset equals previous printed canopy storage; native DSTOR differs from difference of consecutive printed total stores; not a clean daily physical closure'})
    gas=col['GASST'];validgas=gas[gas!=-999.999]
    if manifest['crop_model']!='prescribed':assert np.all(validgas>=-1e-8)
    return {'days':1005,'native_ledger_max_error_cm':float(np.max(np.abs(residual))),'max_native_BALDEV_cm':float(np.max(np.abs(col['BALDEV']))),'canopy_reset_flags':flags,'actual_depth_cm':[float(k[3:-1]) for k in wc],'temperature_range_C':[float(min(col[k].min() for k in temp)),float(max(col[k].max() for k in temp))],'GASST_max_kgCH2O_ha':float(validgas.max()),'GASST_unavailable_days':int(np.sum(gas==-999.999)),'GASST_simulated':manifest['crop_model']!='prescribed'}
def main():
    p=argparse.ArgumentParser();p.add_argument('root',type=Path);p.add_argument('executable',type=Path);p.add_argument('--workers',type=int,default=8);p.add_argument('--limit',type=int);a=p.parse_args()
    root=a.root.resolve();exe=a.executable.resolve();exe.chmod(exe.stat().st_mode|0o100);exehash=sha(exe);rows=list(csv.DictReader((root/'cell_register.csv').open()))
    if a.limit:rows=rows[:a.limit]
    start=time.perf_counter();done=[]
    def run(row):
        case=root/'cells'/row['cell_id'];m=json.loads((case/'cell_manifest.json').read_text());receipt=case/'v02_run_receipt.json';t=time.perf_counter()
        identity={key:sha(case/key) for key in m['input_sha256']};assert identity==m['input_sha256'],case
        old=json.loads(receipt.read_text()) if receipt.exists() else {}
        accepted={'SUCCESS','COMPLETED_WITH_CANOPY_RESET_FLAG'}
        reuse=old.get('status') in accepted and old.get('input_sha256')==identity and old.get('executable_sha256')==exehash and (case/'result_output.csv').exists() and sha(case/'result_output.csv')==old.get('output_sha256')
        try:
            if not reuse:
                with (case/'stdout.log').open('w') as out:
                    code=subprocess.run([str(exe)],cwd=case,stdout=out,stderr=subprocess.STDOUT,timeout=180).returncode
                assert code==100,(case.name,'native returncode',code)
                assert 'Swap normal completion!' in (case/'stdout.log').read_text()
            else:code=100
            evidence=audit(case,m)
            result={'cell_id':row['cell_id'],'status':'COMPLETED_WITH_CANOPY_RESET_FLAG' if evidence['canopy_reset_flags'] else 'SUCCESS','crop_model':m['crop_model'],'returncode':code,'seconds':time.perf_counter()-t,'input_sha256':identity,'executable_sha256':exehash,'output_sha256':sha(case/'result_output.csv'),'reused':reuse,'audit':evidence}
        except Exception as e:
            result={'cell_id':row['cell_id'],'status':'FAILED','crop_model':m['crop_model'],'error':repr(e),'seconds':time.perf_counter()-t,'executable_sha256':exehash,'input_sha256':identity}
        temp=receipt.with_suffix('.tmp');temp.write_text(json.dumps(result,indent=2)+'\n');temp.replace(receipt);return result
    with ThreadPoolExecutor(max_workers=a.workers) as pool:
        tasks=[pool.submit(run,r) for r in rows]
        for task in as_completed(tasks):
            result=task.result();done.append(result)
            if result['status']=='FAILED' or len(done)%32==0:print(json.dumps({'completed':len(done),'total':len(rows),'last':result['cell_id'],'status':result['status'],'error':result.get('error'),'elapsed_s':round(time.perf_counter()-start,1)}),flush=True)
    summary={'selected_cells':len(rows),'counts':dict(Counter(r['status'] for r in done)),'wall_seconds':time.perf_counter()-start,'executable_sha256':exehash,'crop_counts':dict(Counter(r['crop_model'] for r in done)),'canopy_reset_flagged_cells':sum(bool(r.get('audit',{}).get('canopy_reset_flags')) for r in done),'full_grid_complete':len(rows)==4096 and all(r['status']!='FAILED' for r in done)}
    (root/'execution_summary_v02.json').write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps(summary),flush=True)
    assert all(r['status']!='FAILED' for r in done),summary
if __name__=='__main__':main()
