#!/usr/bin/env python3
"""Fail-closed exact B1.11 equation gate for MC-NUT01 / MC-SOL01."""
import base64, hashlib, io, re, subprocess, tarfile
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
BUNDLE=ROOT/"integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64"
EXPECTED={
 "SWAP/solute.f90":"2fc8592001cdcd2de95a252d8b9099416c94e4d2654c335908858a735f80e7a2",
 "SWAP/wofost_soil_rateconstants.f90":"0d869c9acbf290b731c2e7344a0a9df7413eba4da44dcd48d124da994f4adcc6",
 "SWAP/wofostnut.f90":"071e65763be9e771b32b417252584d50874715d9ff11d3482c131826cc80bbb2",
 "SWAP/wofost_soil_amendments.f90":"157caa9b6feafcd16f9505099874f0a8f56bc81618667d5acdafc17e40735df9",
 "SWAP/wofost_soil_cropresidues.f90":"1f5d61e97d4a5d1dae7be604f0ed67ce5a780471d7db35236dbb0dc27d1ff8e9",
 "SWAP/wofost_soil_watern.f90":"b343fa9e485e60d76e2bd49067a20cd5ec328264af5d99d7cf1e4ddf07278722",
 "SWAP/wofost_soil_orgmatn.f90":"85146e95249b41ed9b5202b507cb1647784592a313e36e75010da9bbf9a733f6",
}
with tarfile.open(fileobj=io.BytesIO(base64.b64decode(BUNDLE.read_bytes())),mode="r:gz") as a:
    members={name:a.extractfile(name).read() for name in EXPECTED}
for name,raw in members.items():
    got=hashlib.sha256(raw).hexdigest()
    if got!=EXPECTED[name]:
        raise SystemExit(f"{name} sha mismatch: {got}")

def packed(name):
    return "".join(members[name].decode("latin1").lower().split())

sol=packed("SWAP/solute.f90")
rate=packed("SWAP/wofost_soil_rateconstants.f90")
nut=packed("SWAP/wofostnut.f90")
amend=packed("SWAP/wofost_soil_amendments.f90")
residue=packed("SWAP/wofost_soil_cropresidues.f90")
watern=packed("SWAP/wofost_soil_watern.f90")
orgmat=packed("SWAP/wofost_soil_orgmatn.f90")

age_substep_needles=[
 "agesurf=(nird*ageirr+nraidt*agepre)*dtsolu+pondm1*agepondm1",
 "agepond=agesurf/(pond-qtop*dtsolu)",
 "agefluxb=(q(i+1)*agemlav+thetav*dispr*(ageml(i+1)-ageml(i))/disnod(i+1))*dtsolu",
 "agerot=qrot(i)*ageml(i)/dz(i)",
 "ageprod=1.0d0*0.5d0*(theta(i)+thetm1(i))",
 "agemsy(i)=agemsy(i)+(agefluxb-agefluxt)/dz(i)+(-agerot-agedrtot+ageprod)*dtsolu",
 "ageml(i)=agemsy(i)/theta(i)",
 "agepondm1=agepond",
]
for needle in age_substep_needles:
    if needle not in solute:
        raise SystemExit("missing exact AgeTracer substep equation: "+needle)

reactive_substep_needles=[
 "cfluxt=qtop*(1.0d0-armpss)*cpond*dtsolu",
 "ctrans=decact*theta(i)*cml(i)+decact*bdenskfcref(i)*((cml(i)/cref)**frexp)",
 "crot=tscf*qrot(i)*cml(i)/dz(i)",
 "cmsy(i)=cmsy(i)+(cfluxb-cfluxt)/dz(i)+(-ctrans-crot-cdrtot)*dtsolu",
 "cml(i)=cmsy(i)/(theta(i)+dummy)",
 "cfluxt=cfluxb",
]
for needle in reactive_substep_needles:
    if needle not in solute:
        raise SystemExit("missing exact reactive-solute substep equation: "+needle)

solute_needles=[
 "cmsy(i)=(theta(i)*cml(i)+bdenskfcref(i)*(cml(i)/cref)**frexp)",
 "cml(i)=cmsy(i)/(theta(i)+bdenskf(i))",
 "dummy=bdenskf(i)*(cml(i)/cref)**(frexp-1.0d0)",
 "cml(i)=cmsy(i)/(theta(i)+dummy)",
 "ftemp=exp(gampar*(tsoil(i)-20.0d0))",
 "ftemp=exp(gampar*15.0d0)",
 "ftemp=0.0d0",
 "ftheta=min(1.0d0,(theta(i)/rtheta)**bexp)",
 "decact=decpotfdepth(i)*ftemp*ftheta",
 "ctrans=decact*theta(i)*cml(i)+decact*bdenskfcref(i)*((cml(i)/cref)**frexp)",
 "csurf=(nird*cirr+nraidt*cpre)*dtsolu+csurf",
 "cpond=csurf/(pond-qtop*dtsolu)",
 "cfluxt=qtop*(1.0d0-armpSS)*cpond*dtsolu".lower(),
 "csurf=csurf+cfluxt",
 "ageprod=1.0d0*0.5d0*(theta(i)+thetm1(i))",
]
for needle in solute_needles:
    if needle not in sol:
        raise SystemExit("missing exact solute equation: "+needle)

rate_needles=[
 "r1=1.0d0/(1.0d0+exp(-0.26d0*(temp-17.0d0)))-1.0d0/(1.0d0+exp(-0.77d0*(temp-41.9d0)))",
 "r2=1.0d0/(1.0d0+exp(-0.26d0*(temp_ref-17.0d0)))-1.0d0/(1.0d0+exp(-0.77d0*(temp_ref-41.9d0)))",
 "wfps=0.5d0*(wfrac_t+wfrac_t0)/wfrac_sat",
 "red_w_nit=0.9d0/(1.0d0+exp(-15.0d0*(wfps-0.45d0)))+0.1d0-1.0d0/(1.0d0+exp(-50.0d0*(wfps-0.95d0)))",
 "red_w_den=(max(wfps-wfpscrit2,0.0d0)/(1.0d0-wfpscrit2))**2",
 "red_resp=cdissi/(cdissihalf+cdissi)",
]
for needle in rate_needles:
    if needle not in rate:
        raise SystemExit("missing exact Soil-N rate equation: "+needle)

nfix_needles=[
 "if(dvs.lt.dvsnlt.and.reltr.gt.0.01d0)then",
 "ndemandbiofix=nfixf*ndemto",
]
for needle in nfix_needles:
    if needle not in nut:
        raise SystemExit("missing exact N-fixation equation: "+needle)

crop_n_owner_needles=[
 "ndeml=max(nmaxlv*wlv-anlv,0.0d0)",
 "ndems=max(nmaxst*wst-anst,0.0d0)",
 "ndemr=max(nmaxrt*wrt-anrt,0.0d0)",
 "ndemso=max(nmaxso*wso-anso,0.0d0)/tcnt",
 "atnrt=max((atnlv+atnst)*fntrt,anrt-wrt*rnfrt)",
 "rnulv=(ndeml/ndemto)*(nuptr+nfixtr)",
 "rnust=(ndems/ndemto)*(nuptr+nfixtr)",
 "rnurt=(ndemr/ndemto)*(nuptr+nfixtr)",
 "rnldlv=rnflv*drlv",
 "rnldrt=rnfrt*drrt",
 "rnldst=rnfst*drst",
]
for needle in crop_n_owner_needles:
    if needle not in nut:
        raise SystemExit("missing exact B1.11 crop-N owner equation: "+needle)

addition_needles=[
 "am_nh4=nh4nfrac(matno)*(1.0d0-volafrac(im))*amend(im)",
 "am_no3=no3nfrac(matno)*amend(im)",
 "fdpm=exp(-0.59d0*(age-0.67d0))",
 "fhum=min(1.0d0,max(0.0d0,0.137d0*(age-2.5d0)))",
 "asfa=0.25d0/(1.0d0+exp(-2.7d0*(age-2.0d0)))+0.03d0",
]
for needle in addition_needles:
    if needle not in amend:
        raise SystemExit("missing exact amendment equation: "+needle)
amend_raw=members["SWAP/wofost_soil_amendments.f90"].decode("latin1").lower()
if not re.search(r"am_om\s*(?:>=|\.ge\.)\s*1(?:\.0+)?d-?6",amend_raw):
    raise SystemExit("missing exact amendment 1e-6 OM threshold")
residue_needles=[
 "am_nh4=xnh4nfrac*xamend",
 "am_no3=xno3nfrac*xamend",
 "fdpm=exp(-0.59d0*(age-0.67d0))",
]
for needle in residue_needles:
    if needle not in residue:
        raise SystemExit("missing exact residue equation: "+needle)
residue_raw=members["SWAP/wofost_soil_cropresidues.f90"].decode("latin1").lower()
if not re.search(r"am_om\s*(?:>=|\.ge\.)\s*1(?:\.0+)?d-?12",residue_raw):
    raise SystemExit("missing exact residue 1e-12 OM threshold")

watern_needles=[
 "wfrac_av=half*(wfrac_t+wfrac_t0)",
 "hv=(wfrac_t-wfrac_t0)/dt",
 "hv1=hv+wflux_out/dz+tcsf*wflux_transp/dz+ratecon*wfrac_av",
 "hv2=wflux_inbot*cseep/dz+wflux_intop*ctop/dz+wflux_inlat*clat/dz+producpot",
 "c_t=a1*c_t0+a2*hv2",
 "c_av=b1*c_t0+b2*hv2",
]
for needle in watern_needles:
    if needle not in watern:
        raise SystemExit("missing exact Soil-N transport equation: "+needle)

organic_turnover_needles=[
 "fom_t(fn)=fom_t0(fn)*exp(-rateconfom(fn)*dt)",
 "p1=(1.0d0-asfabio)*rateconbio",
 "p2=asfabio*rateconhum",
 "p3=asfahum*rateconbio",
 "p4=(1.0d0-asfahum)*rateconhum",
 "p5=dsqrt((p1-p4)**2+4*p2*p3)",
 "eval1=-(p1+p4+p5)/2.d0",
 "eval2=-(p1+p4-p5)/2.d0",
]
for needle in organic_turnover_needles:
    if needle not in orgmat:
        raise SystemExit("missing exact organic-turnover equation: "+needle)

organic_dissimilation_needles=[
 "rhs_bio=(bio_t-bio_t0)/dt-fom2bio/dt/dz_wsn",
 "rhs_hum=(hum_t-hum_t0)/dt-fom2hum/dt/dz_wsn",
 "bio_av=(p4*rhs_bio+p2*rhs_hum)/(p2*p3-p1*p4)",
 "hum_av=(p3*rhs_bio+p1*rhs_hum)/(p2*p3-p1*p4)",
 "cdissi=cdissi+cfracbio*dt*dz_wsn*(1.0d0-asfabio-asfahum)*rateconbio*bio_av",
 "cfrachelp_placeholder"
]
organic_dissimilation_needles.remove("cfrachelp_placeholder")
for needle in organic_dissimilation_needles:
    if needle not in orgmat:
        raise SystemExit("missing exact organic-dissimilation equation: "+needle)

# Fail closed on the B1.11 organic-N inconsistency. The earlier balance
# accumulator uses Bio + Hum incorporation, while the later Nminer expression
# subtracts the Bio incorporation term twice. This is evidence for a reference
# decision, not permission to guess which expression should own production.
orgmat_needles=[
 "nfom_min=nfom_min+(nfracfom(fn)-asfafom_bio(fn)*nfracbio-asfafom_hum(fn)*nfrachum)*help",
 "nminer=nminer+(nfracfom(fn)-asfafom_bio(fn)*nfracbio-asfafom_bio(fn)*nfracbio)*help",
]
for needle in orgmat_needles:
    if needle not in orgmat:
        raise SystemExit("organic-N source inconsistency witness missing: "+needle)

decision=(ROOT/"integration/audits/MC_NUT01_ORGANIC_SOURCE_DECISION.md").read_text().lower()
for needle in [
    "accepted_reference_correction",
    "nminer = (nfom_min + nbio_min + nhum_min) / dz_wsn",
]:
    if needle not in decision:
        raise SystemExit("organic-N reference-correction decision contract missing: "+needle)

subprocess.run(["bash",str(ROOT/"tests/physics/run_swap431_nut_sol_owner_components.sh")],cwd=ROOT,check=True)
subprocess.run(["bash",str(ROOT/"tests/fwof/pp02/run_b111_crop_n_fixation_policy.sh")],cwd=ROOT,check=True)
if (ROOT/"tests/physics/run_fmr_b111_soil_n_transaction.sh").exists():
    subprocess.run(["bash",str(ROOT/"tests/physics/run_fmr_b111_soil_n_transaction.sh")],cwd=ROOT,check=True)
if (ROOT/"tests/physics/run_fmr_b111_soil_n_daily_transaction.sh").exists():
    subprocess.run(["bash",str(ROOT/"tests/physics/run_fmr_b111_soil_n_daily_transaction.sh")],cwd=ROOT,check=True)
if (ROOT/"tests/physics/run_fmr_b111_soil_crop_n_transaction.sh").exists():
    subprocess.run(["bash",str(ROOT/"tests/physics/run_fmr_b111_soil_crop_n_transaction.sh")],cwd=ROOT,check=True)
if (ROOT/"tests/physics/run_fmr_b111_solute_transaction.sh").exists():
    subprocess.run(["bash",str(ROOT/"tests/physics/run_fmr_b111_solute_transaction.sh")],cwd=ROOT,check=True)
if (ROOT/"tests/physics/run_b111_reactive_solute_substep.sh").exists():
    subprocess.run(["bash",str(ROOT/"tests/physics/run_b111_reactive_solute_substep.sh")],cwd=ROOT,check=True)
if (ROOT/"tests/physics/run_b111_age_tracer_substep.sh").exists():
    subprocess.run(["bash",str(ROOT/"tests/physics/run_b111_age_tracer_substep.sh")],cwd=ROOT,check=True)
print("SWAP431_B111_NUT_SOL_EXACT_SOURCE_PASS")
