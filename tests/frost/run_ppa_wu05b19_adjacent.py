#!/usr/bin/env python3
"""Original root/salt and immutable drainage/external programs on fresh B19 modules."""
import argparse,gzip,hashlib,json,os,pathlib,subprocess
ROOT=pathlib.Path(__file__).resolve().parents[2]
a=argparse.ArgumentParser();a.add_argument('--build',type=pathlib.Path,required=True);args=a.parse_args()
def git(*s):return subprocess.check_output(['git',*s],cwd=ROOT)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
source=git('rev-parse','HEAD:src').decode().strip()
assert source==json.loads((ROOT/'integration/audits/PPA_WU05B19_PREREGISTRATION.json').read_text())['candidate_source']
assert not git('diff','--name-only','HEAD','--','src').strip()
evidence=json.loads(gzip.decompress((ROOT/'docs/audits/evidence/PPA_WU05B15_LOCAL_REPLAY.json.gz').read_bytes()))
b9=json.loads(gzip.decompress((ROOT/'docs/audits/evidence/PPA_WU05B9_LOCAL_REPLAY.json.gz').read_bytes()))
result={'work_unit':'PPA-WU05B19','production_source':source,'programs':{},'salt':{},'source_sha256':{}}
external=[('FAPP09','ba3699f970d48b6b15db24fac1d1ec619f7fcb32','tests/fapp/test_fapp09_ribasim_external_surface_water_profile.f90','FAPP09_RIBASIM_EXTERNAL_SURFACE_WATER_PROFILE=PASS'),('VQ128','181c785de059842a6361a1f57951a129ed78d8bb','tests/fvq/test_fvq128_fapp09_independent.f90','F_VQ128_FAPP09_INDEPENDENT=PASS')]
for opt in (0,2):
    b=args.build/f'o{opt}';out=b/'adjacent';out.mkdir(exist_ok=True)
    flags=['-std=f2008','-ffree-line-length-none','-w','-fopenmp','-fcheck=all','-fbacktrace','-ffpe-trap=invalid,zero,overflow',f'-O{opt}',f'-J{b}',f'-I{b}',f'-I{out}']
    objects=[str(p)for p in b.glob('*.o')if not p.name.startswith('test_')]
    support=[]
    for rel in ['tests/fmr/mod_fmr04_fixed_top_provider.f90','src/runtime/mod_fmr_surface_water_head_forcing_adapter.f90','src/runtime/mod_fmr_surface_water_swap_participant.f90']:
        obj=out/(pathlib.Path(rel).stem+'.o');subprocess.run(['gfortran',*flags,'-c',str(ROOT/rel),'-o',str(obj)],check=True);support.append(str(obj));result['source_sha256'][rel]=sha(ROOT/rel)
    objects+=support
    def compile_program(label,program):
        obj=out/(label+'.o');exe=out/label
        subprocess.run(['gfortran',*flags,'-c',str(program),'-o',str(obj)],check=True)
        subprocess.run(['gfortran','-fopenmp',f'-O{opt}',*objects,str(obj),'-o',str(exe)],check=True)
        result['source_sha256'][str(program)]=sha(program)
        return exe
    def run_program(label,exe,arguments,marker):
        so=out/(label+'.log');se=out/(label+'.err')
        # This scratch filesystem can clear an executable's mode between runs.
        # Restore only the owner execute bit of the program linked above.
        exe.chmod(exe.stat().st_mode | 0o100)
        with so.open('w')as stdout,se.open('w')as stderr:
            cp=subprocess.run([str(exe),*arguments],stdout=stdout,stderr=stderr,env={**os.environ,'GFORTRAN_UNBUFFERED_ALL':'y'})
        assert cp.returncode==0,(label,opt,so)
        assert marker in so.read_text(),(label,opt)
        result['programs'][f'{label}-O{opt}']={'exit_code':0,'source':source,'executable_sha256':sha(exe),'stdout_sha256':sha(so),'stderr_sha256':sha(se)}
        print(f'B19_ADJACENT_{label}_O{opt}=PASS',flush=True)
    for label in ('73','74'):
        frozen=b9['generated_and_immutable_oracles'][f'b9-vq{label}-oracle.f90']
        program=out/f'immutable-vq{label}.f90';program.write_text(frozen['source']);assert sha(program)==frozen['sha256']
        exe=compile_program('VQ'+label,program)
        run_program('VQ'+label,exe,[],'PASS')
        assert (out/f'VQ{label}.log').read_text()==evidence['logs'][f'frost-b15-current-vq{label}-o{opt}.log']
    for label,authority,rel,marker in external:
        program=out/f'immutable-{label}.f90';program.write_bytes(git('show',authority+':'+rel))
        assert sha(program)==evidence['external_preservation']['programs'][label]['program_sha256']
        exe=compile_program(label,program);run_program(label,exe,[],marker)
        assert (out/f'{label}.log').read_text()==evidence['logs'][f'frost-b15-external-{label.lower()}-o{opt}.log']
    fixture=ROOT/'tests/physics/test_ppa_wu05d2_mixed_application.f90';text=fixture.read_text()
    (out/'wu05e_mixed_fixture.inc').write_text(text[text.index('  subroutine add_root_thermal_oxygen'):text.rindex('end program')]);result['source_sha256'][str(fixture.relative_to(ROOT))]=sha(fixture)
    exe=compile_program('SALT_POLICY',ROOT/'tests/physics/test_fmr_base_salt_temporal_policy.f90')
    run_program('SALT_POLICY',exe,[],'PPA_WU05E_BASE_SALT_METRIC=PASS_TEST_ONLY')
    exe=compile_program('SALT_FROST',ROOT/'tests/physics/test_ppa_wu05e_mixed_salt_frost.f90')
    for method in ('jarvis','walsum'):
        for variant in ('','dispersion'):
            name=method+('-dispersion'if variant else '')
            restart=out/(name+'-restart.bin');expected=out/(name+'-expected.bin');resumed=out/(name+'-resumed.bin')
            run_program('SALT_'+name,exe,['write',str(restart),str(expected),variant,method],'PPA_SALFRO01_MATRIX_MIXED_STRESS_LIFECYCLE=PASS_TEST_ONLY')
            run_program('SALT_'+name+'_RESUME',exe,['resume',str(restart),str(resumed),variant,method],'PPA_WU05E_FRESH_PROCESS_RESTART=PASS_TEST_ONLY')
            assert expected.read_bytes()==resumed.read_bytes()
            result['salt'][f'{name}-O{opt}']=sha(resumed)
for label in ['VQ73','VQ74','FAPP09','VQ128','SALT_POLICY']:
    assert (args.build/'o0/adjacent'/f'{label}.log').read_bytes()==(args.build/'o2/adjacent'/f'{label}.log').read_bytes(),label
for method in ('jarvis','walsum'):
    for variant in ('','-dispersion'):
        assert result['salt'][method+variant+'-O0']==result['salt'][method+variant+'-O2']
(args.build/'b19-adjacent-receipt.json').write_text(json.dumps(result,indent=2)+'\n')
print('B19_ADJACENT_IMMUTABLE_ORACLES_AND_SALT_PHYSICAL_O0_O2_IDENTITY=PASS',flush=True)
