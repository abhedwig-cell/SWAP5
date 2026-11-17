"""Real original CDE/reference executions using the shared production source.

Both original and corrected CDE objects are rebuilt at each optimization while
the validated original provider stays read-only. This is bounded source/ledger
qualification, never whole-model or active-macropore equivalence.
"""
import argparse
import csv
import hashlib
import importlib.util
import json
import math
from pathlib import Path
import subprocess
import sys
import time

ROOT=Path(__file__).resolve().parents[4]
sys.path[:0]=[str(ROOT/'app/hybrid_water'),str(ROOT/'tools/solute')]
import user_prepare
from fixed_irrigation_cases import create
spec=importlib.util.spec_from_file_location('ssdi_reference_source',Path(__file__).with_name('source.py'))
correction=importlib.util.module_from_spec(spec);spec.loader.exec_module(correction)
spec=importlib.util.spec_from_file_location('ssdi_inputs',ROOT/'tests/nomacro_scheduled_subsurface/run.py')
inputs=importlib.util.module_from_spec(spec);spec.loader.exec_module(inputs)


def rows(path):
    lines=[s for s in path.read_text(encoding='cp1252').splitlines() if s.strip() and not s.startswith('*')]
    return list(csv.DictReader(lines))


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--reference-work',type=Path,required=True);p.add_argument('--output',type=Path,required=True)
    p.add_argument('--resume',action='store_true');a=p.parse_args()
    out=a.output.resolve();out.mkdir(parents=True,exist_ok=a.resume);reference=a.reference_work.resolve();user_prepare.validate(reference)
    provider=reference/'build';objects=provider/'swap-obj';ttutil=provider/'ttutil-obj'
    original=(provider/'swap-selected/solute.f90').read_bytes();corrected=correction.source(original)
    original_irrigation=(provider/'swap-selected/irrigation.f90').read_bytes()
    corrected_irrigation=correction.irrigation_source(original_irrigation)
    helper=correction.helper_source();sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
    result=json.loads((out/'RESULT.json').read_text()) if a.resume else dict(status='RUNNING',
        source_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
        original_sha256=correction.ORIGINAL_SHA,corrected_sha256=hashlib.sha256(corrected).hexdigest(),
        original_irrigation_sha256=correction.IRRIGATION_SHA,corrected_irrigation_sha256=hashlib.sha256(corrected_irrigation).hexdigest(),
        helper_canonical_sha256=hashlib.sha256(helper).hexdigest(),profiles={},events=[],
        unchanged_original_objects={p.name:sha(p) for p in objects.glob('*.o') if p.name not in ('solute.o','irrigation.o')},
        original_ttutil_sha256=sha(ttutil/'libttutil.a'),whole_scientific_equivalence='NOT_QUALIFIED',
        b1_promotion=False,chemical_subsurface_SW5_activation=False)
    def save(): (out/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n')
    save()
    def call(command,directory,label,cap):
        start=time.perf_counter();r=subprocess.run(list(map(str,command)),cwd=directory,capture_output=True,timeout=cap)
        (directory/(label+'.stdout')).write_bytes(r.stdout);(directory/(label+'.stderr')).write_bytes(r.stderr)
        result['events'].append(dict(command=list(map(str,command)),cwd=str(directory),returncode=r.returncode,seconds=time.perf_counter()-start));save()
        return r
    try:
        for opt in ('O0','O2'):
            for version,source in (('original',original),('corrected',corrected)):
                name=version+'-'+opt;record=result['profiles'].setdefault(name,dict(cases={}))
                build=out/name
                if not build.exists():build.mkdir()
                executable=build/'swap_reference.exe'
                if not executable.exists():
                    (build/'solute.f90').write_bytes(source);(build/'mod_subsurface_solute_source.f90').write_bytes(helper)
                    flags=['-'+opt,'-std=legacy','-ffree-line-length-none','-ffixed-line-length-none','-fallow-argument-mismatch',
                           '-ffp-contract=off','-march=x86-64','-mtune=generic','-J'+str(build),'-I'+str(build),'-I'+str(objects),'-I'+str(ttutil)]
                    if version=='corrected':
                        r=call(['gfortran',*flags,'-c',build/'mod_subsurface_solute_source.f90','-o',build/'source.o'],build,'source-compile',60);assert r.returncode==0,r.stderr.decode(errors='replace')
                    (build/'irrigation.f90').write_bytes(corrected_irrigation if version=='corrected' else original_irrigation)
                    r=call(['gfortran',*flags,'-c',build/'irrigation.f90','-o',build/'irrigation.o'],build,'irrigation-compile',60);assert r.returncode==0,r.stderr.decode(errors='replace')
                    r=call(['gfortran',*flags,'-c',build/'solute.f90','-o',build/'solute.o'],build,'solute-compile',60);assert r.returncode==0,r.stderr.decode(errors='replace')
                    linked=[p for p in sorted(objects.glob('*.o')) if p.name not in ('solute.o','irrigation.o')]+[build/'irrigation.o',build/'solute.o']
                    if version=='corrected':linked.append(build/'source.o')
                    r=call(['gfortran','-o',executable,*linked,ttutil/'libttutil.a'],build,'link',60);assert r.returncode==0,r.stderr.decode(errors='replace')
                    record.update(executable_sha256=sha(executable),flags=flags,compile_providers=3 if version=='corrected' else 2,link_objects=len(linked));save()
                for kind,key in [('surface','water-file-surface'),('point','water-file-subsurface'),('interval','water-file-subsurface-interval')]:
                    for concentration in (0.,20.):
                        case_name=kind+'-'+str(int(concentration))
                        if record['cases'].get(case_name,{}).get('complete'):continue
                        case=build/case_name
                        if not case.exists():
                            create(case,key);control=case/'swap.swp';body=control.read_text(encoding='cp1252')
                            for field,value in dict(SWSOLU=1,SWMONTH=0,INLIST_CSV="'WATBAL,SOLBAL,GWL'").items():body=inputs.assignment(body,field,value)
                            control.write_text(body+'\nNUM_DECIMALS = 12\n',encoding='cp1252')
                            irrigation=case/'fixed-irrigation.irg';irrigation.write_text(irrigation.read_text().replace('24.0 20.0 ','24.0 '+repr(concentration)+' '))
                        inventory={p.relative_to(case).as_posix():sha(p) for p in case.rglob('*') if p.is_file()}
                        r=call([executable,'./swap.swp'],case,'reference',30)
                        assert (case/'swap.ok').exists(),(name,case_name,r.returncode,r.stderr.decode(errors='replace'))
                        data=rows(case/'result_output.csv');assert len(data)==1097
                        mass=math.fsum(float(row['S_IRRIG']) for row in data)
                        water=math.fsum(float(row['SSDI' if kind!='surface' else 'IRRIG']) for row in data)
                        balance=max(abs(float(row['S_BALDEV'])) for row in data)
                        record['cases'][case_name]=dict(complete=True,days=1096,returncode=r.returncode,input_sha256=inventory,
                            irrigation_water_cm=water,irrigation_mass_mg_cm2=mass,water_times_concentration_mg_cm2=water*concentration,
                            mass_difference_mg_cm2=mass-water*concentration,max_printed_solute_residual_mg_cm2=balance)
                        save();print(name,case_name,'ORIGINAL_PERIOD_COMPLETE',flush=True)
        checks={}
        for opt in ('O0','O2'):
            old,new=result['profiles']['original-'+opt],result['profiles']['corrected-'+opt]
            for case in ('surface-0','surface-20','point-0','interval-0'):
                assert rows(out/('original-'+opt)/case/'result_output.csv')==rows(out/('corrected-'+opt)/case/'result_output.csv'),('source-absent/surface drift',opt,case)
            for kind in ('point','interval'):
                a0,a20=new['cases'][kind+'-0'],new['cases'][kind+'-20']
                assert a20['irrigation_water_cm']>0 and a20['irrigation_mass_mg_cm2']>0
                assert abs(a20['mass_difference_mg_cm2'])<=1e-10,(opt,kind,a20)
                assert a20['max_printed_solute_residual_mg_cm2']<=1e-10,(opt,kind,a20)
                assert old['cases'][kind+'-20']['irrigation_mass_mg_cm2']==0
            checks[opt]=dict(surface_and_source_absent_all_rows_exact=True,original_missing_source_preserved=True,
                            corrected_point_interval_mass_matches_actual_water=True,chemical_guard_mg_cm2=1e-10)
        result.update(status='CORRECTED_ORIGINAL_NODAL_CHEMICAL_SOURCE_O0_O2_AND_SOURCE_ABSENT_PRESERVATION_PASS',checks=checks)
    except Exception as error:
        result.update(status='FAILED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
