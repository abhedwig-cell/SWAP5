"""Retain positive-transport research and failed years; never admit a year."""
import argparse,base64,hashlib,io,json,subprocess,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
BASE='7eb6f10baabae2f26af168c59bf63459fa0a3516'
ANCESTOR='80dbce8d325e9197a53b7189ad184bcdf91f6f5c'
def sha(raw):return hashlib.sha256(raw).hexdigest()
def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT)
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--proof',type=Path,required=True);ap.add_argument('--output',type=Path,required=True);a=ap.parse_args()
 assert not git('diff','--name-only','HEAD').strip(),'commit sources before collecting evidence'
 files={};groups=[]
 for folder in sorted(a.proof.iterdir()):
  if not folder.is_dir()or not folder.name.startswith(('implicit-','conservative-','water-day257-','picard-')):continue
  groups.append(folder.name)
  for p in sorted(folder.rglob('*')):
   if not p.is_file()or p.is_symlink()or p.suffix.lower()in ['.o','.mod','.a','.so','.tmp']:continue
   raw=p.read_bytes()
   if raw.startswith(b'\x7fELF'):continue
   files[folder.name+'/'+str(p.relative_to(folder))]=raw
 frozen=a.proof/'frozen-root-owner-80.json';files[frozen.name]=frozen.read_bytes()
 paths=[p for p in git('diff','--name-only',BASE,'HEAD').decode().splitlines()
  if p!='integration/audits/MC_SOL01_DYNAMIC_DECAY_STATUS.json'and not p.startswith('integration/audits/evidence/')]
 for rev in git('rev-list',ANCESTOR+'..HEAD').decode().splitlines():
  for p in paths:
   r=subprocess.run(['git','show',rev+':'+p],cwd=ROOT,capture_output=True)
   if r.returncode==0:files['source-versions/'+sha(r.stdout)]=r.stdout
 postimages={p:sha((ROOT/p).read_bytes())for p in paths}
 for p in paths:files['source-versions/'+postimages[p]]=(ROOT/p).read_bytes()
 current=dict(status='BOUNDED_RESEARCH_DEFAULT_PRESERVATION_ANNUAL_BLOCKED',baseline=BASE,
  source_checkpoint=git('rev-parse','HEAD').decode().strip(),postimages=postimages,groups=groups,
  annual_qualified=False,full_historical_migration=False,canonically_admitted=False,
  annual_scope='Constructed supported soil/crops and authentic Andelst weather; not the complete original Andelst project',
  annual_failures=dict(frozen_conductivity=dict(coarse_days=256,refined_days=256,rejected_day=257),
   picard_conductivity=dict(coarse_days=266,coarse_rejected_day=267,coarse_cause='surface exfiltration outside pond carrier',
    refined_days=64,refined_rejected_day=65,refined_cause='water transaction near internal saturation')),
  excluded_proofs={'picard-transaction-preflight':'O0 supplied for both optimization cases; not an O0/O2 proof',
   'picard-nut-cold':'Mixed source postimages; see PROVENANCE_REJECTION.json; final cold proof replaces it',
   'picard-day65-tol0.01-O2':'Input-domain rejection; not a water trial',
   'picard-day65-tol0.1-O2':'Input-domain rejection; not a water trial'},
  inherited_annual_source='Earlier Picard postimage before additional fail-closed compatibility guards; failed experiments only')
 files['CURRENT.json']=(json.dumps(current,indent=2)+'\n').encode()
 files['MANIFEST.json']=(json.dumps({p:sha(v)for p,v in sorted(files.items())},indent=2)+'\n').encode()
 stream=io.BytesIO()
 with tarfile.open(fileobj=stream,mode='w:xz')as archive:
  for p,raw in sorted(files.items()):
   m=tarfile.TarInfo(p);m.size=len(raw);m.mode=0o644;m.mtime=0;archive.addfile(m,io.BytesIO(raw))
 raw=stream.getvalue();a.output.write_bytes(base64.encodebytes(raw))
 print(json.dumps(dict(path=str(a.output.relative_to(ROOT)),decoded_sha256=sha(raw),decoded_bytes=len(raw),members=len(files))))
if __name__=='__main__':main()
