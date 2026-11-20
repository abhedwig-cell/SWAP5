"""Private IO-only clock trace; never a scientific admission producer."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'nomacro_scheduled_subsurface'))
import implicit_conductivity_runtime as original

m=original.m


def main():
    p=argparse.ArgumentParser(description=__doc__)
    for name in ('reference-work','profile','warm','build-root','output'):p.add_argument('--'+name,type=Path,required=True)
    args=p.parse_args();args.output.mkdir();report=json.loads((args.profile/'RESULT.json').read_text())
    source=Path(report['build_root']);project=m.e.load(report['input_root'],original_output=True)
    meta,case=m.validate_bundle(source,args.reference_work,project)
    original_build=m.sha(source/'BUILD.json');private=args.build_root/'bundle';shutil.copytree(source,private)
    path=private/'timecontrol.f90';raw=path.read_text(encoding='cp1252')
    anchor='            if (t1900 - hybrid_age_print_epoch + dtCrit > dble(nprintcount)/dble(nprintday)) then'
    addition="""            if(daycum==633.and.fldayend)write(*,'(a,2i10,6(1x,es25.17e3),2l2)') &
             'PRIVATE_SNOW_GW_CLOCK_TRACE',daycum,nprintcount,t1900, &
             hybrid_age_print_epoch+dble(daycum-1)+tcum,tcum,dt,dtCrit,dble(nprintcount)/dble(nprintday),fldayend,flprintdt
"""
    assert raw.count(anchor)==1 and addition not in raw
    changed=raw.replace(anchor,addition+anchor,1);assert changed.replace(addition,'',1)==raw
    path.write_text(changed,encoding='cp1252')
    (args.output/'PRIVATE_timecontrol.f90').write_text(changed,encoding='cp1252')
    objects=args.reference_work/'build/swap-obj';ttutil=args.reference_work/'build/ttutil-obj'
    compile_command=['gfortran',*meta['identity']['donor_flags'],'-I',str(objects),'-I',str(ttutil),'-c','timecontrol.f90']
    local={p.name.casefold():p for p in private.glob('*.o')};provider=sorted(objects.glob('*.o'));names={p.name.casefold() for p in provider}
    donor=private/'day_donor.exe'
    link_command=['gfortran','-o',str(donor),*[str(local.get(p.name.casefold(),p)) for p in provider],
                  *[str(p) for name,p in sorted(local.items()) if name not in names],str(ttutil/'libttutil.a')]
    with (args.output/'compiler.stdout').open('x') as out,(args.output/'compiler.stderr').open('x') as err:
        subprocess.run(compile_command,cwd=private,stdout=out,stderr=err,check=True)
        subprocess.run(link_command,cwd=private,stdout=out,stderr=err,check=True)
    assert m.sha(source/'BUILD.json')==original_build
    result=dict(status='PRIVATE_IO_TRACE_RUNNING_NOT_ADMITTED',numeric_source_unchanged_after_removing_exact_IO=True,
                original_BUILD_sha256=original_build,original_TimeControl_lf_sha256=hashlib.sha256(raw.encode('cp1252')).hexdigest(),
                actual_private_executable_sha256=m.sha(donor),actual_private_timecontrol_sha256=m.sha(path),
                compile_command=compile_command,link_command=link_command,original_binding_role='INPUT_ORIGIN_ONLY',
                published_checkpoints=False,scientific_admission=False)
    def save():(args.output/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    save()
    try:
        origin=args.output/'origin';receipt=m.h.verify_checkpoint(args.warm/'accepted-column-1-day-532.zip',532,meta['binding'],origin)
        target=args.output/'trace';target.mkdir()
        run,seconds=m.bounded(60,lambda:m.h.run(donor,m.h.executable(private,'day_kernel'),case,target,633,
            checkpoint_day=532,origin=origin,origin_receipt=receipt,runtime=True,publish_day=None,
            checkpoint_binding=meta['binding'],model=project.model,project=project))
        assert run['first_refusal'] is None and not list(target.glob('accepted-*.zip'))
        assert m.physical(m.rows(target))==m.physical(m.rows(args.warm)[532:633])
        lines=[s for s in (target/'original/donor.stdout').read_text(encoding='utf-8').splitlines() if s.startswith('PRIVATE_SNOW_GW_CLOCK_TRACE')]
        assert len(lines)==1,lines
        result.update(status='PRIVATE_IO_ONLY_CLOCK_TRACE_PHYSICAL_PREFIX_MATCH_NOT_ADMITTED',seconds=seconds,actual_trace=lines)
    except Exception as error:
        result.update(status='PRIVATE_TRACE_FAILED_NOT_ADMITTED',error=repr(error));raise
    finally:save()
    print(result['status'],result['actual_trace'])


if __name__=='__main__':main()
