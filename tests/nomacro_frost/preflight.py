"""Preflight original frost incompatibilities and exact source-domain refusal."""
import argparse,hashlib,json,re,shutil,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];sys.path[:0]=[str(ROOT/'tools/solute'),str(ROOT/'app/hybrid_water')]
from frost_cases import create,REFUSED
import experimental_project as e
import frost_reference as f
from daily_coupling import validate_bundle
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()


def change(path,name,value):
 text,n=re.subn(r'(?mi)^([ \t]*'+name+r'[ \t]*=[ \t]*)[^\s!]+',lambda m:m[1]+str(value),path.read_text(encoding='cp1252'));assert n==1,name;path.write_text(text,encoding='cp1252')


def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--reference-work',type=Path,required=True);p.add_argument('--bundle',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();out=a.output.resolve();out.mkdir(parents=True,exist_ok=False);records=[]
 specs=[('micro-future','water-frost-free','potato.crp','SWDROUGHT',3),('no-heat','water-frost-free','swap.swp','SWHEA',0),('no-snow','water-frost-free','swap.swp','SWSNOW',0),('no-history','water-frost-free','swap.swp','SWHYST',0),('other-history','water-frost-free','swap.swp','SWHYST',1),('analytic','water-frost-free','swap.swp','SWCALT',1),('closed','water-frost-free','swap.swp','SWBOTB',6),('air-temperature','water-frost-free','swap.swp','SWTOPBHEA',1),('actual-divd1','water-frost-drained','swap.dra','SWDIVD',1),('water-drained','water-frost-drained',None,None,None),('chemical-drained',REFUSED,None,None,None),('reversed-limits','water-frost-free','swap.swp','TFROSTSTA',-2),('nonfinite-limit','water-frost-free','swap.swp','TFROSTEND','NaN'),('fake-main-divd','water-frost-drained','swap.dra','SWDIVD',1)]
 for name,key,file,field,value in specs:
  case=out/name;create(case,key)
  if file:change(case/file,field,value)
  if name=='fake-main-divd':
   path=case/'swap.swp';path.write_text(path.read_text(encoding='cp1252')+'\nSWDIVD = 0\n',encoding='cp1252')
  try:e.inspect(case)
  except ValueError as error:message=str(error)
  else:raise AssertionError('Unsupported frost preflight accepted '+name)
  if name in ('micro-future','actual-divd1','chemical-drained','fake-main-divd'):
   target=out/(name+'-refused-build');cmd=[sys.executable,'-B',str(ROOT/'tools/solute/run_water.py'),'--model',e.MODEL,'--experimental-project',str(case),'--reference-work',str(a.reference_work),'--build-only','--output',str(target)];r=subprocess.run(cmd,capture_output=True,text=True,timeout=30);assert r.returncode!=0 and not target.exists();records.append(dict(name=name,error=message,actual_cli_returncode=r.returncode,no_output=True,stderr=r.stderr))
  else:records.append(dict(name=name,error=message))
 positive=out/'positive';create(positive,'water-frost-free');project=e.load(positive);meta,case=validate_bundle(a.bundle,a.reference_work,project)
 foreign=out/'foreign-source';foreign.mkdir();shutil.copyfile(a.bundle/'BUILD.json',foreign/'BUILD.json');(foreign/'frozencond.f90').write_bytes((a.bundle/'frozencond.f90').read_bytes()+b'\n! foreign source\n')
 try:validate_bundle(foreign,a.reference_work,project)
 except ValueError as error:assert 'Foreign actual original frost source' in str(error)
 else:raise AssertionError('Foreign actual frost source accepted')
 original=(a.reference_work/'build/swap-selected/frozencond.f90').read_bytes()
 try:f.source(original+b'foreign')
 except ValueError:pass
 else:raise AssertionError('Foreign reference chain accepted')
 q=dict(status='BOUNDED_ORIGINAL_FROST_PREFLIGHT_AND_ACTUAL_SOURCE_GUARDS_PASS',source_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),driver_sha256=sha(Path(__file__)),negative_controls=records,foreign_actual_source_refused=True,foreign_original_chain_refused=True,validated_actual_bundle_sha256=sha(a.bundle/'BUILD.json'),science='NOT_QUALIFIED');(out/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n');print(q['status'])


if __name__=='__main__':main()
