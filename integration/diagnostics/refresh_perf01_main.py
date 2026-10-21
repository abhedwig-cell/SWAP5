"""Refresh only an input-guard main; retain exact completed provider build receipts."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import time

ROOT = Path(__file__).resolve().parents[2]


def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--build',type=Path,required=True)
    ap.add_argument('--output',type=Path,required=True)
    a = ap.parse_args()
    base,out = a.build.resolve(),a.output.resolve()
    old = json.loads((base/'build-complete.json').read_text())
    main_path = 'app/solute_column/main.f90'
    assert all(sha(ROOT/p)==h for p,h in old['input_sha256'].items() if p!=main_path)
    assert old['status']=='BUILT' and sha(base/'swap5_solute_column')==old['executable_sha256']
    assert old['events'][-2]['category']=='compile' and old['events'][-2]['command'][-3]==str(ROOT/main_path)
    assert old['events'][-1]['category']=='link'
    shutil.copytree(base,out,copy_function=os.link)
    main_object = out/Path(old['events'][-2]['command'][-1]).name
    for p in [main_object,out/'swap5_solute_column',out/'build.json',out/'build-complete.json',
              out/old['events'][-2]['stdout'],out/old['events'][-2]['stderr'],
              out/old['events'][-1]['stdout'],out/old['events'][-1]['stderr']]:
        p.unlink()
    protected = {str(p.relative_to(base)):sha(p) for p in base.rglob('*') if p.is_file()
                 and p.suffix in {'.o','.mod','.a'} and p.name!=main_object.name}
    report = json.loads(json.dumps(old))
    report['events'] = report['events'][:-2]
    report['flags'] = [f.replace(str(base),str(out)) for f in report['flags']]
    report['candidate'] = subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()
    report['input_sha256'][main_path] = sha(ROOT/main_path)
    report['controlled_main_refresh'] = dict(preimage=old,reused_provider_artifacts=protected,
        unchanged_provider_source_verified=True,reused_prefix_events=len(report['events']),
        cost_note='Completed provider event costs are inherited, not new compilation cost')
    objects = [out/Path(e['command'][-1]).name for e in old['events'] if e['category']=='compile']
    commands = [old['compiler_command']+report['flags']+['-c',str(ROOT/main_path),'-o',str(main_object)],
                old['compiler_command']+report['flags']+list(map(str,objects))+[str(out/'libttutil.a'),'-o',str(out/'swap5_solute_column')]]
    for category,command in zip(['compile','link'],commands):
        start=time.monotonic();p=subprocess.run(command,cwd=out,capture_output=True);i=len(report['events'])
        for stream in ['stdout','stderr']:(out/f'{i:04d}.{stream}').write_bytes(getattr(p,stream))
        report['events'].append(dict(command=command,category=category,returncode=p.returncode,
            seconds=time.monotonic()-start,stdout=f'{i:04d}.stdout',stderr=f'{i:04d}.stderr'))
        p.check_returncode()
    assert all(sha(base/p)==h and sha(out/p)==h for p,h in protected.items())
    assert all(sha(ROOT/p)==h for p,h in report['input_sha256'].items())
    report['executable_sha256']=sha(out/'swap5_solute_column')
    for name in ['build.json','build-complete.json']:(out/name).write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(dict(status='EXACT_PROVIDER_REUSE_CURRENT_MAIN_COMPILE_LINK_PASS',providers=report['provider_count'])))


if __name__=='__main__':
    main()
