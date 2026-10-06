#!/usr/bin/env python3
"""Bounded corrected-reference qualification using full original process bodies."""
from pathlib import Path
import json,gzip,subprocess,hashlib,tempfile,argparse,sys,math
sys.dont_write_bytecode=True
from run_ppa_wu05b16_divdra_owner import distribute,integral
ROOT=Path(__file__).resolve().parents[2]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
    ap=argparse.ArgumentParser();ap.add_argument('--record',required=True);a=ap.parse_args();build=Path(tempfile.mkdtemp(prefix='ppa-wu05b17-ref-'))
    p=json.loads((ROOT/'integration/audits/PPA_WU05B17_REF_PREREGISTRATION.json').read_text());f=ROOT/'reference/swap-4.3.1/frost-corrections/FROST-DIVDRA-02';m=json.loads((f/'manifest.json').read_text());source=ROOT/p['immutable_original']['path']
    evidence=ROOT/p['defect_evidence']['path'];assert sha(evidence)==p['defect_evidence']['sha256'];e=json.loads(gzip.decompress(evidence.read_bytes()));inputs=e['manifest']['actual/cases.txt']['content'];assert hashlib.sha256(inputs.encode()).hexdigest()==p['input_sha256'];(build/'cases.txt').write_text(inputs)
    subprocess.run([sys.executable,str(f/'apply.py'),str(source),str(build/'corrected.f90')],check=True);assert (build/'corrected.f90').read_bytes()==(f/'divdra.f90').read_bytes()
    invalid=build/'invalid.f90';invalid.write_bytes(source.read_bytes()+b'! invalid');occupied=build/'occupied.f90';occupied.write_bytes(b'occupied')
    for src,out in [(invalid,build/'should-not-exist.f90'),(source,source),(source,occupied)]:
        r=subprocess.run([sys.executable,str(f/'apply.py'),str(src),str(out)],capture_output=True,text=True);assert r.returncode!=0;(build/('guard-'+str(len(list(build.glob('guard-*'))))+'.log')).write_text(r.stdout+r.stderr)
    assert sha(source)==p['immutable_original']['sha256'] and occupied.read_bytes()==b'occupied' and not(build/'should-not-exist.f90').exists()
    for variant,divdra in [('original',source),('corrected',build/'corrected.f90')]:
        for opt in (0,2):
            d=build/variant/f'o{opt}';d.mkdir(parents=True)
            files=[ROOT/'tests/frost/test_ppa_wu05b16_divdra_globals.f90',divdra,ROOT/'reference/swap-4.3.1/b1_11_frost_source/SWAP/frozencond.f90',ROOT/'tests/frost/test_ppa_wu05b16_divdra_owner.f90']
            cmd=['gfortran','-std=f2008','-ffree-line-length-none','-fcheck=all','-ffpe-trap=invalid,zero,overflow',f'-O{opt}','-J',str(d),'-I',str(d),*[str(x)for x in files],'-o',str(d/'test')];subprocess.run(cmd,check=True,cwd=d)
            with(d/'output.txt').open('w')as out:subprocess.run([str(d/'test')],input=inputs,text=True,stdout=out,check=True,cwd=d)
            print(f'B17_{variant.upper()}_FULL_SOURCE_O{opt}=PASS',flush=True)
        assert (build/variant/'o0/output.txt').read_bytes()==(build/variant/'o2/output.txt').read_bytes()
    assert (build/'original/o0/output.txt').read_text()==e['manifest']['actual/o0/output.txt']['content']
    original=(build/'original/o0/output.txt').read_text().splitlines();corrected=(build/'corrected/o0/output.txt').read_text().splitlines();cases=inputs.splitlines();assert len(cases)==len(original)==len(corrected)==4536
    changed=0;unchanged=0;max_error=0.;max_closure=0.;max_original_residual=0.;max_expected_difference=0.;initial_tiny=0
    for text,orig,corr in zip(cases,original,corrected):
        id,inf,gw,frost,air,raw,qbot,spacing,aniso=map(float,text.split());v=list(map(float,corr.split()));assert v[0]==id
        before=v[2:10];level=v[10];after=v[11:19];bottom=v[19];k=[1.,4.]*4
        expected_before=distribute(raw,k,gw,spacing,aniso,inf,False)
        frozen=[i for i in range(8)if -(i+.5)>=frost];rf=[0. if i in frozen else 1. for i in range(8)];rf[len(frozen)]=.5
        affected=False
        if air<.01:
            blocked=frost < -3.;expected_level=0. if blocked else raw;expected_bottom=0. if blocked else qbot
            if abs(expected_level)<1e-6:expected_level=0. if blocked else qbot
            else:expected_level*=1.+qbot/expected_level
            modified=[x*r+(1.-r)*1e-10 for x,r in zip(k,rf)];gw_final=min(gw,frost)
            expected_after=distribute(expected_level,modified,gw_final,spacing,aniso,inf,False)
            uns=integral([x*aniso for x in modified],1.,-gw_final)
            affected=inf==1 and expected_level < -1e-10 and 0.<uns<=1e-8
        else:
            expected_after=[x*r for x,r in zip(expected_before,rf)];expected_level=sum(expected_after);expected_bottom=qbot
        assert abs(level-expected_level)<1e-14 and bottom==expected_bottom
        error=max(abs(a-b)for a,b in zip(before+after,expected_before+expected_after));max_error=max(max_error,error);assert error<1e-14,(id,error)
        closure=abs(sum(after)-level);max_closure=max(max_closure,closure);assert closure<1e-14,(id,closure)
        ov=list(map(float,orig.split()));max_original_residual=max(max_original_residual,abs(sum(ov[11:19])-ov[10]))
        if affected:
            assert orig!=corr;changed+=1
            max_expected_difference=max(max_expected_difference,max(abs(a-b)for a,b in zip(ov[11:19],v[11:19])))
            assert ov[:11]==v[:11] and ov[19]==v[19]  # scalar, bottom and initial partition unchanged
        else:
            assert orig==corr,(id,'unchanged-domain difference');unchanged+=1
        if 0.<abs(raw)<=1e-10:assert before==[0.]*8;initial_tiny+=1
    paths=[source,ROOT/'reference/swap-4.3.1/b1_11_frost_source/SWAP/frozencond.f90',f/'divdra.f90',f/'manifest.json',f/'apply.py',f/'correction.patch',ROOT/'tests/frost/test_ppa_wu05b16_divdra_globals.f90',ROOT/'tests/frost/test_ppa_wu05b16_divdra_owner.f90',ROOT/'tests/frost/run_ppa_wu05b16_divdra_owner.py',Path(__file__)]
    result=dict(work_unit='PPA-WU05B17',status='LOCAL_BOUNDED_CORRECTED_REFERENCE_PASS_NOT_ADMITTED',baseline=p['baseline'],production_source=p['baseline_source'],cases_per_variant_optimization=4536,complete_case_executions=18144,changed_cases=changed,byte_exact_unchanged_cases=unchanged,initial_tiny_scalar_domain_retained=initial_tiny,original_B16_output_identity=True,original_and_corrected_O0_O2_identity=True,max_independent_conservative_partition_error=max_error,max_corrected_nodal_scalar_residual=max_closure,max_original_residual=max_original_residual,max_expected_nodal_difference=max_expected_difference,hash_guard_and_overwrite_negatives=True,source_sha256={str(x.relative_to(ROOT)):sha(x)for x in paths},input_sha256=sha(build/'cases.txt'),build=str(build),executables={f'{var}/o{o}':sha(build/var/f'o{o}/test')for var in ('original','corrected')for o in(0,2)},outputs={f'{var}/o{o}':sha(build/var/f'o{o}/output.txt')for var in ('original','corrected')for o in(0,2)},scope=p['qualification_scope'],global_B1_snapshot_promoted=False,runtime_admitted=False)
    Path(a.record).write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
if __name__=='__main__':main()
