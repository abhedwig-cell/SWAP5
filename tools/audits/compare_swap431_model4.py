#!/usr/bin/env python3
"""Bounded model-4/default-provider curve comparison, not a runtime admission."""
import argparse, base64, gzip, hashlib, io, json, os, subprocess, tarfile, tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
STUBS='module MOD_arrays\ninteger,parameter :: maho=1,macp=1\nend module\nmodule MOD_grid\ninteger :: layer(1)=1\nend module\nsubroutine swap_error(where,message)\ncharacter(*) :: where,message\nprint *,where,message\nerror stop\nend subroutine\n'
DRIVER="program probe\nuse WC_K_models_04_11\nuse mod_b110_default_mvg_provider\nimplicit none\ntype(b110_default_mvg_parameters_t),target :: p\ntype(b110_default_mvg_provider_t) :: v\nreal(8) :: cof(42,1),h(1),w(1),k(1),c(1),dk(1),ref(3),err(3),worst(3)\ninteger :: i,j,model(1),ncase\ncof=0;model=4;bimodal=.false.;novap=.true.;worst=0;ncase=0\ncof(1,1)=.04d0;cof(2,1)=.45d0;cof(3,1)=10d0;cof(5,1)=.5d0\ndo i=1,4\n cof(4,1)=.005d0*i;cof(6,1)=1.3d0+.2d0*i;cof(7,1)=1d0-1d0/cof(6,1)\n call initialize_b110_default_mvg_parameters(p,cof)\n call bind_b110_default_mvg_provider(v,p,1d-3)\n do j=1,6\n  h=-10d0**j\n  call v%evaluate(h,w,k,c,dk)\n  ref(1)=functionvalue_04_11(1,1,model,cof,h(1))\n  ref(2)=functionvalue_04_11(2,1,model,cof,h(1))\n  ref(3)=functionvalue_04_11(3,1,model,cof,h(1))\n  err=abs([w(1),k(1),c(1)]-ref)/max(abs(ref),1d-20)\n  worst=max(worst,err);ncase=ncase+1\n enddo\nenddo\nprint *,ncase,worst\nif(any(worst>1d-8)) error stop 'curve mismatch'\nend program\n"

def run(record):
    bundle=ROOT/'integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64'
    with tarfile.open(fileobj=io.BytesIO(gzip.decompress(base64.b64decode(bundle.read_bytes())))) as t:
        source=t.extractfile('SWAP/WC_K_models_04_11.f90').read()
    results=[]
    with tempfile.TemporaryDirectory(prefix='swap431-hyd4-') as tmp:
        wd=Path(tmp);(wd/'stubs.f90').write_text(STUBS);(wd/'driver.f90').write_text(DRIVER)
        (wd/'authority.f90').write_bytes(source)
        for opt in ['-O0','-O2']:
            subprocess.run([os.environ.get('FC','gfortran'),opt,'-ffree-line-length-none','stubs.f90','authority.f90',str(ROOT/'src/solver/mod_soil_water_solver_contract.f90'),str(ROOT/'src/solver/mod_b110_default_mvg_provider.f90'),'driver.f90','-o','probe'],cwd=wd,check=True,capture_output=True)
            out=subprocess.run(['./probe'],cwd=wd,check=True,capture_output=True,text=True).stdout.split()
            results.append({'optimization':opt,'cases':int(out[0]),'max_relative_errors_theta_K_C':[float(v) for v in out[1:]]})
    evidence={'schema':'swap5.coverage.model4_curve_review.v1','baseline':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'source_sha256':hashlib.sha256(source).hexdigest(),'provider_sha256':hashlib.sha256((ROOT/'src/solver/mod_b110_default_mvg_provider.f90').read_bytes()).hexdigest(),'status':'PASS_BOUNDED_CURVE_COMPARISON','cases_per_optimization':24,'domain':{'pressure_head_cm':[-10,-100,-1000,-10000,-100000,-1000000],'alpha_per_cm':[0.005,0.01,0.015,0.02],'n':[1.5,1.7,1.9,2.1],'m':'1-1/n','residual_theta':0.04,'saturated_theta':0.45,'ksat_cm_day':10,'lambda':0.5,'entry_head':0},'excluded':['Near-saturation numerical capacity/conductivity regularization','Nonzero entry head','Finite dry-end normalization models 5/7/9/11','Bimodal models','PDI adsorption/film/vapour','dK/dh admission','All soil parameter combinations and full-column trajectory equality'],'results':results,'runtime_admission_created':False}
    if record:Path(record).write_text(json.dumps(evidence,indent=2)+'\n')
    print(json.dumps(evidence,indent=2))
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--record');run(p.parse_args().record)
