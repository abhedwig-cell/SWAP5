"""Freeze completed native Grassgrowth evidence; never copy an active run.

The --segments list is explicit so a later original continuation can replace the
bounded snapshot without changing the assertions or inventing a process exit.
"""
import argparse,hashlib,io,json,subprocess,tarfile
from pathlib import Path
from check_history import check

ROOT=Path(__file__).resolve().parents[2]
BASE='d541180b32df692fa67c5fc795cc6b15e6812ed6'
O0_YEAR=['dq15-weighted-yearrun-O0','dq15-weighted-yearsuffix-O0','dq15-weighted-cont188-O0','dq15-weighted-cont233-O0']
sha=lambda b:hashlib.sha256(b).hexdigest()

def package(workspace,segments):
 files={};external={};sources={}
 def add(path,name=None):
  path=Path(path);name=name or path.relative_to(workspace).as_posix()
  raw=path.read_bytes()
  assert name not in files or files[name]==raw,name
  files[name]=raw
 def bind(mapping):
  for p,h in mapping.items():
   path=Path(p)
   if path.is_absolute()and '/SWAP5/'in p:relative=p.split('/SWAP5/',1)[1]
   elif not path.is_absolute():relative=p
   else:
    assert sha(path.read_bytes())==h,p
    name='external/'+h+'-'+path.name;add(path,name);external[p]=name;continue
   assert sha((ROOT/relative).read_bytes())==h,relative
   assert relative not in sources or sources[relative]==h
   sources[relative]=h
 def small_tree(folder):
  for p in folder.rglob('*'):
   if p.is_file()and(p.suffix in ['.json','.csv','.bin','.f90','.crp','.swp','.met','.bbc','.dra','.stdout','.stderr']or p.name in ['stdout','stderr','application.binding','swap.ok','swap.err','swap.log','swap.wrn']):add(p)
 def run(folder):
  assert (folder/'checkpoint.bin').exists()
  # A missing RESULT is retained as an interruption with UNKNOWN native exit.
  if not(folder/'RESULT.json').exists():assert(folder/'INTERRUPTION.json').exists(),folder
  binding=json.loads((folder/'application.binding').read_text());bind(binding['source_sha256'])
  small_tree(folder)
 for name in segments:run(workspace/name)
 for name in [*O0_YEAR,'dq15-weighted-restart126-140-O2','dq15-weighted-restart365-367-O2','dq15-weighted-restart365-367-O0']:
  run(workspace/name)
 for opt,negative in [('O0','dq15-weighted-negative-O0'),('O2','dq15-weighted-negative-b-O2')]:
  build=workspace/('dq15-weighted-'+opt);report=json.loads((build/'BUILD.json').read_text())
  assert sha((build/'swap5_grass_startup').read_bytes())==report['executable_sha256']
  bind(report['source_sha256']);add(build/'BUILD.json')
  for p in build.glob('*.stdout'):add(p)
  for p in build.glob('*.stderr'):add(p)
  q=workspace/negative;report=json.loads((q/'RESULT.json').read_text());bind(report['source_sha256'])
  for e in report['events']:
   case=q/e['case'];assert not(case/'checkpoint.bin').exists()and not(case/'budget.csv').exists()
  small_tree(q)
 for name in ['dq15-weighted-runtime','dq15-mowing-final-oracle']:
  q=workspace/name;report=json.loads((q/'RESULT.json').read_text());bind(report['source_sha256']);small_tree(q)
 ref=workspace/'dq15-original-reference';small_tree(ref)
 donor=Path('/workspace/scratch/f29d9f3066a3/dq13-reference431')
 add(donor/'BUILD.json','original431/BUILD.json')
 add(Path('/workspace/scratch/f29d9f3066a3/dq14-reference/swap.swp'),'original431/previous-output-only.swp')
 donor_build=json.loads((donor/'BUILD.json').read_text())
 for p,h in donor_build['original_provider_build']['source_sha256'].items():
  path=donor/'providers'/p;assert sha(path.read_bytes())==h,p
  name='original431/providers/'+p;add(path,name);external[p]=name
 main=donor/'providers/selected/swap_main.f90';assert sha(main.read_bytes())==donor_build['source_sha256']
 for path in (donor/'providers/selected').glob('*.f90'):add(path,'original431/providers/selected/'+path.name)
 history=check([workspace/n for n in segments],ref/'result_output.csv')
 files['HISTORY_CHECK.json']=(json.dumps(history,indent=2)+'\n').encode()
 o0_history=check([workspace/n for n in O0_YEAR],ref/'result_output.csv')
 assert o0_history['completed_days']==367 and o0_history['segments'][-1]['returncode']==0
 files['O0_HISTORY_CHECK.json']=(json.dumps(o0_history,indent=2)+'\n').encode()
 manifest={n:sha(b)for n,b in sorted(files.items())}
 files['MANIFEST.json']=(json.dumps(manifest,indent=2)+'\n').encode()
 output=ROOT/'integration/dataqual15/EVIDENCE.tar.xz'
 with tarfile.open(output,'w:xz',preset=6)as tar:
  for n,b in sorted(files.items()):
   info=tarfile.TarInfo(n);info.size=len(b);info.mode=0o644;info.mtime=0;tar.addfile(info,io.BytesIO(b))
 delta=subprocess.check_output(['git','diff','--name-status',BASE,'HEAD','--','src','app','reference'],cwd=ROOT,text=True).splitlines()
 qualified_source=subprocess.check_output(['git','rev-parse','76d41a0'],cwd=ROOT,text=True).strip()
 summary=dict(schema=1,baseline=BASE,qualified_scientific_source_commit=qualified_source,evidence_sha256=sha(output.read_bytes()),archive_files=len(files),source_sha256=sources,external_source_members=external,reviewed_production_delta={line.split('\t')[1]:line.split('\t')[0]for line in delta},history_segments=segments,original_project_days=1827,executed_days=history['completed_days'],full_original_execution=history['full_original_execution'],scientific_equivalence=False,process_exit_scope='Interrupted native segments have UNKNOWN process exit; a complete original run requires successful native completion of the final exact same-build continuation.',diagnostic_log_scope='Daily budgets, crop rows and CRC-valid atomic checkpoints are complete for the archived interval; full stdout diagnostic completeness is not claimed.')
 summary['O0_history_segments']=O0_YEAR
 summary['O0_O2_exact_days']=367
 (ROOT/'integration/dataqual15/EVIDENCE_MANIFEST.json').write_text(json.dumps(summary,indent=2)+'\n')
 print(json.dumps({k:v for k,v in summary.items()if k not in ['source_sha256','external_source_members','reviewed_production_delta']},indent=2))

if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--workspace',type=Path,default=ROOT.parent);p.add_argument('--segments',nargs='+',default=['dq15-weighted-yearrun-O2','dq15-weighted-cont438-O2']);a=p.parse_args();package(a.workspace.resolve(),a.segments)
