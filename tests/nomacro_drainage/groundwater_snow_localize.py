"""Localize the actual censored Snow full period using original accepted states."""
import argparse
import json
from pathlib import Path
import subprocess
import sys
import zipfile

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'nomacro_scheduled_subsurface'))
import implicit_conductivity_runtime as original

m=original.m


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    for key in ('reference-work','full','output'):parser.add_argument('--'+key,type=Path,required=True)
    parser.add_argument('--reuse-cold-root',type=Path)
    args=parser.parse_args();args.output.mkdir();report=json.loads((args.full/'RESULT.json').read_text())
    assert report['status']=='FAILED_OR_CENSORED'
    bundle=Path(report['build_root']);project=m.e.load(report['input_root'],original_output=True)
    meta,case=m.validate_bundle(bundle,args.reference_work,project);build_before=m.sha(bundle/'BUILD.json')
    warm=args.full/'trajectory';data=m.rows(warm);assert len(data)==633
    result=dict(status='RUNNING',source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=original.ROOT,text=True).strip(),
                actual_BUILD_sha256=build_before,original_full_receipt_sha256=m.sha(args.full/'RESULT.json'),
                original_full_status='FAILED_OR_CENSORED',observed_accepted_days=633,cold={},model_compilations=0,
                whole_scientific_equivalence='NOT_QUALIFIED',functional_completion='PARTIAL')
    def save():(args.output/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    save()
    try:
        def run(low,high,source,target,cap):
            origin=target.with_name(target.name+'-origin');receipt=m.h.verify_checkpoint(source,low,meta['binding'],origin);target.mkdir()
            record,seconds=m.bounded(cap,lambda:m.h.run(m.h.executable(bundle,'day_donor'),m.h.executable(bundle,'day_kernel'),case,target,high,
                checkpoint_day=low,origin=origin,origin_receipt=receipt,runtime=True,publish_day=high,checkpoint_binding=meta['binding'],model=project.model,project=project))
            assert record['first_refusal'] is None,record
            return seconds
        for low,high in ((364,367),(530,532)):
            previous=args.reuse_cold_root/f'own-{low}' if args.reuse_cold_root else None
            if previous is not None and (previous/f'accepted-column-1-day-{high}.zip').exists():
                target=previous;seconds=None;reused=True
            else:
                target=args.output/f'own-{low}'
                seconds=run(low,high,warm/f'accepted-column-1-day-{low}.zip',target,60);reused=False
            actual=m.rows(target);assert m.physical(actual)==m.physical(data[low:high])
            with zipfile.ZipFile(warm/f'accepted-column-1-day-{high}.zip') as a,zipfile.ZipFile(target/f'accepted-column-1-day-{high}.zip') as b:
                assert all(a.read(name)==b.read(name) for name in ('macro.bin','result.end'))
            result['cold'][str(low)]=dict(start=low,end=high,actual_root=str(target),exact_physical=True,exact_complete_native=True,
                reused_original_completed_cold=reused,seconds=seconds,user_output_role='NOT_EVALUATED_CENSORED_WARM_BINARY_INCOMPLETE')
            save()
        prefix=args.output/'accepted-prefix-633'
        seconds=run(532,633,warm/'accepted-column-1-day-532.zip',prefix,60)
        actual=m.rows(prefix);assert m.physical(actual)==m.physical(data[532:633])
        result['accepted_prefix']=dict(start=532,end=633,exact_physical=True,seconds=seconds,
                                       new_actual_checkpoint_sha256=m.sha(prefix/'accepted-column-1-day-633.zip'))
        save()
        try:
            seconds=run(633,634,prefix/'accepted-column-1-day-633.zip',args.output/'day-634',30)
            result['day634']=dict(status='ACCEPTED',seconds=seconds)
        except Exception as error:result['day634']=dict(status='REFUSED_OR_CENSORED',error=repr(error))
        assert m.sha(bundle/'BUILD.json')==build_before
        result['status']='ACTUAL_ORIGINAL_STATE_FULL_PERIOD_LOCALIZATION_COMPLETE'
    except Exception as error:
        result.update(status='LOCALIZATION_FAILED',error=repr(error));raise
    finally:save()
    print(result['status'],result.get('day634'))


if __name__=='__main__':main()
