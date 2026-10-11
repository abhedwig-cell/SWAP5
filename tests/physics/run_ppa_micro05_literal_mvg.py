#!/usr/bin/env python3
"""Compare corrected literal B1.11 MvG MICRO tables to the typed first-node binding."""
import hashlib
import json
import os
import pathlib
import subprocess
import tempfile

ROOT=pathlib.Path(__file__).resolve().parents[2]
MVG="reference/swap-4.3.1/b1_11_frost_source/SWAP/MOD_MvG_functions.f90"
RWU="reference/swap-4.3.1/b1_11_frost_source/SWAP/RWU_micro.f90"
assert hashlib.sha256((ROOT/MVG).read_bytes()).hexdigest()=="6b65637866476581b283eb3d61c3aa0dfe4b51f84223f6eea571ac25ecac1104"
assert hashlib.sha256((ROOT/RWU).read_bytes()).hexdigest()=="cac3d723cc11fb001878d53f2747bbff9fd53fb22949b682906df4361cb90477"
source=(ROOT/RWU).read_bytes().decode().replace("\r\n","\n")
patches=[
    ("public :: do_RWU_micro, read_rwu_micro_input, PP, PL, UpwPot, swAlpTot, M_table, K_table",
     "public :: do_RWU_micro, RWU_micro, get_MFLP_K, read_rwu_micro_input, PP, PL, UpwPot, swAlpTot, M_table, K_table"),
    ("      start = int(100.d0*dlog10(-wiltpoint))",
     "      M_table=0d0; K_table=0d0\n      start = int(100.d0*dlog10(-wiltpoint))"),
    ("         M_table(start,lay) = 0.0d0",
     """         K_table(start,lay)=conduc1
         wcontent=watcon(i,wiltpoint)
         conduc2=hconduc(i,wiltpoint,wcontent,10d0)
         K_table(start+1,lay)=conduc2
         M_table(start,lay)=0.5d0*(conduc1+conduc2)*(phead1-wiltpoint)"""),
    ("      else if (H > -1.023293d0) then",
     """      else if (H <= -10d0**(dble(int(100d0*dlog10(-wiltpoint)))/100d0)) then
         start=int(100d0*dlog10(-wiltpoint))
         phead1=-10d0**(dble(start)/100d0)
         c0=H-wiltpoint
         c1=c0/(phead1-wiltpoint)
         M=K_table(start+1,lay)*c0+0.5d0*(K_table(start,lay)-K_table(start+1,lay))*c0*c1
         if(Kpresent)K=K_table(start+1,lay)+(K_table(start,lay)-K_table(start+1,lay))*c1
      else if (H > -1.023293d0) then"""),
]
for old,new in patches:
    assert source.count(old)==1,old
    source=source.replace(old,new)
paths=["tests/physics/micro05_literal_mvg_stubs.f90",MVG,
       "src/solver/mod_soil_water_solver_contract.f90",
       "src/solver/mod_b110_default_mvg_provider.f90",
       "src/process/mod_root_micro_matric_flux_table.f90",
       "src/runtime/mod_fmr_micro_mvg_table_binding.f90",
       "src/process/mod_root_micro_de_willigen_process.f90",
       "tests/physics/test_ppa_micro05_literal_mvg.f90"]
outputs={}
with tempfile.TemporaryDirectory(prefix="ppa-micro05-") as tmp:
    tmp=pathlib.Path(tmp)
    literal=tmp/"corrected_rwu.f90"
    literal.write_text(source)
    for opt in ("O0","O2"):
        build=tmp/opt
        build.mkdir()
        flags=["-"+opt,"-ffree-line-length-none","-fcheck=all", "-ffpe-trap=invalid,zero,overflow",
               "-ffunction-sections","-J"+str(build),"-I"+str(build)]
        objects=[]
        for path in [paths[0],paths[1],str(literal.relative_to(ROOT)) if literal.is_relative_to(ROOT) else literal,
                     *paths[2:]]:
            file=ROOT/path if isinstance(path,str) else path
            obj=build/(file.stem+".o")
            subprocess.run(["gfortran",*flags,"-c",str(file),"-o",str(obj)],cwd=build,check=True)
            objects.append(str(obj))
        exe=build/"test"
        subprocess.run(["gfortran","-Wl,--gc-sections",*objects,"-o",str(exe)],check=True)
        outputs[opt]=subprocess.check_output([str(exe)],text=True,cwd=build)
        print(outputs[opt],end="",flush=True)
assert outputs["O0"]==outputs["O2"]
result=os.environ.get("MICRO05_RESULT")
if result:
    manifest=[*paths,"tests/physics/run_ppa_micro05_literal_mvg.py",RWU]
    pathlib.Path(result).write_text(json.dumps({
        "work_unit":"PPA-MICRO05", "status":"LOCAL_LITERAL_MVG_TABLE_O0_O2_PASS",
        "source_sha256":{p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in manifest},
        "corrected_rwu_sha256":hashlib.sha256(source.encode()).hexdigest(),
        "explicit_rwu_patches":patches,"outputs":outputs,
        "claim_ceiling":"Standard MvG (model 1), no power tail/KSATEXM/hysteresis, two representative horizons; no full production trajectory"
    },indent=2)+"\n")
print("MICRO05_LITERAL_MVG_O0_O2=PASS")
