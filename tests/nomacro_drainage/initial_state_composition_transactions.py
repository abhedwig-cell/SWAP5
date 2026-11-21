"""Exercise literal admitted discard/replay/recovery on the actual new root codec."""
import argparse,ast,json,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tests/nomacro_scheduled_subsurface'),str(ROOT/'tests/nomacro_drainage')]
import original_output_controls as old
BASE='e4dfd5fd0274c51e56ac30baf247cea51a304321'
PATH='tests/nomacro_scheduled_subsurface/original_output_controls.py'


def main():
 p=argparse.ArgumentParser()
 for key in ('profile','reference-work','output'):p.add_argument('--'+key,type=Path,required=True)
 a=p.parse_args();q=json.loads((a.profile/'RESULT.json').read_text())
 assert q['status']=='ACTUAL_ORIGINAL_INITIAL_STATE_COMPOSITION_WATER_CDE_EXACT_COLD_PASS_NOT_ADMITTED' and q['native_codec']=='S5IRC003'
 assert (ROOT/PATH).read_bytes().replace(b'\r\n',b'\n')==subprocess.check_output(['git','show',BASE+':'+PATH],cwd=ROOT)
 build=Path(q['build_root']);project=old.m.e.load(Path(q['input_root']),original_output=True)
 raw=subprocess.check_output(['git','show',BASE+':'+PATH],cwd=ROOT)
 nodes=[n for n in ast.parse(raw).body if isinstance(n,ast.FunctionDef) and n.name=='transactions'];assert len(nodes)==1
 selected=[n for n in ast.walk(nodes[0]) if isinstance(n,ast.Subscript) and ast.unparse(n.value)=="trial.budget['solute_ledger_mg_cm2']" and ast.literal_eval(n.slice)==3];assert len(selected)==1
 # This actual cold/wet Snow case has positive solute inflow at the lower
 # boundary, while its irrigation solute is zero. Retain a positive-input
 # witness, attached to the independently balanced bottom inflow owner.
 selected[0].slice=ast.Constant(4)
 namespace=dict(vars(old));exec(compile(ast.fix_missing_locations(ast.Module(body=nodes,type_ignores=[])),PATH,'exec'),namespace)
 rows=old.m.rows(a.profile/'trajectory');assert rows[4]['bottom_outward_cm']<0 and rows[4]['solute_ledger_mg_cm2'][4]>0 and rows[4]['solute_ledger_mg_cm2'][3]==0
 actual=namespace['transactions'](build,a.reference_work,project,a.profile/'trajectory',a.output)
 actual['positive_CDE_input_witness']='actual inward lower-boundary flux, ledger slot4; actual irrigation slot3 exactly zero'

 result=dict(status='ACTUAL_DENSE_DAILY_CDE_ROOT_NATIVE3_EXTERNAL_DISCARD_REPLAY_RECOVERY_PASS',source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),profile_producer=q['source'],initial_selector=q['initial_selector'],optimization=q['optimization'],actual_BUILD_sha256=old.m.sha(build/'BUILD.json'),native_codec=q['native_codec'],observations=actual,actual_prepared_days=3,actual_committed_days=1,actual_discarded_days=2,compiler_executions=0,canonical_admission=False)
 with (a.output/'RESULT.json').open('x') as f:json.dump(result,f,indent=2);f.write('\n')
 print(result['status'],q['optimization'])


if __name__=='__main__':main()
