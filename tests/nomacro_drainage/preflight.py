"""Original drainage method/refusal contracts and actual DRFIL resolution."""
import argparse,importlib.util,json,re,shutil,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];sys.path[:0]=[str(ROOT/'tools/solute'),str(ROOT/'app/hybrid_water')]
import drainage_table_cases as cases,experimental_project as e
from daily_coupling import validate_bundle


def change(path,field,value):
 body,n=re.subn(r'(?mi)^([ \t]*'+field+r'[ \t]*=[ \t]*)[^!\r\n]+',lambda m:m[1]+str(value)+' ',path.read_text(encoding='cp1252'));assert n==1;path.write_text(body,encoding='cp1252')


def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--configuration',choices=cases.KEYS,required=True);p.add_argument('--reference-work',type=Path,required=True);p.add_argument('--bundle',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();out=a.output.resolve();out.mkdir(parents=True,exist_ok=False);records=[]
 for name,key,field,value in [('unknown-method','water-drain-table','DRAMET',4),('zero-method','water-drain-table','DRAMET',0),('table-infiltration-layer','water-drain-table','SWDIVDINF',1),('table-top-factor','water-drain-table','SWDISLAY',2),('chemical-undistributed','chemical-drain-table','SWDIVD',0)]:
  case=out/name;cases.create(case,key);change(case/'swap.dra',field,value)
  try:e.load(case)
  except ValueError as error:message=str(error)
  else:raise AssertionError('Unsupported original drainage accepted '+name)
  target=out/(name+'-refused-build');cmd=[sys.executable,'-B',str(ROOT/'tools/solute/run_water.py'),'--model',e.MODEL,'--experimental-project',str(case),'--reference-work',str(a.reference_work),'--build-only','--output',str(target)];r=subprocess.run(cmd,capture_output=True,text=True,timeout=30);assert r.returncode!=0 and not target.exists();records.append(dict(name=name,error=message,command=cmd,returncode=r.returncode,stderr=r.stderr,no_output=True))
 positive=out/'positive';cases.create(positive,a.configuration);project=e.load(positive);validate_bundle(a.bundle,a.reference_work,project)
 custom=None
 if a.configuration=='water-drain-signed':
  case=out/'custom-file';cases.create(case,a.configuration);(case/'drains').mkdir();shutil.copyfile(case/'swap.dra',case/'drains/selected.dra');change(case/'swap.dra','DRAMET',2);change(case/'swap.swp','DRFIL',"'selected'");change(case/'swap.swp','PATHDRAIN',"'drains/'");project=e.load(case)
  build=out/'custom-build';cmd=[sys.executable,'-B',str(ROOT/'tools/solute/run_water.py'),'--model',e.MODEL,'--experimental-project',str(case),'--reference-work',str(a.reference_work),'--build-only','--kernel-opt','O0','--donor-opt','O0','--output',str(build)];r=subprocess.run(cmd,capture_output=True,text=True,timeout=180);(out/'custom-build.stderr').write_text(r.stderr);assert r.returncode==0,r.stderr
  spec=importlib.util.spec_from_file_location('original_mixtures',ROOT/'tests/nomacro_mixtures/run.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);warm=out/'custom-prefix53';custom,rows=m.trajectory(build,a.reference_work,project,warm,53,{50,53},30);custom['own']=m.own(build,a.reference_work,project,warm,rows,50,53,out/'custom-own50');assert 'linear_pond_top_jacobian' in (build/'headcalc.f90').read_text();custom['actual_selected_drain_file']='drains/selected.dra';custom['unused_swap_dra_method']=2
 q=dict(status='ORIGINAL_TABLE_DRAINAGE_PREFLIGHT_AND_DRFIL_PASS',source_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),configuration=a.configuration,negative_controls=records,actual_bundle_validated=True,custom_file_probe=custom,science='NOT_QUALIFIED');(out/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n');print(q['status'])


if __name__=='__main__':main()
