"""Measure original hydraulic derivative interfaces; retain every mismatch/refusal."""
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
    for key in ('reference-work','build-root','output'):p.add_argument('--'+key,type=Path,required=True)
    p.add_argument('--optimization',choices=('O0','O2'),required=True)
    p.add_argument('--correct-model7-capacity',action='store_true')
    p.add_argument('--model7-grid',action='store_true')
    p.add_argument('--mixed-grid',action='store_true')
    p.add_argument('--correct-vapor-sign',action='store_true')
    a=p.parse_args()
    if a.mixed_grid and not a.correct_model7_capacity:p.error('Mixed vapor source comparison requires already qualified model7 capacity correction')
    a.output.mkdir();a.build_root.mkdir(exist_ok=True)
    sys.path.insert(0,str(ROOT/'app/hybrid_water'))
    import user_prepare
    from daily_host import NO_MACRO_FP_FLAGS
    user_prepare.validate(a.reference_work);ref=a.reference_work/'build';objects=ref/'swap-obj'
    sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
    q=dict(status='RUNNING',source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
        optimization=a.optimization,compiler=[],original_models=[],model_periods=0,public_admitted=False,
        model7_capacity_correction=a.correct_model7_capacity,model7_parameter_grid=a.model7_grid,vapor_original_grid=True,mixed_vapor_grid=a.mixed_grid,
        purpose='Actual original watcon/moiscap and hconduc/dhconduc. Source assessment only; mismatches are not repaired or admitted.',
        fixture='Existing original4..11 two-soil coefficients1..7/13..21; explicit full-module initialization with hysteresis0/Frost0, perlayerNoVap0/1 andactualtsoil0/20/40, alphaWet2alpha and entry-.01; no claim of original reader execution')
    q['vapor_sign_correction']=a.correct_vapor_sign
    q['actual_controller_path']=__file__;q['actual_controller_sha256']=sha(Path(__file__));q['controller_baseline_git_source']='dcb0a8215573176f73e4fea5dd232e19e4ea8e6a';q['actual_probe_scope']=('Mixed6orderedpairs/4heads/3opposedtemperatures/4vaporflags/6visits1728calls' if a.mixed_grid else 'Original4models/2soils/4heads/3temperatures/2vaporflags192calls')+'; no model periods or admission'
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n',encoding='utf-8')
    def run(command):return subprocess.run(command,cwd=a.build_root,capture_output=True,text=True,timeout=60)
    def compile(command):
        start=time.perf_counter();r=run(command);q['compiler'].append(dict(command=command,returncode=r.returncode,seconds=time.perf_counter()-start,stdout=r.stdout,stderr=r.stderr));save();r.check_returncode()
    def symbols(paths,flag):
        r=run(['nm','-g',flag,'--format=posix',*map(str,paths)]);r.check_returncode();table={};current=None
        for line in r.stdout.splitlines():
            if line.endswith(':'):current=Path(line[:-1]);table[current]=set();continue
            if current is not None and line.strip():table[current].add(line.split()[0])
        assert set(table)==set(paths);return table
    save()
    try:
        flags=['gfortran','-'+a.optimization,'-ffree-line-length-none','-fcheck=all','-fimplicit-none','-finit-local-zero',
            '-ffpe-trap=invalid,zero,overflow',*NO_MACRO_FP_FLAGS,'-I'+str(a.build_root),'-I'+str(objects),'-I'+str(ref/'ttutil-obj'),'-J'+str(a.build_root)]
        files=sorted(path for path in objects.glob('*.o') if path.name!='swap_main.o')
        defined=symbols(files,'--defined-only');undefined=symbols(files,'--undefined-only');lookup={}
        for path,values in defined.items():
            for value in values:lookup.setdefault(value,path)
        affected={}
        for name in ('WC_K_models_04_11','MOD_MvG_functions'):
            source=ref/'swap-selected'/(name+'.f90');target=a.build_root/(name+'.f90');raw=source.read_bytes()
            if a.correct_model7_capacity and name=='WC_K_models_04_11':
                text=raw.decode('cp1252').replace('\r\n','\n')
                before='   C_MvG_2_s = (WCs-WCr)*(Omega1*C1(h)/(1.0d0-Gam01) + Omega2*C2(h)/(1.0d0-Gam02))'
                after='   C_MvG_2_s = (WCs-WCr)*(Omega1*C1(h) + Omega2*C2(h))/(1.0d0-Omega1*Gam01-Omega2*Gam02)'
                assert text.count(before)==1
                corrected=text.replace(before,after,1);assert corrected.replace(after,before,1)==text
                raw=corrected.encode('cp1252')
            if a.correct_vapor_sign and name=='WC_K_models_04_11':
                text=raw.decode('cp1252').replace('\r\n','\n')
                before='Hr        = dexp(h/100.0d0*MgRT)'
                after='Hr        = dexp(-h/100.0d0*MgRT)'
                assert text.count(before)==1
                corrected=text.replace(before,after,1);assert corrected.replace(after,before,1)==text
                raw=corrected.encode('cp1252')
            target.write_bytes(raw)
            obj=a.build_root/(name+'.o');compile([*flags,'-c',str(target),'-o',str(obj)])
            assert objects/(name+'.o') in files;affected[objects/(name+'.o')]=obj
            (a.output/target.name).write_bytes(target.read_bytes())
        driver=Path(__file__).with_name('hydraulic_vapor_mixed_probe.f90' if a.mixed_grid else 'hydraulic_vapor_probe.f90');obj=a.build_root/'driver.o';compile([*flags,'-c',str(driver),'-o',str(obj)])
        selected={lookup[symbol] for values in symbols([obj,*affected.values()],'--undefined-only').values() for symbol in values if symbol in lookup}
        while True:
            before=set(selected)
            for path in before:selected.update(lookup[symbol] for symbol in undefined[path] if symbol in lookup)
            if before==selected:break
        q['actual_original_object_closure']=[dict(name=path.name,sha256=sha(path)) for path in sorted(selected)]
        q['original_rebuilt_sources']={name.name:dict(original_sha256=sha(ref/'swap-selected'/name.name),actual_sha256=sha(name)) for name in a.build_root.glob('*.f90')}
        q['driver_sha256']=sha(driver)
        exe=a.build_root/('actual-hydraulic'+('.exe' if os.name=='nt' else ''))
        linked=[affected.get(path,path) for path in sorted(selected)]
        for path in affected.values():
            if path not in linked:linked.append(path)
        compile([*flags,str(obj),*map(str,linked),str(ref/'ttutil-obj/libttutil.a'),'-o',str(exe)])
        q['executable_sha256']=sha(exe)
        for path in (exe,driver):(a.output/path.name).write_bytes(path.read_bytes())
        for model in (8,):
            r=run([str(exe),str(model)]);(a.output/('model'+str(model)+'.stdout')).write_text(r.stdout,encoding='utf-8');(a.output/('model'+str(model)+'.stderr')).write_text(r.stderr,encoding='utf-8')
            rows=[line.split() for line in r.stdout.splitlines() if line.startswith('ACTUAL_ORIGINAL_HYDRAULIC ')]
            if r.returncode==0:assert len(rows)==(1728 if a.mixed_grid else 192) and not r.stderr
            q['original_models'].append(dict(model=model,returncode=r.returncode,raw_rows=len(rows),status='COMPONENT_OBSERVED' if r.returncode==0 else 'ORIGINAL_COMPONENT_REFUSED',stderr=r.stderr));save()
        q['status']='ACTUAL_ORIGINAL_HYDRAULIC_INTERFACES_OBSERVED_NO_ADMISSION'
        print(q['status'],len(selected),[(row['model'],row['returncode']) for row in q['original_models']],flush=True)
    except Exception as error:q.update(status='FAILED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
