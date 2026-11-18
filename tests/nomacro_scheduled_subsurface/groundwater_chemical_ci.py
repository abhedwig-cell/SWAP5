"""Bounded actual prescribed groundwater CDE source and native qualification."""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import sys
import groundwater_chemical_runtime as runtime

CASES={
    'within-csv3':('within',3,(),True),
    'below-csv1':('below',1,(),True),
    'crossing-csv3':('crossing',3,(),True),
    'crossing-bbc':('crossing',1,('--boundary-file',),True),
    'crossing-sorption-decay':('crossing',2,('--chemistry',),True),
    'crossing-default':('crossing',1,('--compatibility-output',),True),
    'crossing-boundaries':('crossing',3,('--source-boundaries',),True),
    'crossing-csv0':('crossing',0,(),False),
}


def main():
    parser=argparse.ArgumentParser()
    for key in ('reference-work','output'):parser.add_argument('--'+key,type=Path,required=True)
    parser.add_argument('--optimization',choices=('O0','O2'),required=True)
    parser.add_argument('--reuse-pilots',type=Path)
    parser.add_argument('--resume',action='store_true')
    args=parser.parse_args();args.output=args.output.resolve();args.output.mkdir(exist_ok=args.resume)
    import user_prepare
    if not (args.reference_work/'PREPARED.json').exists():user_prepare.prepare(args.reference_work)
    user_prepare.validate(args.reference_work);shutil.copyfile(args.reference_work/'PREPARED.json',args.output/'PROVIDER.json')
    record=dict(status='RUNNING',source_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=runtime.ROOT,text=True).strip(),
                optimization=args.optimization,cases={},controls={},functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED')
    if args.resume:record['retained_previous_report']=json.loads((args.output/'RESULT.json').read_text())
    def save():(args.output/'RESULT.json').write_text(json.dumps(record,indent=2)+'\n',encoding='utf8')
    def invoke(script,*options):
        subprocess.run([sys.executable,'-B',str(Path(__file__).with_name(script)),*map(str,options)],cwd=runtime.ROOT,check=True,timeout=1800)
    save()
    try:
        for name,(kind,fmt,extra,full_selected) in CASES.items():
            short=args.output/('short-'+name)
            pilot={'within-csv3':'within','below-csv1':'below','crossing-csv3':'crossing'}.get(name)
            if args.reuse_pilots and pilot:short=args.reuse_pilots/f'groundwater-chemical-{pilot}-{args.optimization}-v4'
            options=['--reference-work',args.reference_work,'--optimization',args.optimization,'--kind',kind,'--format',fmt,*extra]
            if not (short/'RESULT.json').exists():invoke('groundwater_chemical_runtime.py',*options,'--output',short)
            report=json.loads((short/'RESULT.json').read_text());assert report['status']=='ACTUAL_PRESCRIBED_GROUNDWATER_CDE_SHORT_NATIVE_USER_FILES_PASS'
            build=Path(report.get('build_root',short/'build'));inputs=Path(report.get('input_root',short/'input'))
            project=runtime.m.e.load(inputs,original_output='--compatibility-output' not in extra)
            runtime.m.validate_bundle(build,args.reference_work,project)
            record['cases'][name]=dict(short_root=str(short),build_root=str(build),input_root=str(inputs),short=report);save()
            if name in ('crossing-csv3','crossing-default','crossing-sorption-decay'):
                target=args.output/('controls-'+name)
                if args.reuse_pilots and name=='crossing-csv3':target=args.reuse_pilots/f'groundwater-chemical-controls-{args.optimization}-v1'
                if not (target/'RESULT.json').exists():invoke('groundwater_chemical_controls.py','--reference-work',args.reference_work,'--profile-root',short,'--output',target)
                control=json.loads((target/'RESULT.json').read_text())
                assert control['status']=='PRESCRIBED_GROUNDWATER_ACTUAL_NATIVE_ACTIVE_AND_REPORTED_REFUSALS_PASS'
                assert control['build_sha256']==runtime.m.sha(build/'BUILD.json')
                record['controls'][name]=dict(root=str(target),report=control);save()
            if full_selected:
                target=args.output/('full-'+name)
                if args.reuse_pilots and name=='crossing-csv3':target=args.reuse_pilots/f'groundwater-chemical-crossing-full-{args.optimization}-v1'
                if not (target/'RESULT.json').exists():invoke('groundwater_chemical_runtime.py',*options,'--phase','full','--reuse-build',build,'--existing-input',inputs,'--output',target)
                full=json.loads((target/'RESULT.json').read_text());assert full['status']=='ACTUAL_PRESCRIBED_GROUNDWATER_CDE_FULL_NATIVE_USER_FILES_PASS'
                assert full['trajectory']['build_sha256']==runtime.m.sha(build/'BUILD.json')
                record['cases'][name]['full_root']=str(target);record['cases'][name]['full']=full;save()
            print(name,args.optimization,'ACTUAL_GROUNDWATER_CDE_SELECTED_PERIOD_NATIVE_PASS',flush=True)
        left=runtime.m.rows(Path(record['cases']['crossing-csv3']['short_root'])/'trajectory')
        right=runtime.m.rows(Path(record['cases']['crossing-csv0']['short_root'])/'trajectory')
        assert runtime.m.physical(left)==runtime.m.physical(right)
        record['format_independence_ten_physical_days_exact']=True
        record['status']='EIGHT_GROUNDWATER_CDE_SHORT_SEVEN_FULL_AND_THREE_NATIVE_TRANSACTION_CONTEXTS_PASS'
    except Exception as error:record.update(status='FAILED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
