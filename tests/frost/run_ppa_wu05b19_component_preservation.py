#!/usr/bin/env python3
"""B19 preservation of full B18 science with a proven additive validator-only wrapper."""
from pathlib import Path
import argparse,subprocess,tempfile,json,gzip,hashlib
ROOT=Path(__file__).resolve().parents[2]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
    ap=argparse.ArgumentParser();ap.add_argument('--record',required=True);a=ap.parse_args();build=Path(tempfile.mkdtemp(prefix='ppa-wu05b18-component-'))
    p=json.loads((ROOT/'integration/audits/PPA_WU05B18_PREREGISTRATION.json').read_text());refstatus=json.loads((ROOT/'integration/audits/PPA_WU05B17_REF_STATUS.json').read_text());assert refstatus['admitted']and refstatus['qualified']
    body='src/process/mod_frost_divdra_drainage_effect.f90'
    original=subprocess.check_output(['git','show','ca856e88e582d468a6f40971ce1f2a75e5089c40:'+body],cwd=ROOT).decode()
    current=(ROOT/body).read_text()
    addition="""  pure logical function frost_divdra_parameters_valid(p) result(ok)
    type(frost_divdra_parameters_t),intent(in)::p
    ok=valid_parameters(p)
  end function
"""
    assert current.count(addition)==1
    assert current.replace(addition,'').replace('public :: compose_single_level_signed_frost_divdra, frost_divdra_parameters_valid','public :: compose_single_level_signed_frost_divdra')==original
    for f,h in p['source_sha256'].items():
        if f!=body:assert sha(ROOT/f)==h,f
    path=ROOT/refstatus['evidence']['path'];assert sha(path)==refstatus['evidence']['sha256'];record=json.loads(gzip.decompress(path.read_bytes()));inputs=record['manifest']['actual/cases.txt']['content'];(build/'cases.txt').write_text(inputs)
    common=['src/solver/mod_soil_water_solver_contract.f90','src/solver/mod_process_hydraulic_view.f90','src/process/mod_drainage_spatial_distribution.f90','src/process/mod_frost_divdra_drainage_effect.f90']
    reference=['tests/frost/test_ppa_wu05b16_divdra_globals.f90','reference/swap-4.3.1/frost-corrections/FROST-DIVDRA-02/divdra.f90','reference/swap-4.3.1/b1_11_frost_source/SWAP/frozencond.f90','tests/frost/test_ppa_wu05b16_divdra_owner.f90']
    allfiles=list(dict.fromkeys(common+reference+['tests/frost/test_ppa_wu05b18_divdra_component.f90']))
    for variant,files in [('reference',reference),('typed',common+reference[:-1]+['tests/frost/test_ppa_wu05b18_divdra_component.f90'])]:
        for opt in (0,2):
            d=build/variant/f'o{opt}';d.mkdir(parents=True)
            cmd=['gfortran','-std=f2008','-ffree-line-length-none','-fcheck=all','-ffpe-trap=invalid,zero,overflow',f'-O{opt}','-J',str(d),'-I',str(d),*[str(ROOT/f)for f in files],'-o',str(d/'test')];subprocess.run(cmd,check=True,cwd=d)
            with(d/'output.txt').open('w')as out:subprocess.run([str(d/'test')],input=inputs,text=True,stdout=out,check=True,cwd=d)
            print(f'B18_{variant.upper()}_O{opt}_FULL_EXECUTION=PASS',flush=True)
        assert (build/variant/'o0/output.txt').read_bytes()==(build/variant/'o2/output.txt').read_bytes()
    assert (build/'reference/o0/output.txt').read_text()==record['manifest']['actual/corrected/o0/output.txt']['content']
    reference_rows=(build/'reference/o0/output.txt').read_text().splitlines();typed_rows=(build/'typed/o0/output.txt').read_text().splitlines();assert typed_rows[-2:]==['B18_INVALID_DOMAIN_UNAVAILABLE_CASES=32','B18_ACTUAL_REFERENCE_BOUNDARY_AND_BEYOND_OFFSET_CASES=2'];typed_rows=typed_rows[:-2]
    assert len(reference_rows)==len(typed_rows)==4536
    accepted=0;held=0;max_nodes=0.;max_scalar=0.;max_closure=0.;max_correction=0.
    for inp,ref,line in zip(inputs.splitlines(),reference_rows,typed_rows):
        case=list(map(float,inp.split()));r=list(map(float,ref.split()));t=list(map(float,line.split()));assert case[0]==r[0]==t[0]
        raw=case[5]
        if 0.<abs(raw)<=1e-10:
            assert t[1]==2 and t[2]==0 and t[3:13]==[0.]*10;held+=1;continue
        assert t[1]==0 and t[2]==1,(case,t)
        accepted+=1;node_error=max(abs(x-y)for x,y in zip(t[4:12],r[11:19]));scalar_error=abs(t[3]-r[10]);assert t[12]==r[19]
        assert node_error<1e-14 and scalar_error<1e-14,(case,node_error,scalar_error)
        max_nodes=max(max_nodes,node_error);max_scalar=max(max_scalar,scalar_error);max_closure=max(max_closure,abs(sum(t[4:12])-t[3]));max_correction=max(max_correction,abs(t[13]),abs(t[14]))
    assert accepted==3240 and held==1296 and max_closure<1e-14 and max_correction<1e-14
    result=dict(work_unit='PPA-WU05B19',status='LOCAL_COMPLETE_B18_SCIENCE_PRESERVATION_PASS_NOT_RUNTIME_ADMISSION',baseline=p['baseline'],baseline_source=p['baseline_source'],cases=4536,accepted_component_cases=accepted,unavailable_original_tiny_scalar_cases=held,invalid_domain_cases=32,actual_reference_boundary_cases=2,typed_O0_O2_byte_identity=True,reference_O0_O2_byte_identity=True,actual_B17_corrected_reference_output_identity=True,max_actual_corrected_nodal_error=max_nodes,max_actual_corrected_scalar_error=max_scalar,max_typed_nodal_scalar_residual=max_closure,max_diagnosed_partition_correction=max_correction,source_sha256={f:sha(ROOT/f)for f in allfiles+[str(Path(__file__).relative_to(ROOT))]},build=str(build),input_sha256=sha(build/'cases.txt'),executables={f'{v}/o{o}':sha(build/v/f'o{o}/test')for v in('reference','typed')for o in(0,2)},outputs={f'{v}/o{o}':sha(build/v/f'o{o}/output.txt')for v in('reference','typed')for o in(0,2)},qualification_scope=p['qualification_scope'],runtime_admitted=False)
    Path(a.record).write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
if __name__=='__main__':main()
