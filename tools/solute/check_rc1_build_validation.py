"""Public refusal checks around invocation-local compiler proof reuse."""
import argparse,json,os,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--reference',type=Path,required=True);p.add_argument('--bundle',type=Path,required=True);p.add_argument('--output',type=Path,required=True)
a=p.parse_args();a.output=a.output.resolve();a.output.mkdir();bundle=a.bundle.resolve();reference=a.reference.resolve()
meta=json.loads((bundle/'BUILD.json').read_text());events=[]
def refuse(label,env=None):
 output=a.output/label;command=[sys.executable,'-B','tools/solute/run_water.py','--no-macro-release','--model',meta['project']['model'],'--reference-work',str(reference),'--build-bundle',str(bundle),'--output',str(output),'--days','1']
 r=subprocess.run(command,cwd=ROOT,env=env,capture_output=True,text=True,timeout=15)
 (a.output/(label+'.log')).write_text(r.stdout+r.stderr)
 assert r.returncode!=0 and not output.exists(),label
 events.append(dict(label=label,refused_before_output=True,command=command,returncode=r.returncode))
refuse('current-toolchain-missing',dict(os.environ,PATH=''))
p=bundle/'BUILD.json';original=p.read_bytes();changed=json.loads(original);changed['identity']['compiler_sha256']='0'*64
try:p.write_text(json.dumps(changed));refuse('foreign-build-compiler')
finally:p.write_bytes(original)
p=reference/'PREPARED.json';original=p.read_bytes();changed=json.loads(original);changed['toolchain']['gfortran']['sha256']='0'*64
try:p.write_text(json.dumps(changed));refuse('foreign-provider-compiler')
finally:p.write_bytes(original)
if 'restart_publisher' in meta['identity']:
 p=bundle/'BUILD.json';original=p.read_bytes()
 for field,message in [('source_sha256','Build durable restart publisher differs'),
                       ('gcc_sha256','Build publisher compiler differs')]:
  changed=json.loads(original);changed['identity']['restart_publisher'][field]='0'*64
  try:p.write_text(json.dumps(changed));refuse('foreign-publisher-'+field)
  finally:p.write_bytes(original)
  assert message in (a.output/('foreign-publisher-'+field+'.log')).read_text()
 library=bundle/('restart_publish.dll' if os.name=='nt' else 'restart_publish.so')
 original=library.read_bytes()
 try:library.write_bytes(original+b'changed');refuse('changed-publisher-library')
 finally:library.write_bytes(original)
 assert 'Build durable restart publisher differs' in (a.output/'changed-publisher-library.log').read_text()
(a.output/'RESULT.json').write_text(json.dumps(dict(status='INVOCATION_LOCAL_TOOLCHAIN_REFUSALS_PASS',events=events),indent=2)+'\n')
print('INVOCATION_LOCAL_TOOLCHAIN_REFUSALS_PASS',flush=True)
