"""Link real production leaf controls using verified current provider objects."""
import argparse,json,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser();p.add_argument('--physical',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();a.output.mkdir()
b=json.loads((a.physical/'build-complete.json').read_text());objects=[e['command'][-1]for e in b['events']if e['category']=='compile'and not e['command'][e['command'].index('-c')+1].endswith('/app/solute_crop/main.f90')]
flags=[x for x in b['flags']if not x.startswith('-J')];events=[]
for name in ['test_native_perched_jacobian','test_native_perched_limiter']:
 d=(a.output/name).resolve();d.mkdir();cmd=b['compiler_command']+flags+['-J'+str(d),*[str(ROOT/'app/solute_column'/f)for f in ['read_swp_macro_geometry.f90','read_swp_macro_initial.f90','read_swp_macro_configuration.f90']],str(ROOT/'integration/dataqual03'/(name+'.f90')),*objects,str(a.physical/'libttutil.a'),'-o',str(d/'test')]
 start=time.monotonic();cp=subprocess.run(cmd,capture_output=True);(d/'compile.stdout').write_bytes(cp.stdout);(d/'compile.stderr').write_bytes(cp.stderr);cp.check_returncode()
 cmd=[str(d/'test'),'/workspace/scratch/9be0a7c91534/dataqual02-checkpoint/macro.nml'];cp=subprocess.run(cmd,cwd=d,capture_output=True);(d/'stdout').write_bytes(cp.stdout);(d/'stderr').write_bytes(cp.stderr);cp.check_returncode();events.append(dict(name=name,seconds=time.monotonic()-start,returncode=cp.returncode,stdout=cp.stdout.decode()))
(a.output/'RESULT.json').write_text(json.dumps(events,indent=2)+'\n');print(json.dumps(events))
