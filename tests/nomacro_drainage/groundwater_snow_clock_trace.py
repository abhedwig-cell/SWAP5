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
    p.add_argument('--trace-kind',choices=('clock','head','top'),default='clock')
    p.add_argument('--target-day',type=int,default=633)
    p.add_argument('--resume-compiled',action='store_true')
    args=p.parse_args();args.output.mkdir(exist_ok=args.resume_compiled);report=json.loads((args.profile/'RESULT.json').read_text())
    source=Path(report['build_root']);project=m.e.load(report['input_root'],original_output=True)
    meta,case=m.validate_bundle(source,args.reference_work,project)
    original_build=m.sha(source/'BUILD.json');private=args.build_root/'bundle'
    if args.resume_compiled:assert private.is_dir()
    else:shutil.copytree(source,private)
    provider={'clock':'timecontrol.f90','head':'headcalc.f90','top':'boundtop.f90'}[args.trace_kind]
    path=private/provider;raw=(source/provider).read_text(encoding='cp1252')
    anchor='            if (t1900 - hybrid_age_print_epoch + dtCrit > dble(nprintcount)/dble(nprintday)) then'
    addition="""            if(daycum==633.and.fldayend)write(*,'(a,2i10,6(1x,es25.17e3),2l2)') &
             'PRIVATE_SNOW_GW_CLOCK_TRACE',daycum,nprintcount,t1900, &
             hybrid_age_print_epoch+dble(daycum-1)+tcum,tcum,dt,dtCrit,dble(nprintcount)/dble(nprintday),fldayend,flprintdt
"""
    if args.trace_kind=='head':
        anchor='         if(abs(hybrid_groundwater_cde_clock_trial(groundwater_bottom,groundwater_delta))>1d-10)flnonconv=.true.'
        addition="""
         if(daycum==TRACE_DAY.and.flnonconv)then
          private_snow_trace_count=private_snow_trace_count+1
          if(private_snow_trace_count<=32.or.mod(private_snow_trace_count,10000)==0)then
          write(*,'(a,i8,13(1x,es25.17e3),3l2)')'PRIVATE_SNOW_GW_HEAD_TRACE', &
           daycum,t1900,tcum,dt,h(1),pond,q0,groundwater_bottom,groundwater_delta, &
           budget_step,budget_total,1d-10*(t1900-budget_start+dt), &
           hybrid_groundwater_cde_clock_trial(groundwater_bottom,groundwater_delta),hsurf,ftoph,flnonconv,flrunoff
          flush(6)
          end if
         end if
""".replace('TRACE_DAY',str(args.target_day))
        imports='   use variables,only:daycum,tcum\n'
        declaration='   integer,save::private_snow_trace_count=0\n'
        assert raw.count('\nsubroutine headcalc\n')==raw.count('\n   implicit none\n')==raw.count(anchor)==1
        changed=raw.replace('\nsubroutine headcalc\n','\nsubroutine headcalc\n'+imports,1)
        changed=changed.replace('\n   implicit none\n','\n   implicit none\n'+declaration,1).replace(anchor,anchor+addition,1)
        assert changed.replace(imports,'',1).replace(declaration,'',1).replace(addition,'',1)==raw
    elif args.trace_kind=='top':
        anchor='      if (h0 <= 1.0d-6) then'
        addition="""      if(daycum==TRACE_DAY.and.h0>0d0.and.h0<=1d-6.and.private_snow_top_count<32)then
       private_snow_top_count=private_snow_top_count+1
       write(*,'(a,i8,8(1x,es25.17e3))')'PRIVATE_SNOW_GW_TOP_TRACE', &
        daycum,tcum,dt,h0,h(1),pondm1,q1,k1max,disnod(1)
       flush(6)
      end if
""".replace('TRACE_DAY',str(args.target_day))
        imports='      use variables,only:daycum,tcum\n'
        declaration='      integer,save::private_snow_top_count=0\n'
        import_anchor='      use variables,     only: k, swkmean, h, swredu, pondm1, dt, fluseksatexm, ksatexm, ksatfit'
        decl_anchor='      integer, intent(in)  :: iTask'
        assert raw.count(anchor)==raw.count(import_anchor)==raw.count(decl_anchor)==1
        changed=raw.replace(import_anchor,imports+import_anchor,1).replace(decl_anchor,declaration+decl_anchor,1).replace(anchor,addition+anchor,1)
        assert changed.replace(imports,'',1).replace(declaration,'',1).replace(addition,'',1)==raw
    else:
        assert raw.count(anchor)==1 and addition not in raw
        changed=raw.replace(anchor,addition+anchor,1);assert changed.replace(addition,'',1)==raw
    if args.resume_compiled:
        assert path.read_text(encoding='cp1252')==(args.output/('PRIVATE_'+provider)).read_text(encoding='cp1252')==changed
    else:
        path.write_text(changed,encoding='cp1252')
        (args.output/('PRIVATE_'+provider)).write_text(changed,encoding='cp1252')
    objects=args.reference_work/'build/swap-obj';ttutil=args.reference_work/'build/ttutil-obj'
    compile_command=['gfortran',*meta['identity']['donor_flags'],'-I',str(objects),'-I',str(ttutil),'-c',provider]
    local={p.name.casefold():p for p in private.glob('*.o')};provider_objects=sorted(objects.glob('*.o'));names={p.name.casefold() for p in provider_objects}
    donor=private/'day_donor.exe'
    link_command=['gfortran','-o',str(donor),*[str(local.get(p.name.casefold(),p)) for p in provider_objects],
                  *[str(p) for name,p in sorted(local.items()) if name not in names],str(ttutil/'libttutil.a')]
    if not args.resume_compiled:
        with (args.output/'compiler.stdout').open('x') as out,(args.output/'compiler.stderr').open('x') as err:
            subprocess.run(compile_command,cwd=private,stdout=out,stderr=err,check=True)
            subprocess.run(link_command,cwd=private,stdout=out,stderr=err,check=True)
    assert m.sha(source/'BUILD.json')==original_build
    result=dict(status='PRIVATE_IO_TRACE_RUNNING_NOT_ADMITTED',numeric_source_unchanged_after_removing_exact_IO=True,
                original_BUILD_sha256=original_build,source_file=provider,original_provider_lf_sha256=hashlib.sha256(raw.encode('cp1252')).hexdigest(),
                actual_private_executable_sha256=m.sha(donor),actual_private_provider_sha256=m.sha(path),
                compile_command=compile_command,link_command=link_command,original_binding_role='INPUT_ORIGIN_ONLY',
                published_checkpoints=False,scientific_admission=False)
    def save():(args.output/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    save()
    try:
        origin=args.output/'origin';receipt=m.h.verify_checkpoint(args.warm/'accepted-column-1-day-532.zip',532,meta['binding'],origin)
        target=args.output/'trace';target.mkdir()
        try:
            run,seconds=m.bounded(45 if args.trace_kind!='clock' else 60,lambda:m.h.run(donor,m.h.executable(private,'day_kernel'),case,target,args.target_day,
                checkpoint_day=532,origin=origin,origin_receipt=receipt,runtime=True,publish_day=None,
                checkpoint_binding=meta['binding'],model=project.model,project=project))
            assert run['first_refusal'] is None
        except Exception as error:
            if args.trace_kind=='clock':raise
            seconds=None;result['actual_censor_or_refusal']=repr(error)
        assert not list(target.glob('accepted-*.zip'))
        actual=m.rows(target);warm=m.rows(args.warm)
        assert m.physical(actual)==m.physical(warm[532:532+len(actual)])
        prefix={'head':'PRIVATE_SNOW_GW_HEAD_TRACE','clock':'PRIVATE_SNOW_GW_CLOCK_TRACE','top':'PRIVATE_SNOW_GW_TOP_TRACE'}[args.trace_kind]
        lines=[s for s in (target/'original/donor.stdout').read_text(encoding='utf-8').splitlines() if s.startswith(prefix)]
        assert lines and (args.trace_kind!='clock' or len(lines)==1),lines
        result.update(status='PRIVATE_IO_ONLY_TRACE_PHYSICAL_PREFIX_MATCH_NOT_ADMITTED',seconds=seconds,actual_trace=lines,
                      trace_kind=args.trace_kind,actual_prefix_days=len(actual))
    except Exception as error:
        result.update(status='PRIVATE_TRACE_FAILED_NOT_ADMITTED',error=repr(error));raise
    finally:save()
    print(result['status'],'trace_rows=',len(result['actual_trace']))


if __name__=='__main__':main()
