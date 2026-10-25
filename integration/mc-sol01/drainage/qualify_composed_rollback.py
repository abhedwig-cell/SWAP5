"""Real joint chemical-overdraw rollback of water, heat and Boesten memory."""
import argparse,hashlib,json,os,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];p=argparse.ArgumentParser();p.add_argument('--bundle',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();out=a.output.resolve();out.mkdir();b=json.loads((a.bundle.resolve()/'column/build-complete.json').read_text());physical=b['source_build'];events=[];sha=lambda x:hashlib.sha256(x).hexdigest()
def run(cmd,label):
 t=time.monotonic();r=subprocess.run(list(map(str,cmd)),cwd=out,env=dict(os.environ,PYTHONDONTWRITEBYTECODE='1'),capture_output=True,timeout=90)
 for k in ['stdout','stderr']:(out/(label+'.'+k)).write_bytes(getattr(r,k))
 events.append(dict(command=list(map(str,cmd)),label=label,returncode=r.returncode,seconds=time.monotonic()-t));(out/'events.json').write_text(json.dumps(events,indent=2));assert not r.returncode,r.stdout.decode()+r.stderr.decode();return r
objects=[e['command'][-1]for e in physical['events']if e['category']=='compile'][:-1];archive=Path(next(x[2:]for x in physical['flags']if x.startswith('-J')))/'libttutil.a';test=ROOT/'tests/nut-sol/test_composed_heat_rollback.f90';flags=[x for x in b['flags']if not x.startswith('-J')];driver=out/'driver'
run(b['compiler_command']+flags+['-J'+str(out),test,*objects,archive,'-o',driver],'link');run([driver,'rollback','unused',out/'state'],'native');assert(out/'state.before').read_bytes()==(out/'state.after').read_bytes()==(out/'state.initialized').read_bytes();assert(out/'state.before').read_bytes()!=(out/'state.retry').read_bytes();assert(out/'state.legacy_target').read_bytes()==b'PRESERVED\n'
inputs=dict(b['input_sha256']);inputs.update({str(p.relative_to(ROOT)):sha(p.read_bytes())for p in [test,Path(__file__)]});record=dict(status='COMPOSED_REAL_ROLLBACK_RETRY_PASS',events=events,input_sha256=inputs,rejected_generation_exact=True,accepted_retry_advances=True,files={p.name:sha(p.read_bytes())for p in out.glob('state.*')});(out/'RESULT.json').write_text(json.dumps(record,indent=2)+'\n');print(record['status'])
