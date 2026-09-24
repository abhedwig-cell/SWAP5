#!/usr/bin/env python3
from __future__ import annotations
import hashlib, importlib.util, json, urllib.request
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
URL="https://raw.githubusercontent.com/SWAP-model/SWAP/68b6d8d4e53af2586d009d77245543e908ecdac5/src/soil/WC_K_models_04_11.f90"
B0="1f956cae894e83e208630e234c9b2017c945b2c522daf8277e89541f598ae4fd"
B16="f728e832645ab8273e41d0d285910240565148671989de24882740e7244f15b7"
B17="7ca607b2bbf97e166a32ab8a529fc7f32af9949afb1e6eb518ddbf84e6f0169e"
B111="d6038f1c2e0f4d061738bb2a176398cd89b7da59310394a2c4049fd0b4214126"
MANIFEST_SHA="24ce2768b3804ca1744457e8a7adcf101e37a4c1390049df23179e09816957e2"

def sha(x:bytes): return hashlib.sha256(x).hexdigest()
def gate(name, got, expected):
    if got != expected: raise SystemExit(f"{name} mismatch: expected {expected}, got {got}")

raw=urllib.request.urlopen(URL).read()
gate("B0 raw target",sha(raw),B0)

old9=b"Kvap = Kvap_func (WC, dabs(h), Temp) * Conv"
new9=b"Kvap = Kvap_func (WC, h, Temp) * Conv"
if raw.count(old9)!=4: raise SystemExit("SWAP-009 target count mismatch")
b16=raw.replace(old9,new9)
gate("B1.6",sha(b16),B16)

old10=(b"   Gam01 = Gamma1 (dabs(h0))\r\n"
       b"   Gam02 = Gamma2 (dabs(h0))\r\n"
       b"   C_MvG_2_s = (WCs-WCr)*(Omega1*C1(h)/(1.0d0-Gam01) + Omega2*C2(h)/(1.0d0-Gam02))\r\n")
new10=(b"   Gam01 = Omega1*Gamma1 (dabs(h0))\r\n"
       b"   Gam02 = Omega2*Gamma2 (dabs(h0))\r\n"
       b"   C_MvG_2_s = (WCs-WCr)*(Omega1*C1(h) + Omega2*C2(h))/(1.0d0-Gam01-Gam02)\r\n")
if b16.count(old10)!=1: raise SystemExit("SWAP-010 target count mismatch")
b17=b16.replace(old10,new10,1)
gate("B1.7/B1.10",sha(b17),B17)

helper_path=ROOT/"reference/swap-4.3.1/patches/SWAP-011/apply_and_verify.py"
spec=importlib.util.spec_from_file_location("swap011",helper_path)
mod=importlib.util.module_from_spec(spec); spec.loader.exec_module(mod)
patch=(ROOT/"reference/swap-4.3.1/patches/SWAP-011/fix.patch").read_bytes()
parsed=mod.parse_patch(patch)
b111=mod.apply_file(b17,parsed["WC_K_models_04_11.f90"])
gate("B1.11",sha(b111),B111)

decl=b"real(8)                :: fKvap, Da, MgRT, Rho_sv\r\n"
mg=b"MgRT      = MgR/(Temp+273.15d0)\r\n"
da=b"Da        = 2.14d-5*((Temp+273.15d0)/273.15d0)**2                                ! diffusivity of water vapor in air; m2/s\r\n"
rho=b"Rho_sv    = 1.0d-3*dexp(31.3716d0 - 6014.79d0/Temp - 7.92495d-3*Temp)/Temp       ! saturated vapor density; kg/m3\r\n"
for label,needle in [("declaration",decl),("MgRT",mg),("Da",da),("Rho_sv",rho)]:
    if b111.count(needle)!=1: raise SystemExit(f"temperature repair {label} count != 1")
fixed=b111.replace(decl,b"real(8)                :: fKvap, Da, MgRT, Rho_sv, TK\r\n",1)
fixed=fixed.replace(mg,b"TK        = Temp + 273.15d0\r\nMgRT      = MgR/TK\r\n",1)
fixed=fixed.replace(da,b"Da        = 2.14d-5*(TK/273.15d0)**2                                ! diffusivity of water vapor in air; m2/s\r\n",1)
fixed=fixed.replace(rho,b"Rho_sv    = 1.0d-3*dexp(31.3716d0 - 6014.79d0/TK - 7.92495d-3*TK)/TK       ! saturated vapor density; kg/m3\r\n",1)
post=sha(fixed)

manifest_path=ROOT/"docs/performance/evidence/F-PE19_B1_11_source_manifest.sha256"
manifest=manifest_path.read_bytes()
gate("stored exact B1.11 manifest",sha(manifest),MANIFEST_SHA)
oldline=f"{B111}  {len(b111):8d}  SWAP/WC_K_models_04_11.f90\n".encode()
if manifest.count(oldline)!=1: raise SystemExit("B1.11 manifest target entry mismatch")
newline=f"{post}  {len(fixed):8d}  SWAP/WC_K_models_04_11.f90\n".encode()
newmanifest=manifest.replace(oldline,newline,1)
result={
 "schema_version":1,"work_unit":"F-PDI-VT05","status":"PASS",
 "source_authority":{
   "raw_host_url":URL,"B0_sha256":sha(raw),"B1_6_sha256":sha(b16),
   "B1_7_through_B1_10_sha256":sha(b17),"B1_11_preimage_sha256":sha(b111),
   "B1_11_preimage_bytes":len(b111)},
 "repair":{
   "postimage_sha256":post,"postimage_bytes":len(fixed),
   "changed_target":"SWAP/WC_K_models_04_11.f90",
   "signed_head_preserved": b"Kvap_func (WC, h, Temp)" in fixed and b"Kvap_func (WC, dabs(h), Temp)" not in fixed,
   "SWAP_011_derivative_TK_logic_preserved": b"tk=Temp+273.15d0;MgRT=MgR/tk" in fixed},
 "source_manifest":{
   "preimage_sha256":sha(manifest),"postimage_sha256":sha(newmanifest),
   "member_count":len(newmanifest.splitlines())},
 "historical_classification":{
   "bug_present_in_B0":True,"bug_present_after_SWAP_009":True,"bug_present_after_SWAP_010":True,
   "bug_present_after_SWAP_011_B1_11":True}
}
Path("/tmp/F-PDI-VT05_RESULT.json").write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
Path("/tmp/F-PDI-VT05_B1_11_FIXED_SOURCE_MANIFEST.sha256").write_bytes(newmanifest)
print(json.dumps(result,indent=2,sort_keys=True))
