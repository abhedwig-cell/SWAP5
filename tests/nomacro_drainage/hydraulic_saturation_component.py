"""Actual original private Jacobian/Tridag and default-MvG search diagonal."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time

ROOT=Path(__file__).resolve().parents[2]
SEARCH="""   ! Numerical search diagonal already present in original default MvG.
   ! Only the fully saturated flux/closed-bottom null mode is affected.
   if(SwKimpl==0.and.swmacro==0.and.swbotb==6.and..not.ftoph.and.NN>1)then
      if(all(h(1:NN)>=0d0).and.all(dimoca(1:NN)==0d0))then
         dFdhM(1:NN)=dFdhM(1:NN)+1d-7*FrArMtrx(1:NN)*dz(1:NN)
      end if
   end if
"""


def main():
    p=argparse.ArgumentParser(description=__doc__)
    for key in ('reference-work','build-root','output'):p.add_argument('--'+key,type=Path,required=True)
    p.add_argument('--optimization',choices=('O0','O2'),required=True)
    a=p.parse_args();a.output.mkdir();a.build_root.mkdir(exist_ok=True)
    sys.path.insert(0,str(ROOT/'app/hybrid_water'))
    import user_prepare
    from daily_host import NO_MACRO_FP_FLAGS
    user_prepare.validate(a.reference_work);ref=a.reference_work/'build';objects=ref/'swap-obj'
    sha=lambda path:hashlib.sha256(path.read_bytes()).hexdigest()
    q=dict(status='RUNNING',source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),optimization=a.optimization,
           compiler=[],variants={},model_periods=0,public_admission=False,physical_water_or_flux_changed=False)
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
        original=(ref/'swap-selected/headcalc.f90').read_text(encoding='cp1252')
        probe=Path(__file__).with_name('hydraulic_saturation_matrix_probe.f90').read_text(encoding='utf-8')
        q['actual_original_HeadCalc_sha256']=sha(ref/'swap-selected/headcalc.f90')
        parent=(ref/'swap-selected/MOD_MvG_functions.f90').read_text(encoding='cp1252');assert 'moiscap = dt * 1.0d-7' in parent
        q['actual_original_default_capacity_source_sha256']=sha(ref/'swap-selected/MOD_MvG_functions.f90')
        flags=['gfortran','-'+a.optimization,'-ffree-line-length-none','-fcheck=all','-fimplicit-none','-finit-local-zero',
            '-ffpe-trap=invalid,zero,overflow',*NO_MACRO_FP_FLAGS,'-I'+str(a.build_root),'-I'+str(objects),'-I'+str(ref/'ttutil-obj'),'-J'+str(a.build_root)]
        files=sorted(path for path in objects.glob('*.o') if path.name!='swap_main.o');defined=symbols(files,'--defined-only');undefined=symbols(files,'--undefined-only');lookup={}
        for path,values in defined.items():
            for symbol in values:lookup.setdefault(symbol,path)
        driver=a.build_root/'driver.f90';driver.write_text('program actual_saturation\ncall headcalc\nend program\n');driver_obj=a.build_root/'driver.o';compile([*flags,'-c',str(driver),'-o',str(driver_obj)])
        for name,body in [('original',original),('search_diagonal',original.replace('end subroutine jacobian_F',SEARCH+'end subroutine jacobian_F',1))]:
            if name!='original':assert body.replace(SEARCH,'',1)==original
            entry='   call hydraulic_saturation_probe()\n   return\n';anchor='!  reset some variables at the start of a new day'
            assert body.count(anchor)==1 and body.count('contains')==1
            actual=body.replace(anchor,entry+anchor,1).replace('contains','contains\n'+probe,1)
            assert actual.replace(entry,'',1).replace('\n'+probe,'',1)==body
            source=a.build_root/(name+'.f90');source.write_text(actual,encoding='cp1252');obj=a.build_root/(name+'.o');compile([*flags,'-c',str(source),'-o',str(obj)])
            selected={lookup[symbol] for values in symbols([obj,driver_obj],'--undefined-only').values() for symbol in values if symbol in lookup}
            while True:
                before=set(selected)
                for path in before:selected.update(lookup[symbol] for symbol in undefined[path] if symbol in lookup)
                if before==selected:break
            q['actual_original_object_closure']=[dict(name=path.name,sha256=sha(path)) for path in sorted(selected)]
            exe=a.build_root/(name+('.exe' if os.name=='nt' else ''))
            linked=[obj if path.name=='headcalc.o' else path for path in sorted(selected)]
            if obj not in linked:linked.append(obj)
            compile([*flags,str(driver_obj),*map(str,linked),str(ref/'ttutil-obj/libttutil.a'),'-o',str(exe)])
            r=run([str(exe)]);q['variants'][name]=dict(returncode=r.returncode,stdout=r.stdout,stderr=r.stderr,source_sha256=sha(source),executable_sha256=sha(exe));save();r.check_returncode()
            rows=[line.split() for line in r.stdout.splitlines() if line.startswith('ACTUAL_SATURATED_JACOBIAN ')]
            assert len(rows)==90 and all(len(row)==27 for row in rows)
            for path in (source,exe):(a.output/path.name).write_bytes(path.read_bytes())
        q['status']='ACTUAL_ORIGINAL_SATURATED_JACOBIAN_TRIDAG_SEARCH_COMPONENT_OBSERVED_NO_ADMISSION'
        print(q['status'],len(selected),flush=True)
    except Exception as error:q.update(status='FAILED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
