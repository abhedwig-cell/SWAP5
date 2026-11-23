"""Independent original Snow native/cold audit plus paired9 soil/global ledgers."""
import argparse,ast,hashlib,json,sys
from decimal import Decimal,localcontext
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tests/nomacro_drainage'),str(ROOT/'tests/nomacro_scheduled_subsurface')]
import snow_undrained_forensics as original
from analytical_hydraulic_archives import SHA
from explicit_bottom9_source_inverse import git,blob,norm

PARENT='04dadca2bf52027ef9c72360684c86bd98aa77ff'
FROZEN='tests/nomacro_drainage/snow_undrained_forensics.py'
PERIOD='ACTUAL_EXPLICIT9_SNOW_PHYSICAL_NATIVE_OUTPUT_PERIOD_PASS_NOT_ADMITTED'


def literal_audit():
 raw=blob(PARENT,FROZEN);assert norm((ROOT/FROZEN).read_bytes())==raw
 node=next(n for n in ast.parse(raw).body if isinstance(n,ast.FunctionDef) and n.name=='audit')
 edits={'status':0,'domain':0,'field':0}
 class Domain(ast.NodeTransformer):
  def visit_Constant(self,value):
   if value.value=='ACTUAL_SNOW_UNDRAINED_PHYSICAL_NATIVE_OUTPUT_PERIOD_PASS':value.value=PERIOD;edits['status']+=1
   elif value.value=='exact_original_output':value.value='exact_user_output';edits['field']+=1
   return value
  def visit_Compare(self,value):
   if ast.unparse(value)=="s['SWBOTB'] in (5, 8)":
    value.comparators=[ast.Tuple(elts=[ast.Constant(9)],ctx=ast.Load())];edits['domain']+=1
   return self.generic_visit(value)
 node=Domain().visit(node);assert edits==dict(status=1,domain=1,field=1)
 namespace=dict(vars(original));exec(compile(ast.fix_missing_locations(ast.Module(body=[node],type_ignores=[])),FROZEN,'exec'),namespace)
 return namespace['audit'],SHA(raw)


def audit(profile):
 profile=Path(profile);q=json.loads((profile/'RESULT.json').read_text());assert q['status']==PERIOD and q['days']==35
 inputs=Path(q['input_root']);build=Path(q['build_root']);meta=json.loads((build/'BUILD.json').read_text());selected=meta['identity']['original_output']
 assert selected['swbotb']==9 and selected['swkimpl']==selected['swhyst']==selected['swdra']==0 and selected['swsnow']==1 and selected['kind'] in ('water','cde') and selected['paired_snow_boundary'] is True
 function,parent_reader_sha=literal_audit();inherited=function(profile)
 rows=[json.loads(line) for line in (profile/'trajectory/daily.jsonl').read_text().splitlines()];assert len(rows)==35
 d=lambda value:Decimal(str(value))
 global_residual=[];soil_residual=[]
 with localcontext() as context:
  context.prec=60
  for row in rows:
   residual=sum(map(d,row['stock_start_cm']))+sum(map(d,row['external_flux_cm'][:7]))-sum(map(d,row['external_flux_cm'][7:]))-sum(map(d,row['stock_end_cm']))
   assert abs(residual)<=Decimal('1e-10'),'Original six-stock Snow water balance differs'
   global_residual.append(abs(residual));assert row['external_flux_cm'][-1]==0 and row['pressure_head_cm'][-1]==-1005.0
  for line in (profile/'trajectory/original/donor.stdout').read_text().splitlines():
   if not line.startswith('HYBRID_SNOW_SOIL_RECEIPT '):continue
   values=list(map(Decimal,line.split()[1:]));assert len(values)==29
   residual=sum(values[12:19])-sum(values[19:28])+sum(values[6:12])-sum(values[:6])
   assert abs(residual)<=Decimal('1e-10') and abs(values[-1])<=Decimal('1e-10'),'Actual net soil rainfall/melt ledger differs'
   soil_residual.append(abs(residual))
 assert len(soil_residual)==35
 assert rows[0]['stock_start_cm'][2]==0.4 and max(row['stock_end_cm'][2] for row in rows)>0.4 and rows[-1]['stock_end_cm'][2]==0
 assert rows[-1]['stock_end_cm'][0]>rows[0]['stock_start_cm'][0] and max(abs(a-b) for a,b in zip(rows[0]['pressure_head_cm'],rows[-1]['pressure_head_cm']))>1
 return dict(status='INDEPENDENT_EXPLICIT9_ACTIVE_SNOW_ACCUMULATION_MELT_ALL_NODE_SOIL_GLOBAL_LEDGER_NATIVE_EXACT_COLD_PASS_NOT_ADMITTED',producer=q['source'],observer_source=q.get('observer_source'),case=q['case'],optimization=q['optimization'],actual_days=35,actual_native_checkpoints=7,actual_exact_cold_windows=3,actual_original_Snow_scalar_carry=7,actual_BUILD_sha256=SHA((build/'BUILD.json').read_bytes()),frozen_original_snow_reader_sha256=parent_reader_sha,frozen_original_scientific_checks=inherited,decimal_global_maximum_absolute_residual_cm=str(max(global_residual)),decimal_net_soil_maximum_absolute_residual_cm=str(max(soil_residual)),absolute_water_limit_cm='1e-10',original_boundary_head=-1000.0,original_prescribed_qbot=0.0,original_last_node_head=-1005.0,model_executions=0,compiler_executions=0,canonical_admission=False)


if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--profile',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();q=audit(a.profile)
 with a.output.open('x') as f:json.dump(q,f,indent=2);f.write('\n')
 print(q['status'],q['decimal_global_maximum_absolute_residual_cm'],q['decimal_net_soil_maximum_absolute_residual_cm'])
