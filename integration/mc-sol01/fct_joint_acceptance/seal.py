"""Seal all measured development rounds and the fresh current-source proof."""
import argparse,base64,hashlib,io,json,runpy,subprocess,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).resolve().parent
sha=lambda b:hashlib.sha256(b).hexdigest()
def main():
    ap=argparse.ArgumentParser();ap.add_argument('--round-root',type=Path,required=True);a=ap.parse_args();files={};cost={}
    labels=['round2','round3','round4','round5'];files['ROUNDS.json']=json.dumps(labels).encode()
    for label in labels:
        folder=a.round_root/('joint-'+label);r=json.loads((folder/'execution.json').read_text());checkpoint=r['baseline']
        files[label+'/checkpoint.raw']=subprocess.check_output(['git','cat-file','commit',checkpoint],cwd=ROOT)
        for p,h in r['inputs'].items():
            raw=subprocess.check_output(['git','show',checkpoint+':'+p],cwd=ROOT);assert sha(raw)==h
            files[label+'/source/'+p]=raw
        paths=[folder/'execution.json',folder/'joint_driver.f90',folder/'storage_successor.f90']
        paths.extend(folder/e[s] for e in r['events'] for s in ['stdout','stderr'])
        for p in paths:files[label+'/'+p.name]=p.read_bytes()
        cost[label]=sum(e['seconds'] for e in r['events'])
    files['STARTUP.json']=json.dumps(dict(status='SCANNER_REJECTED_BEFORE_BUILD',baseline='2381d1d6',
        error='ValueError: generated target outside strict_closure repository root',
        evidence_kind='RECOVERY_DIAGNOSTIC_NOT_A_NUMERICAL_EXECUTION',
        remedy='Resolve committed fixture plus explicitly imported real providers; substitute generated program only after strict scan.'),indent=2).encode()
    files['startup/generated_driver.f90']=(a.round_root/'joint-round1/joint_driver.f90').read_bytes()
    files['startup/source_run.py']=subprocess.check_output(['git','show','2381d1d6:integration/mc-sol01/fct_joint_acceptance/run.py'],cwd=ROOT)
    wrapper=a.round_root/'gfortran-local';files['toolchain/gfortran-local']=wrapper.read_bytes()
    latest=json.loads(files['round5/execution.json']);assert sha(wrapper.read_bytes())==latest['toolchain_files'][str(wrapper)]
    owner=runpy.run_path(str(ROOT/'integration/audits/verify_nut_historical_output_caller.py'))
    result=owner['verify']();controls=owner['self_test']()
    files['PRESERVATION.json']=json.dumps(dict(qualified=result['qualified'],controls=len(controls),control_labels=controls,result=result),indent=2).encode()
    v=runpy.run_path(str(HERE/'verify.py'));result=v['assess'](files)
    # Fresh shared-backend postimage must preserve pre-drainage joint endpoints.
    prior=json.loads(files['round4/execution.json'])
    for before,after in zip(prior['cases'],latest['cases']):
        keys=['optimization','n','factor','exponent'];assert all(before[k]==after[k] for k in keys)
        endpoint=lambda raw:[l for l in raw.splitlines() if l.startswith((b'CELL ',b'JOINT_PASS '))]
        assert endpoint(files['round4/'+before['stdout']])==endpoint(files['round5/'+after['stdout']])
    files['CURRENT_RECONCILIATION.json']=json.dumps(dict(status='CURRENT_DRAINAGE_BACKEND_REQUALIFIED',endpoint_cases_exact=24,
        before=prior['baseline'],after=latest['baseline'],changed_inputs=[p for p,h in latest['inputs'].items() if prior['inputs'].get(p)!=h]),indent=2).encode()
    files['VERIFICATION.json']=json.dumps(result,indent=2).encode();controls=v['controls'](files);files['CONTROLS.json']=json.dumps(controls,indent=2).encode()
    files['MANIFEST.json']=json.dumps({p:sha(b) for p,b in sorted(files.items())},indent=2).encode();stream=io.BytesIO()
    with tarfile.open(fileobj=stream,mode='w:xz',preset=6) as t:
        for p,b in sorted(files.items()):
            info=tarfile.TarInfo(p);info.size=len(b);info.mtime=0;t.addfile(info,io.BytesIO(b))
    raw=stream.getvalue();(HERE/'EVIDENCE.tar.xz.b64').write_bytes(base64.encodebytes(raw))
    index=dict(decoded_sha256=sha(raw),bytes=len(raw),members=len(files),controls=controls,cost_seconds=cost,
        current_owner_controls=json.loads(files['PRESERVATION.json'])['controls'])
    for name,data in [('EVIDENCE_INDEX.json',index),('MEASUREMENTS.json',result),('CURRENT_RECONCILIATION.json',json.loads(files['CURRENT_RECONCILIATION.json']))]:
        (HERE/name).write_text(json.dumps(data,indent=2)+'\n')
    print(json.dumps(index,indent=2))
if __name__=='__main__':main()
