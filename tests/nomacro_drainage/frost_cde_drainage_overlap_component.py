"""Check actual Divdra against independent high-precision geometric integrals."""
import argparse
from decimal import Decimal,localcontext
import hashlib
import json
import math
import os
from pathlib import Path
import subprocess
import sys
import time

ROOT=Path(__file__).resolve().parents[2]


def geometric(channel,water,bottom):
    # Independent integral of the stated unit horizontal conductivity over
    # intersections of physical grid intervals; no Divdra formula is copied.
    with localcontext() as context:
        context.prec=80
        cells=[(Decimal(a),Decimal(b)) for a,b in ((0,10),(10,30),(30,70),(70,130))]
        def integral(low,high):return sum((max(Decimal(0),min(b,high)-max(a,low)) for a,b in cells),Decimal(0))
        total=integral(channel,bottom);saturated=integral(water,bottom)
        return total,saturated,total-saturated


def main():
    p=argparse.ArgumentParser(description=__doc__)
    for name in ('reference-work','build-root','output'):p.add_argument('--'+name,type=Path,required=True)
    p.add_argument('--optimization',choices=('O0','O2'),required=True);a=p.parse_args();a.output.mkdir();a.build_root.mkdir(exist_ok=True)
    sys.path.insert(0,str(ROOT/'app/hybrid_water'))
    import user_prepare
    import frost_divdra_overlap as correction
    from daily_host import NO_MACRO_FP_FLAGS,no_macro_fp_profile
    import frost_cde_drainage_divdra_probe as observer
    sha=lambda raw:hashlib.sha256(raw).hexdigest()
    q=dict(status='RUNNING',source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
        optimization=a.optimization,floating_point_profile=no_macro_fp_profile(),cases={},model_periods=0,
        scope='Original Divdra saturated/unsaturated geometric overlap only; public/CDE/Frost composition not admitted',canonical_admission=False)
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
        selected={objects/'divdra.o'}
        while True:
            before=set(selected)
            for path in before:selected.update(lookup[s] for s in undefined[path] if s in lookup)
            if before==selected:break
        original=(ref/'swap-selected/divdra.f90').read_text(encoding='cp1252');corrected=correction.source(original)
        driver=Path(__file__).with_name('frost_cde_drainage_overlap_driver.f90')
        q.update(original_source_lf_sha256=sha(original.encode('cp1252')),corrected_source_lf_sha256=sha(corrected.encode('cp1252')),
            driver_sha256=sha(driver.read_bytes()),observer_sha256=sha(Path(observer.__file__).read_bytes()),
            actual_original_object_closure=[dict(name=p.name,sha256=sha(p.read_bytes())) for p in sorted(selected)],
            actual_linked_original_objects=[p.name for p in sorted(selected-{objects/'divdra.o'})],
            ttutil_sha256=sha((ref/'ttutil-obj/libttutil.a').read_bytes()),geometric_oracle_decimal_digits=80)
        (a.output/'actual-driver.f90').write_bytes(driver.read_bytes());seen={}
        for mode,plain in [('original',original),('corrected',corrected)]:
            build=a.build_root/mode;build.mkdir();path=build/'divdra.f90';actual=observer.source(plain)
            path.write_text(actual,encoding='cp1252');obj=build/'divdra.o';exe=build/('actual-divdra-overlap'+('.exe' if os.name=='nt' else ''))
            flags=['gfortran','-'+a.optimization,'-g','-ffree-line-length-none','-fcheck=all','-fimplicit-none',
                '-finit-local-zero','-ffpe-trap=invalid,zero,overflow',*NO_MACRO_FP_FLAGS,
                '-I'+str(build),'-I'+str(objects),'-I'+str(ref/'ttutil-obj'),'-J'+str(build)]
            commands=[[*flags,'-c',str(path),'-o',str(obj)],[*flags,str(driver),str(obj),
                *map(str,sorted(selected-{objects/'divdra.o'})),str(ref/'ttutil-obj/libttutil.a'),'-o',str(exe)]]
            logs=[]
            for command in commands:
                start=time.perf_counter();r=run(command,build);logs.append(dict(command=command,returncode=r.returncode,
                    seconds=time.perf_counter()-start,stdout=r.stdout,stderr=r.stderr))
                (a.output/(mode+'-compile.json')).write_text(json.dumps(logs,indent=2)+'\n',encoding='utf-8');r.check_returncode()
            (a.output/(mode+'-reference.f90')).write_text(plain,encoding='cp1252')
            (a.output/(mode+'-probe.f90')).write_bytes(path.read_bytes());(a.output/(mode+'-'+exe.name)).write_bytes(exe.read_bytes())
            modeq=q['cases'][mode]={};seen[mode]={}
            for water in (45,50,55):
                for channel in (5,35):
                    for spacing in (40,400):
                        label=f'{water}-{channel}-{spacing}';start=time.perf_counter();r=run([str(exe),str(water),str(channel),str(spacing)],build)
                        item=modeq[label]=dict(input=dict(water_depth_cm=water,channel_depth_cm=channel,spacing_cm=spacing),
                            returncode=r.returncode,native_seconds=time.perf_counter()-start,stdout=r.stdout,stderr=r.stderr,
                            actual_source_sha256=sha(path.read_bytes()),executable_sha256=sha(exe.read_bytes()));save()
                        rows=[line.split() for line in r.stdout.splitlines() if line.startswith('ACTUAL_DIVDRA_INFILTRATION_BOOKKEEPING ')]
                        assert len(rows)==1,'Actual original private Divdra observation missing'
                        row=rows[0];dmax=Decimal(row[8]);expected=geometric(Decimal(channel),Decimal(water),dmax)
                        actual=tuple(Decimal(row[i]) for i in (13,14,15));item.update(expected_geometric_transmissivity_cm2_d=list(map(str,expected)),
                            actual_transmissivity_cm2_d=list(map(str,actual)),actual_saturated_overlap_positive=actual[1]>0,
                            exact_geometric_integral=actual==expected)
                        outputs=[line for line in r.stdout.splitlines() if line.startswith('ACTUAL_DIVDRA_OVERLAP_OUTPUT ')]
                        if mode=='corrected':
                            r.check_returncode();assert not r.stderr and actual==expected and actual[1]>0 and len(outputs)==1
                            values=list(map(float,outputs[0].split()[1:]));assert all(math.isfinite(x) for x in values)
                            assert abs(math.fsum([-values[3],*values[4:]]))<=1e-10 and all(x<=0 for x in values[4:])
                        elif spacing==40:
                            assert actual!=expected,'Original within-cell overlap defect not reproduced'
                            if water==50:assert actual[1]==0 and r.returncode!=0 and 'Floating-point exception' in r.stderr
                        else:r.check_returncode();assert not r.stderr and actual==expected
                        seen[mode][label]=r.stdout;save()
        for label in seen['original']:
            if label.endswith('-400'):assert seen['original'][label]==seen['corrected'][label],'Actual unaffected Divdra path changed'
        q['status']='ACTUAL_ORIGINAL_DIVDRA_OVERLAP_DEFECT_AND_12_CORRECTED_GEOMETRIC_RATE_CASES_PASS'
        print(q['status'],len(selected),flush=True)
    except Exception as error:q.update(status='FAILED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
