#!/usr/bin/env python3
"""Run incumbent F-WOF38/39 science with current compile closure and death assertions."""
import argparse,hashlib,json,os,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
a=argparse.ArgumentParser();a.add_argument('--output',required=True);args=a.parse_args()
out=Path(args.output).resolve();out.mkdir(parents=True,exist_ok=False)
p=ROOT/'tests/fwof/pp03/run_fwof38_fwof39_current_contract_preservation.sh'
s=p.read_text();old='ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"';assert s.count(old)==1
s=s.replace(old,'ROOT="${ANNUAL_ROOT:?}"',1)
# Canonical c2aae867 added only two optional-shadow compile providers to F38.
f38=ROOT/'tests/fwof/run_fwof38_atomic_crop_transaction_gate.sh'
current=f38.read_text()
old_f38=current
for line in ['  src/crop/mod_wofost_potential_shadow_state.f90\n','  src/crop/mod_wofost_potential_shadow_daily.f90\n']:
 assert old_f38.count(line)==1
 old_f38=old_f38.replace(line,'',1)
old_hash=subprocess.check_output(['git','hash-object','--stdin'],input=old_f38,text=True,cwd=ROOT).strip()
assert old_hash=='435ae756e326fc059a771f202eb3d9a144460257'
new_hash=subprocess.check_output(['git','hash-object',str(f38)],cwd=ROOT,text=True).strip()
s=s.replace('EXPECTED_FWO38='+old_hash,'EXPECTED_FWO38='+new_hash,1)
f39=ROOT/'tests/fwof/run_fwof39_crop_event_lifecycle_gate.sh'
f39text=f39.read_text().replace('EXPECTED_DONOR_BLOB='+old_hash,'EXPECTED_DONOR_BLOB='+new_hash,1)
f39copy=out/'f39_pin_compat.sh';f39copy.write_text(f39text)
new39=subprocess.check_output(['git','hash-object',str(f39copy)],cwd=ROOT,text=True).strip()
s=s.replace('FWO39=tests/fwof/run_fwof39_crop_event_lifecycle_gate.sh','FWO39='+str(f39copy),1)
s=s.replace('EXPECTED_FWO39=c85424228f65799757833f34272dba570c3ea5c0','EXPECTED_FWO39='+new39,1)
anchor="out_path.write_text(s, encoding='utf-8')"
insert='''# Complete only the declared current module build dependencies.
s = s.replace('for OPT in 0 2; do', 'mapfile -t SOURCES < <(python3 "$ROOT/tests/support/augment_bartholomeus_backend_sources.py" --all "${SOURCES[@]}")\\nfor OPT in 0 2; do', 1)
# Preserve every incumbent assertion, extending owner equality to new diagnostics.
needle = "      if (.not. bitwise_equal(left%biomass%root_biomass, right%biomass%root_biomass)) return"
extra = "\\n".join("      if (.not. bitwise_equal(left%biomass%cumulative_dead_"+organ+"_biomass, right%biomass%cumulative_dead_"+organ+"_biomass)) return" for organ in ['root','stem','leaf'])
read = "f33 = Path(sys.argv[1]).read_text(encoding='utf-8')"
assert s.count(read)==1
s=s.replace(read,read+"\\nf33 = f33.replace("+repr(needle)+","+repr(needle+'\\n'+extra)+",1)",1)
'''
assert s.count(anchor)==1;s=s.replace(anchor,insert+'\n'+anchor,1)
(out/'run_compat.sh').write_text(s)
env=os.environ.copy();env['ANNUAL_ROOT']=str(ROOT)
t=time.monotonic();r=subprocess.run(['bash',str(out/'run_compat.sh')],cwd=ROOT,env=env,capture_output=True,text=True)
(out/'stdout').write_text(r.stdout);(out/'stderr').write_text(r.stderr)
res={'exit':r.returncode,'seconds':time.monotonic()-t,'incumbent_wrapper_sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'stdout_sha256':hashlib.sha256(r.stdout.encode()).hexdigest(),'scope':'Original F-WOF38/F-WOF39 assertions retained; same_owner additionally compares cumulative mortality; build closure completed using existing dependency resolver. Real generic transaction accepted crop events, not actual Richards uptake qualification.'}
(out/'result.json').write_text(json.dumps(res,indent=2)+'\n');print(json.dumps(res))
raise SystemExit(r.returncode)
