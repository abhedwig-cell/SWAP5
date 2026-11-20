"""Real qualified two-rate provider, bounded Frost domain and measured link closure."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import struct
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[2]


def main():
    p = argparse.ArgumentParser(description=__doc__)
    for name in ('reference-work','build-root','output'): p.add_argument('--'+name,type=Path,required=True)
    p.add_argument('--optimization',choices=('O0','O2'),required=True)
    a=p.parse_args();a.output.mkdir();a.build_root.mkdir(exist_ok=True)
    sys.path.insert(0,str(ROOT/'app/hybrid_water'))
    import user_prepare
    import implicit_frost_root_state as state
    from daily_host import NO_MACRO_FP_FLAGS
    sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
    q=dict(status='RUNNING',source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
           optimization=a.optimization,compiler=[],native=[],model_periods=0,new_physical_state=False,public_admitted=False)
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n',encoding='utf-8')
    def run(command,cwd=None):return subprocess.run(command,cwd=cwd or a.build_root,capture_output=True,text=True,timeout=60)
    save()
    try:
        user_prepare.validate(a.reference_work);ref=a.reference_work/'build';objects=ref/'swap-obj'
        files=sorted(p for p in objects.glob('*.o') if p.name!='swap_main.o')
        def symbols(paths,flag):
            r=run(['nm','-g',flag,'--format=posix',*map(str,paths)]);r.check_returncode();table={};current=None
            for line in r.stdout.splitlines():
                if line.endswith(':'):current=Path(line[:-1]);table[current]=set();continue
                if current is not None and line.strip():table[current].add(line.split()[0])
            assert set(table)==set(paths)
            return table
        defined=symbols(files,'--defined-only');undefined=symbols(files,'--undefined-only');lookup={}
        for path,values in defined.items():
            for value in values:lookup.setdefault(value,path)
        driver=Path(__file__).with_name('implicit_frost_root_driver.f90')
        flags=['gfortran','-'+a.optimization,'-ffree-line-length-none','-fcheck=all','-fimplicit-none',
            '-finit-local-zero','-ffpe-trap=invalid,zero,overflow',*NO_MACRO_FP_FLAGS,
            '-I'+str(a.build_root),'-I'+str(objects),'-I'+str(ref/'ttutil-obj'),'-J'+str(a.build_root)]
        def compile(command):
            start=time.perf_counter();r=run(command);q['compiler'].append(dict(command=command,returncode=r.returncode,
                seconds=time.perf_counter()-start,stdout=r.stdout,stderr=r.stderr));save();r.check_returncode()
        q.update(parent_provider_sha256=state.PARENT_SHA,driver_sha256=sha(driver),actual_object_closures={})
        for kind in (0,1):
            source=a.build_root/('root-kind'+str(kind)+'.f90');source.write_text(state.source(bool(kind)),encoding='cp1252')
            obj=source.with_suffix('.o');driver_obj=a.build_root/('driver-kind'+str(kind)+'.o')
            compile([*flags,'-c',str(source),'-o',str(obj)]);compile([*flags,'-c',str(driver),'-o',str(driver_obj)])
            own=symbols([obj,driver_obj],'--undefined-only');selected={lookup[s] for values in own.values() for s in values if s in lookup}
            while True:
                before=set(selected)
                for path in before:selected.update(lookup[s] for s in undefined[path] if s in lookup)
                if before==selected:break
            q['actual_object_closures'][str(kind)]=[dict(name=p.name,sha256=sha(p)) for p in sorted(selected)]
            exe=a.build_root/('root-kind'+str(kind)+('.exe' if os.name=='nt' else ''))
            compile([*flags,str(driver_obj),str(obj),*map(str,sorted(selected)),str(ref/'ttutil-obj/libttutil.a'),'-o',str(exe)])
            for path in (source,exe,driver):(a.output/path.name).write_bytes(path.read_bytes())
            for attack in ('roundtrip','header','witness','value-witness','nonfinite','truncated','bad-frost','bad-bottom'):
                work=a.build_root/(str(kind)+'-'+attack);work.mkdir();out=a.output/(str(kind)+'-'+attack);out.mkdir()
                r=run([str(exe),str(kind),attack],work)
                raw=(work/'root-native.bin').read_bytes();(out/'root-native.bin').write_bytes(raw)
                if attack=='roundtrip':
                    expected=struct.pack('<16i4d',*([4,3,kind,1,2,6,1,0]*2),0.25,0.875,0.25,0.875)
                    assert r.returncode==0 and not r.stderr and raw==expected
                    assert 'ACTUAL_FROST_ROOT_NATIVE_ROUNDTRIP_PASS' in r.stdout
                else:assert r.returncode!=0 and 'ACTUAL_FROST_ROOT_NATIVE_ROUNDTRIP_PASS' not in r.stdout
                q['native'].append(dict(kind=kind,attack=attack,returncode=r.returncode,stdout=r.stdout,stderr=r.stderr,
                    input_sha256=hashlib.sha256(raw).hexdigest(),bytes=len(raw),status='ROUNDTRIP_PASS' if attack=='roundtrip' else 'REFUSED'))
                save()
        q['status']='ACTUAL_TWO_RATE_FROST_NATIVE_PROVIDER_ROUNDTRIPS_AND_14_REFUSALS_PASS_NOT_ADMITTED'
        print(q['status'],{k:len(v) for k,v in q['actual_object_closures'].items()},flush=True)
    except Exception as error:q.update(status='FAILED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
