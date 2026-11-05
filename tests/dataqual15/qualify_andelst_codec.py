"""Actual original-source macro byte roundtrips and early atomic refusals."""
import argparse,csv,hashlib,json,shutil,subprocess,zlib,struct
from pathlib import Path
sha=lambda b:hashlib.sha256(b).hexdigest()

def main():
 p=argparse.ArgumentParser();p.add_argument('--workspace',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
 w=a.workspace.resolve();out=a.output.resolve();out.mkdir();proof={};payloads={}
 for opt in ('O0','O2'):
  base=w/('s5-events-andelst-prefix-exact-'+opt);own=w/('s5-events-andelst-own-exact-'+opt)
  r=json.loads((base/'RESULT.json').read_text());s=json.loads((own/'RESULT.json').read_text())
  assert r['returncode']==s['returncode']==0 and not r['censored']and not s['censored']
  assert r['original_initialization']and not s['original_initialization']and s['strict_own_restart_sha256']
  raw=(base/'restart.bin').read_bytes();assert raw==(own/'restart.bin').read_bytes()
  assert raw[:8]==b'S5WM0001'and zlib.crc32(raw[:-4])==struct.unpack('=I',raw[-4:])[0]
  rows=lambda folder:list(csv.DictReader((folder/'budget.csv').open()))
  assert rows(base)[1:]==rows(own)and all(abs(float(x['water_residual_cm']))<1e-10 for x in rows(base))
  original=Path(s['command'][2]);incoming=original.read_bytes();assert sha(incoming)==s['strict_own_restart_sha256']
  payloads[opt]=raw[72:-4];events=[]
  for kind in ('crc','truncated','binding'):
   folder=out/(opt+'-'+kind);folder.mkdir()
   for name in r['original_input_sha256']:shutil.copyfile(base/name,folder/name)
   bad=bytearray(incoming)
   if kind=='crc':bad[-5]^=1
   if kind=='truncated':bad=bad[:-7]
   seed=folder/'bad.bin';seed.write_bytes(bad);target=folder/'restart.bin';target.write_bytes(incoming)
   cmd=s['command'].copy();cmd[2]=str(seed)
   if kind=='binding':cmd[6]='0'*64
   cp=subprocess.run(cmd,cwd=folder,capture_output=True,timeout=30)
   (folder/'stdout').write_bytes(cp.stdout);(folder/'stderr').write_bytes(cp.stderr)
   assert cp.returncode!=0 and b'native macro water restart rejected'in cp.stdout,kind
   assert target.read_bytes()==incoming and seed.read_bytes()==bad and not(folder/'budget.csv').exists(),kind
   events.append(dict(kind=kind,returncode=cp.returncode,command=cmd))
  assert original.read_bytes()==incoming
  proof[opt]=dict(status='ACTUAL_ORIGINAL_MACRO_OWN_RESTART_AND_ATOMIC_REFUSALS_PASS',endpoint=r['last_completed_source_interval'],
   checkpoint_sha256=sha(raw),executable_sha256=r['executable_sha256'],maximum_water_residual_cm=max(abs(float(x['water_residual_cm']))for x in rows(base)),events=events)
 assert payloads['O0']==payloads['O2']
 result=dict(status='NATIVE_MACRO_O0_O2_OWN_BYTES_AND_REFUSALS_PASS',builds=proof,optimization_physical_payload_exact=True,
  excluded_from_cross_optimization_comparison='Distinct64-byte executable bindings and their CRCs; no stream was rebound.',full481=False)
 (out/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))

if __name__=='__main__':main()
