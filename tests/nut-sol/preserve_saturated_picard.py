"""Affected native no-DRA and wet-day atomicity on the new Reference solve."""
import argparse,csv,hashlib,json,runpy,subprocess,sys,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser();p.add_argument('--bundle',required=True,type=Path);p.add_argument('--prior',required=True,type=Path);p.add_argument('--fixture',required=True,type=Path);p.add_argument('--output',required=True,type=Path);a=p.parse_args()
out=a.output.resolve();out.mkdir();bundle=json.loads((a.bundle/'bundle.json').read_text());events=[]
original_run=subprocess.run
def run(cmd,*args,**kw):
 # The host has reset execute mode on an otherwise hash-identical local ELF.
 # Restore only this newly built bundle's executable mode before each launch.
 for key in ['exe','project_reader','crop_reader','root_reader']:
  exe=Path(bundle[key]);assert hashlib.sha256(exe.read_bytes()).hexdigest()==bundle['executable_sha256'][str(exe)];exe.chmod(exe.stat().st_mode|0o100)
 t=time.perf_counter();r=original_run(cmd,*args,**kw);events.append(dict(command=list(map(str,cmd)),returncode=r.returncode,seconds=time.perf_counter()-t));return r
subprocess.run=run
common=[sys.executable,ROOT/'tools/solute/run_project.py',a.prior/'project.swp','--bundle',a.bundle,'--temporal-tolerance','.001','--solute-transport','implicit_upwind','--water-conductivity','picard_continuous','--surface-exfiltration','historical_zero']
r=run(list(map(str,common+['--output',out/'ordinary','--stop-after','481'])),cwd=ROOT,capture_output=True,timeout=240)
(out/'ordinary.stdout').write_bytes(r.stdout);(out/'ordinary.stderr').write_bytes(r.stderr);assert r.returncode==0,r.stderr.decode()
def rows(p):return[{k:float(v)for k,v in d.items()}for d in csv.DictReader(p.open())]
new=rows(out/'ordinary/budget.csv');old=rows(a.prior/'full/budget.csv');assert len(new)==len(old)==481
for d in new:
 assert abs(d['water_residual_cm'])<1e-10 and abs(d['solute_residual_mg_cm2'])<1e-10
 assert abs(d['water_end_cm']-d['water_start_cm']-d['rain_supplied_cm']+d['runoff_cm']+d['soil_evaporation_cm']+d['pond_evaporation_cm']+d['actual_transpiration_cm']-d['bottom_up_cm'])<1e-10
compare={k:dict(max_daily_difference_cm=max(abs(x[k]-y[k])for x,y in zip(new,old)),sum_difference_cm=sum(x[k]-y[k]for x,y in zip(new,old)))for k in ['runoff_cm','infiltration_cm','soil_evaporation_cm','pond_evaporation_cm','actual_transpiration_cm','water_end_cm']}
# Declared physical preservation:0.01mm/day runoff and0.1mm storage; hard mass unchanged.
assert compare['runoff_cm']['max_daily_difference_cm']<.001
assert compare['water_end_cm']['max_daily_difference_cm']<.01
sys.argv=['qualify_detailed_rain_rollback.py','--bundle',str(a.bundle),'--fixture',str(a.fixture),'--output',str(out/'wet')]
runpy.run_path(str(ROOT/'tests/nut-sol/qualify_detailed_rain_rollback.py'),run_name='__main__')
wet=json.loads((out/'wet/result.json').read_text())
result=dict(status='NATIVE_ORDINARY481_AND_WET_ATOMICITY_PRESERVED',ordinary_days=481,ordinary_bytes_exact={n:(out/'ordinary'/n).read_bytes()==(a.prior/'full'/n).read_bytes()for n in ['state.csv','endpoint.csv','restart.bin','budget.csv']},physical_comparison=compare,wet=wet,events=events)
(out/'result.json').write_text(json.dumps(result,indent=2)+'\n');print(result['status'])
