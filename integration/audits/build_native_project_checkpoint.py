"""Persist successful controls AND failed annual experiments, without admission."""
import argparse,base64,hashlib,io,json,subprocess,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
BASE='80dbce8d325e9197a53b7189ad184bcdf91f6f5c'
def sha(raw):return hashlib.sha256(raw).hexdigest()
def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT)
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--proof',type=Path,required=True);ap.add_argument('--output',type=Path,required=True);a=ap.parse_args()
 files={}
 groups=['preparation-final','short-final','spatial','rejection','annual','resolved-O0','resolved-O2',
  'diagnostic-year','retry-day229','final-O0','final-O2','retry-O0']
 for group in groups:
  folder=a.proof/group;assert folder.is_dir(),folder
  for p in sorted(folder.rglob('*')):
   if not p.is_file()or p.is_symlink()or p.suffix in ['.o','.mod','.a','.so','.tmp']:continue
   raw=p.read_bytes()
   if raw.startswith(b'\x7fELF'):continue
   files[group+'/'+str(p.relative_to(folder))]=raw
 changed=git('diff','--name-only',BASE,'--').decode().splitlines()
 paths=[p for p in changed if p!='integration/audits/MC_SOL01_DYNAMIC_DECAY_STATUS.json'and not p.startswith('integration/audits/evidence/')]
 # Source versions retain exact failed runner/retry postimages too. A failed
 # experiment is never silently rebound to the later corrected current source.
 for rev in git('rev-list',BASE+'..HEAD').decode().splitlines()+['HEAD']:
  for p in paths:
   r=subprocess.run(['git','show',rev+':'+p],cwd=ROOT,capture_output=True)
   if r.returncode==0:files['source-versions/'+sha(r.stdout)]=r.stdout
 for p in paths:files['source-versions/'+sha((ROOT/p).read_bytes())]=(ROOT/p).read_bytes()
 current=dict(baseline=BASE,source_checkpoint=git('rev-parse','HEAD').decode().strip(),
  status='PROPOSED_ANNUAL_TRANSPORT_BLOCKED_NOT_ADMITTED',
  postimages={p:sha((ROOT/p).read_bytes())for p in paths},
  failed_years={'annual':dict(days=228,rejected_day=229),
   'resolved-O0':dict(days=140,rejected_day=141),'resolved-O2':dict(days=140,rejected_day=141)},
  cross_year_physical='NOT_REACHED_DEPENDENCY',
  original_units='LDIS=.01/.02cm; read_solute_CDE and native import perform no conversion',
  superseded_experiment='Joint halving did not cure coarse rejection; removed from current driver',
  scope='Constructed supported soil/crops with authentic weather, NOT complete original Andelst model')
 files['CURRENT.json']=(json.dumps(current,indent=2)+'\n').encode()
 files['MANIFEST.json']=(json.dumps({p:sha(v)for p,v in sorted(files.items())},indent=2)+'\n').encode()
 stream=io.BytesIO()
 with tarfile.open(fileobj=stream,mode='w:xz')as archive:
  for p,raw in sorted(files.items()):
   m=tarfile.TarInfo(p);m.size=len(raw);m.mode=0o644;m.mtime=0;archive.addfile(m,io.BytesIO(raw))
 raw=stream.getvalue();a.output.write_bytes(base64.encodebytes(raw))
 print(json.dumps(dict(path=str(a.output.relative_to(ROOT)),decoded_sha256=sha(raw),decoded_bytes=len(raw),members=len(files))))
if __name__=='__main__':main()
