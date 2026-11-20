"""Exercise actual FrozenCond/FrozenBounds and Divdra; no copied flow equation."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time

ROOT=Path(__file__).resolve().parents[2]


def main():
    p=argparse.ArgumentParser(description=__doc__)
    for name in ('reference-work','build-root','output'):p.add_argument('--'+name,type=Path,required=True)
    p.add_argument('--optimization',choices=('O0','O2'),required=True)
    modegroup=p.add_mutually_exclusive_group()
    modegroup.add_argument('--diagnose-divdra',action='store_true')
    modegroup.add_argument('--correct-divdra-overlap',action='store_true');a=p.parse_args();a.output.mkdir();a.build_root.mkdir(exist_ok=True)
    sys.path.insert(0,str(ROOT/'app/hybrid_water'))
    import user_prepare
    import frost_reference
    from daily_host import NO_MACRO_FP_FLAGS,no_macro_fp_profile
    sha=lambda raw:hashlib.sha256(raw).hexdigest()
    q=dict(status='RUNNING',source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
        optimization=a.optimization,scope='Actual original SWDIVD1 nodal rate interface; CDE/whole-model/public scope not qualified',
        model_periods=0,canonical_admission=False,executions=[],floating_point_profile=no_macro_fp_profile())
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n',encoding='utf-8')
    def run(command,cwd):return subprocess.run(command,cwd=cwd,capture_output=True,text=True,timeout=60)
    save()
    try:
        user_prepare.validate(a.reference_work);ref=a.reference_work/'build';objects=ref/'swap-obj'
        files=sorted(p for p in objects.glob('*.o') if p.name!='swap_main.o')
        def symbols(flag):
            r=run(['nm','-g',flag,'--format=posix',*map(str,files)],a.build_root);r.check_returncode();table={};current=None
            for line in r.stdout.splitlines():
                if line.endswith(':'):current=Path(line[:-1]);table[current]=set();continue
                if current is not None and line.strip():table[current].add(line.split()[0])
            assert set(table)==set(files);return table
        defined=symbols('--defined-only');undefined=symbols('--undefined-only');lookup={}
        for path,values in defined.items():
            for symbol in values:lookup.setdefault(symbol,path)
        selected={objects/'frozencond.o'}
        while True:
            before=set(selected)
            for path in before:selected.update(lookup[s] for s in undefined[path] if s in lookup)
            if before==selected:break
        original=(ref/'swap-selected/frozencond.f90').read_bytes();guarded=frost_reference.source(original)
        driver=Path(__file__).with_name('frost_cde_drainage_rates_driver.f90')
        q.update(original_frozencond_sha256=sha(original),guarded_frozencond_sha256=sha(guarded),
            actual_original_Divdra_sha256=sha((ref/'swap-selected/divdra.f90').read_bytes()),
            driver_sha256=sha(driver.read_bytes()),actual_original_object_closure=[dict(name=p.name,sha256=sha(p.read_bytes())) for p in sorted(selected)],
            ttutil_sha256=sha((ref/'ttutil-obj/libttutil.a').read_bytes()),physical_equations_changed=False)
        (a.output/'actual-driver.f90').write_bytes(driver.read_bytes());observations={}
        modes=[('original',original)] if a.diagnose_divdra else [('original',original),('guarded',guarded)]
        for mode,source in modes:
            build=a.build_root/mode;build.mkdir();path=build/'frozencond.f90';path.write_bytes(source)
            obj=build/'frozencond.o';exe=build/('actual-frost-divdra'+('.exe' if os.name=='nt' else ''))
            flags=['gfortran','-'+a.optimization,'-cpp','-ffree-line-length-none','-fcheck=all','-fimplicit-none',
                '-finit-local-zero','-ffpe-trap=invalid,zero,overflow',*NO_MACRO_FP_FLAGS,
                '-I'+str(build),'-I'+str(objects),'-I'+str(ref/'ttutil-obj'),'-J'+str(build)]
            if mode=='guarded':flags.append('-DGUARDED')
            extra=[];replaced={objects/'frozencond.o'}
            commands=[[*flags,'-c',str(path),'-o',str(obj)]]
            if a.diagnose_divdra or a.correct_divdra_overlap:
                raw=(ref/'swap-selected/divdra.f90').read_text(encoding='cp1252')
                actual=raw
                if a.correct_divdra_overlap:
                    import frost_divdra_overlap as correction
                    actual=correction.source(actual)
                    q['explicit_Divdra_reference_correction']='FROST-DIVDRA-OVERLAP-01'
                    q['scope']='Actual original/guarded FrozenCond and FrozenBounds with separately corrected Divdra geometric overlap; CDE/whole-model/public scope not qualified'
                if a.diagnose_divdra:
                    import frost_cde_drainage_divdra_probe as observer
                    actual=observer.source(actual);q['diagnostic_observer_sha256']=sha(Path(observer.__file__).read_bytes())
                observed=build/'divdra.f90';observed.write_text(actual,encoding='cp1252')
                q['actual_compiled_Divdra_sha256']=sha(observed.read_bytes())
                extra=[build/'divdra.o'];replaced.add(objects/'divdra.o')
                commands.append([*flags,'-g','-c',str(observed),'-o',str(extra[0])])
                (a.output/(mode+'-actual-divdra.f90')).write_bytes(observed.read_bytes())
            q['actual_linked_original_objects']=[p.name for p in sorted(selected-replaced)]
            commands.append([*flags,str(driver),str(obj),*map(str,extra),*map(str,sorted(selected-replaced)),
                    str(ref/'ttutil-obj/libttutil.a'),'-o',str(exe)])
            logs=[]
            for command in commands:
                start=time.perf_counter();r=run(command,build);logs.append(dict(command=command,returncode=r.returncode,
                    seconds=time.perf_counter()-start,stdout=r.stdout,stderr=r.stderr))
                (a.output/(mode+'-compile.json')).write_text(json.dumps(logs,indent=2)+'\n',encoding='utf-8');r.check_returncode()
            (a.output/(mode+'-frozencond.f90')).write_bytes(source);(a.output/(mode+'-'+exe.name)).write_bytes(exe.read_bytes())
            start=time.perf_counter();r=run([str(exe)],build)
            record=dict(mode=mode,actual_source_sha256=sha(source),executable_sha256=sha(exe.read_bytes()),
                native_seconds=time.perf_counter()-start,returncode=r.returncode,stdout=r.stdout,stderr=r.stderr)
            q['executions'].append(record);save()
            if a.diagnose_divdra:
                rows=[line.split() for line in r.stdout.splitlines() if line.startswith('ACTUAL_DIVDRA_INFILTRATION_BOOKKEEPING ')]
                broken=[v for v in rows if float(v[14])==0 and float(v[13])>0 and float(v[12])>0 and float(v[16])<0]
                assert r.returncode!=0 and 'Floating-point exception' in r.stderr and broken,'Original Divdra causal zero-KDsat diagnostic absent'
                q['actual_zero_KDsat_observations']=broken
                q['status']='ACTUAL_ORIGINAL_DIVDRA_ZERO_SATURATED_TRANSMISSIVITY_DIAGNOSTIC_REPRODUCED_NOT_QUALIFIED'
                print(q['status'],flush=True);return
            r.check_returncode()
            observations[mode]=[line for line in r.stdout.splitlines() if line.startswith('ACTUAL_FROZENBOUNDS_DIVDRA_RATES ')]
            assert len(observations[mode])==84 and not r.stderr
        assert observations['original']==observations['guarded'],'Actual valid SWDIVD1 Frost physics differs from the original procedure'
        q['status']=('ACTUAL_ORIGINAL_AND_GUARDED_FROST_WITH_CORRECTED_DIVDRA_84_RATE_CASES_PASS_NOT_CDE_QUALIFIED'
            if a.correct_divdra_overlap else 'ACTUAL_ORIGINAL_AND_GUARDED_FROZENBOUNDS_DIVDRA_84_RATE_INTERFACE_CASES_PASS_NOT_CDE_QUALIFIED')
        print(q['status'],len(selected),flush=True)
    except Exception as error:q.update(status='FAILED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
