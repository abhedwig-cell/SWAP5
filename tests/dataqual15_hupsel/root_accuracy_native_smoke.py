"""Cold current original-input profile and exact own disk restart smoke."""
import argparse,json,os,subprocess,sys
from pathlib import Path
import film_runtime as original
import film_rotation as native
from root_accuracy_production_runtime import SELECTOR,exact_window

def main():
 p=argparse.ArgumentParser()
 for name in ('build','output','compiler'):p.add_argument('--'+name,type=Path,required=True)
 a=p.parse_args();out=a.output.resolve();out.mkdir();b=a.build.resolve();exe=b/('swap5_hupsel_germination.exe'if os.name=='nt'else'swap5_hupsel_germination')
 inputs=original.inputs(out/'inputs');swp=inputs/'swap.swp';swp.write_bytes(swp.read_bytes()+SELECTOR)
 full=native.execute(exe,inputs,out/'full7',7,capture=[1,2,6,7]);native.ensure_captures(exe,inputs,full,out,[1,2,6,7])
 for first,last in [(1,2),(6,7)]:
  strict=native.execute(exe,inputs,out/f'own{first}-{last}',last,seed=full/f'checkpoint-{first}.bin');exact_window(full,strict,first,last)
 case=native.execute(exe,inputs,out/'day2',2)
 subprocess.run([sys.executable,'-B',str(Path(__file__).with_name('qualify_root_profile_controls.py')),'--short','--build',str(b),'--case',str(case),'--compiler',str(a.compiler),'--output',str(out/'controls')],check=True)
 (out/'RESULT.json').write_text(json.dumps(dict(status='COLD_CURRENT_ROOT_PROFILE_ORIGINAL7_OWN_RESTART_AND_PUBLIC_CONTROLS_PASS',days=7,strict_own_windows=[[1,2],[6,7]],executable_sha256=native.sha(exe.read_bytes()),whole_scientific_admission=False),indent=2)+'\n')
if __name__=='__main__':main()
