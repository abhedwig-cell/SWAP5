"""Paired original scheduled source using qualified immutable reference executables."""
import argparse,csv,hashlib,importlib.util,json,math,shutil,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location("s",ROOT/"tests/nomacro_scheduled_subsurface/run.py");s=importlib.util.module_from_spec(spec);spec.loader.exec_module(s)
parser=argparse.ArgumentParser()
parser.add_argument("--reference-evidence",type=Path,required=True)
parser.add_argument("--output",type=Path,required=True)
a=parser.parse_args();reference=a.reference_evidence.resolve();out=a.output.resolve();out.mkdir()
prior=json.loads((reference/"RESULT.json").read_text())
result=dict(status="RUNNING",source_commit=subprocess.check_output(["git","rev-parse","HEAD"],cwd=ROOT,text=True).strip(),profiles={},SWAP5_scheduled_chemical_activation=False,whole_scientific_equivalence="NOT_QUALIFIED")
def save():(out/"RESULT.json").write_text(json.dumps(result,indent=2)+"\n")
def rows(case):return list(csv.DictReader([v for v in (case/"result_output.csv").read_text().splitlines() if v.strip() and not v.startswith("*")]))
try:
 for opt in ("O0","O2"):
  for version in ("original","corrected"):
   key=version+"-"+opt;exe=(reference/key/"swap_reference.exe").resolve();assert hashlib.sha256(exe.read_bytes()).hexdigest()==prior["profiles"][key]["executable_sha256"]
   result["profiles"][key]={}
   for kind in ("point","interval"):
    for concentration in (0,20):
     name=kind+"-"+str(concentration);case=out/(key+"-"+name)
     s.fixture(case,kind)
     path=case/"swap.swp";body=path.read_text(encoding="cp1252")
     body=s.assignment(body,"SWSOLU",1);body=s.assignment(body,"INLIST_CSV","'WATBAL,ETTERMS,SOLBAL,GWL'");path.write_text(body,encoding="cp1252")
     for crop in case.glob("*.crp"):crop.write_text(s.assignment(crop.read_text(encoding="cp1252"),"CIRRS",float(concentration)),encoding="cp1252")
     inventory={p.relative_to(case).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in case.rglob("*") if p.is_file()}
     start=time.perf_counter();r=subprocess.run([str(exe),"./swap.swp"],cwd=case,capture_output=True,timeout=30)
     (case/"reference.stdout").write_bytes(r.stdout);(case/"reference.stderr").write_bytes(r.stderr);assert (case/"swap.ok").exists(),(key,name,r.stderr)
     data=rows(case);assert len(data)==1097
     water=math.fsum(float(row["SSDI"]) for row in data);mass=math.fsum(float(row["S_IRRIG"]) for row in data);balance=max(abs(float(row["S_BALDEV"])) for row in data)
     result["profiles"][key][name]=dict(days=1096,seconds=time.perf_counter()-start,input_sha256=inventory,irrigation_water_cm=water,irrigation_mass_mg_cm2=mass,expected_actual_water_times_concentration_mg_cm2=water*concentration,mass_difference_mg_cm2=mass-water*concentration,max_printed_solute_residual_mg_cm2=balance)
     save();print(key,name,water,mass,balance,flush=True)
 for opt in ("O0","O2"):
  for kind in ("point","interval"):
   assert rows(out/("original-"+opt+"-"+kind+"-0"))==rows(out/("corrected-"+opt+"-"+kind+"-0"))
   old=result["profiles"]["original-"+opt][kind+"-20"];new=result["profiles"]["corrected-"+opt][kind+"-20"]
   assert old["irrigation_mass_mg_cm2"]==0
   assert new["irrigation_water_cm"]>0 and new["irrigation_mass_mg_cm2"]>0
   assert abs(new["mass_difference_mg_cm2"])<=1e-10,new
   assert new["max_printed_solute_residual_mg_cm2"]<=1e-10,new
 result["status"]="ORIGINAL_SCHEDULED_CHEMICAL_SOURCE_POINT_INTERVAL_O0_O2_REFERENCE_PASS"
except Exception as error:result.update(status="FAILED",error=repr(error));raise
finally:save()
