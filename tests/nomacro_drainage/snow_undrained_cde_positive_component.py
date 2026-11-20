"""Exercise the actual original CDE cell update through its production routine.

Verification-only task98 factors the complete literal private cell block into
an internal procedure. Both the original production callsite and task98 call
that same block; no conservation or adsorption formula is reconstructed.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time

ROOT=Path(__file__).resolve().parents[2]


def probe(text):
    anchor='   public :: solute_CDE, calc_AgeTracer'
    assert text.count(anchor)==1
    text=text.replace(anchor,"   real(8),save::hybrid_cde_probe_input(2)=0d0,hybrid_cde_probe_result(2)=0d0\n"
        '   public::hybrid_cde_probe_input,hybrid_cde_probe_result\n'+anchor,1)
    start=text.index('submodule (MOD_Solute) MOD_Solute_CDE')
    first=next(m.start() for m in re.finditer(r'(?m)^ +module subroutine solute_CDE\(task\)',text) if m.start()>start)
    match=next(m for m in re.finditer(r'(?m)^ +end subroutine solute_CDE',text) if m.start()>first)
    last=match.end();body=text[first:last]
    low=body.index('               cmsy(i) = cmsy(i) +')
    high=body.index('!              make top flux next compartment equal to current bottom flux',low)
    literal=body[low:high]
    body=body[:low]+'               call hybrid_actual_cde_cell()\n\n'+body[high:]
    anchor='      select case (task)';assert body.count(anchor)==1
    setup="""
      case (98)
         numnod=1;i=1;dz(1)=2d0;theta(1)=0.3d0
         if(.not.allocated(bdenskf))allocate(bdenskf(1))
         if(.not.allocated(bdenskfcref))allocate(bdenskfcref(1))
         bdenskf(1)=0.2d0;bdenskfcref(1)=0.2d0;cref=1d0
         frexp=hybrid_cde_probe_input(2);cmsy(1)=hybrid_cde_probe_input(1)
         cml(1)=vsmall;rounderr=0d0;sqbot=0d0;imsqbot=0d0
         qbot=0d0;dtsolu=1d0;cfluxb=0d0;cfluxt=0d0
         ctrans=0d0;crot=0d0;cdrtot=0d0
         call hybrid_actual_cde_cell()
         hybrid_cde_probe_result=[rounderr,cml(1)]
         return
"""
    body=body.replace(anchor,anchor+setup,1)
    at=body.rindex('      end subroutine solute_CDE')
    body=body[:at]+'      contains\n         subroutine hybrid_actual_cde_cell()\n'+literal+\
        '         end subroutine hybrid_actual_cde_cell\n'+body[at:]
    return text[:first]+body+text[last:],literal


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    for name in ('reference-work','build-root','output'):parser.add_argument('--'+name,type=Path,required=True)
    parser.add_argument('--optimization',choices=('O0','O2'),required=True)
    a=parser.parse_args();a.output.mkdir();a.build_root.mkdir(exist_ok=True)
    sys.path[:0]=[str(ROOT/'app/hybrid_water'),str(ROOT/'tools/solute')]
    import user_prepare
    import snow_undrained_cde_positive as correction
    from daily_host import NO_MACRO_FP_FLAGS,no_macro_fp_profile
    sha=lambda raw:hashlib.sha256(raw).hexdigest()
    q=dict(status='RUNNING',source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
        optimization=a.optimization,floating_point_profile=no_macro_fp_profile(),executions=[],model_periods=0)
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n',encoding='utf-8')
    def run(command):return subprocess.run(command,cwd=a.build_root,capture_output=True,text=True,timeout=60)
    save()
    try:
        user_prepare.validate(a.reference_work);ref=a.reference_work/'build';objects=ref/'swap-obj'
        files=sorted(p for p in objects.glob('*.o') if p.name!='swap_main.o')
        def symbols(flag):
            result=run(['nm','-g',flag,'--format=posix',*map(str,files)]);result.check_returncode();table={};current=None
            for line in result.stdout.splitlines():
                if line.endswith(':'):current=Path(line[:-1]);table[current]=set();continue
                if current is not None and line.strip():table[current].add(line.split()[0])
            assert set(table)==set(files);return table
        defined=symbols('--defined-only');undefined=symbols('--undefined-only');lookup={}
        for path,values in defined.items():
            for symbol in values:lookup.setdefault(symbol,path)
        selected={objects/'solute.o'}
        while True:
            before=set(selected)
            for path in before:selected.update(lookup[s] for s in undefined[path] if s in lookup)
            if selected==before:break
        original=(ref/'swap-selected/solute.f90').read_bytes();text=original.decode('cp1252').replace('\r\n','\n')
        driver=Path(__file__).with_name('snow_undrained_cde_positive_driver.f90')
        q.update(original_source_sha256=sha(original),driver_sha256=sha(driver.read_bytes()),
            numerical_owner_sha256=sha(Path(correction.__file__).read_bytes()),actual_original_object_closure=
            [dict(name=p.name,sha256=sha(p.read_bytes())) for p in sorted(selected)],
            verification='Complete literal original cell conservation, bottom booking, cutoff and adsorption block; original routine and verification-only task98 call the same internal block.')
        flags=['gfortran','-'+a.optimization,'-ffree-line-length-none','-fcheck=all','-fimplicit-none',
            '-finit-local-zero',*NO_MACRO_FP_FLAGS,'-I'+str(a.build_root),'-I'+str(objects),
            '-I'+str(ref/'ttutil-obj'),'-J'+str(a.build_root)]
        observations={}
        for mode,source in [('original',text),('corrected',correction.source(text))]:
            body,literal=probe(source);path=a.build_root/(mode+'.f90');path.write_text(body,encoding='cp1252')
            obj=a.build_root/(mode+'.o');exe=a.build_root/(mode+('.exe' if os.name=='nt' else ''))
            commands=[[*flags,'-c',str(path),'-o',str(obj)],
                [*flags,str(driver),str(obj),*map(str,sorted(selected-{objects/'solute.o'})),
                    str(ref/'ttutil-obj/libttutil.a'),'-o',str(exe)]]
            logs=[]
            for command in commands:
                started=time.perf_counter();result=run(command);logs.append(dict(command=command,returncode=result.returncode,
                    seconds=time.perf_counter()-started,stdout=result.stdout,stderr=result.stderr))
                (a.output/(mode+'-compile.json')).write_text(json.dumps(logs,indent=2)+'\n',encoding='utf-8')
                result.check_returncode()
            started=time.perf_counter();result=run([str(exe),mode]);record=dict(mode=mode,actual_source_sha256=sha(path.read_bytes()),
                literal_cell_sha256=sha(literal.encode('cp1252')),executable_sha256=sha(exe.read_bytes()),
                returncode=result.returncode,native_seconds=time.perf_counter()-started,stdout=result.stdout,stderr=result.stderr)
            q['executions'].append(record);save();result.check_returncode()
            observations[mode]=[line.split() for line in result.stdout.splitlines() if line.startswith('ACTUAL_ORIGINAL_CDE_TINY_CELL ')]
            assert len(observations[mode])==27
            for path in (path,exe):(a.output/(mode+'-'+path.name)).write_bytes(path.read_bytes())
        for old,new in zip(observations['original'],observations['corrected']):
            mass=float(old[3])
            if mass<=0 or mass>=1e-15:assert old==new,'Unchanged original cell path changed'
        q['status']='REAL_ORIGINAL_CDE_POSITIVE_TAIL_LOSS_AND_27_CORRECTED_CELL_CASES_PASS'
        print(q['status'],flush=True)
    except Exception as error:q.update(status='FAILED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
