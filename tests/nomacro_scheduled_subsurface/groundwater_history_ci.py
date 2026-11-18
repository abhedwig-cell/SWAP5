"""Representative original groundwater CDE histories with complete native ownership."""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import sys
import zipfile
import groundwater_history_runtime as runtime

# Actual hysteresis, snow, output format, groundwater table, explicit fixture options, full.
CASES={}
for hys,snow in ((1,0),(2,0),(0,1),(1,1),(2,1)):
    for original in (True,False):
        key=f'hys{hys}-snow{snow}-'+('original' if original else 'default')
        CASES[key]=(hys,snow,3 if original else 1,'crossing',() if original else ('--compatibility-output',),True)
CASES.update({
    'hys1-heat0-drain0-et1-default':(1,0,1,'crossing',('--compatibility-output','--heat','0','--drainage','0','--et','1','--oxygen','1'),True),
    'hys1-below':(1,0,3,'below',(),True),
    'hys2-snow1-chemistry-bbc':(2,1,2,'crossing',('--chemistry','--boundary-file'),True),
    'hys2-snow1-first-year-terminal-default':(2,1,1,'crossing',('--compatibility-output','--source-boundaries'),True),
    'hys2-snow1-csv0':(2,1,0,'crossing',(),False),
    'hys1-snow1-et1':(1,1,2,'crossing',('--et','1'),False),
})
CONTROLS=tuple(list(CASES)[:10])+('hys1-heat0-drain0-et1-default','hys1-snow1-et1')


def main():
    parser=argparse.ArgumentParser()
    for key in ('reference-work','output'):parser.add_argument('--'+key,type=Path,required=True)
    parser.add_argument('--optimization',choices=('O0','O2'),required=True)
    parser.add_argument('--reuse-pilots',type=Path);parser.add_argument('--resume',action='store_true')
    args=parser.parse_args();args.output=args.output.resolve();args.output.mkdir(exist_ok=args.resume)
    import user_prepare
    if not (args.reference_work/'PREPARED.json').exists():user_prepare.prepare(args.reference_work)
    user_prepare.validate(args.reference_work);shutil.copyfile(args.reference_work/'PREPARED.json',args.output/'PROVIDER.json')
    record=dict(status='RUNNING',source_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=runtime.ROOT,text=True).strip(),optimization=args.optimization,
        cases={},controls={},functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED')
    if args.resume:record['retained_previous_report']=json.loads((args.output/'RESULT.json').read_text())
    def save():(args.output/'RESULT.json').write_text(json.dumps(record,indent=2)+'\n',encoding='utf8')
    def invoke(script,*options):subprocess.run([sys.executable,'-B',str(Path(__file__).with_name(script)),*map(str,options)],cwd=runtime.ROOT,check=True,timeout=1800)
    reuse={'hys1-snow0-original':f'groundwater-history-hys1-snow0-{args.optimization}-v1',
           'hys0-snow1-original':f'groundwater-history-hys0-snow1-{args.optimization}-v1',
           'hys2-snow1-original':f'groundwater-history-hys2-snow-{args.optimization}-v1',
           'hys1-heat0-drain0-et1-default':f'groundwater-history-hys1-heat0-drain0-et1-default-{args.optimization}-v2'}
    save()
    try:
        for key,(hys,snow,fmt,kind,extra,full_selected) in CASES.items():
            short=args.output/('short-'+key)
            if args.reuse_pilots and key in reuse:short=args.reuse_pilots/reuse[key]
            options=['--reference-work',args.reference_work,'--optimization',args.optimization,'--hysteresis',hys,'--snow',snow,'--format',fmt,'--kind',kind,*extra]
            if not (short/'RESULT.json').exists():invoke('groundwater_history_runtime.py',*options,'--output',short)
            report=json.loads((short/'RESULT.json').read_text());assert report['status']=='ACTUAL_GROUNDWATER_CDE_HISTORY_SHORT_COMPOUND_NATIVE_USER_FILES_PASS'
            assert (report['hysteresis'],report['snow'],report['format'],report['kind'],report['optimization'])==(hys,snow,fmt,kind,args.optimization)
            build=Path(report['build_root']);inputs=Path(report['input_root']);project=runtime.m.e.load(inputs,original_output='--compatibility-output' not in extra)
            meta,_=runtime.m.validate_bundle(build,args.reference_work,project)
            assert meta['identity']['groundwater_native_state']==report['native'] and report['native']['domain_bytes']==104
            record['cases'][key]=dict(short_root=str(short),input_root=str(inputs),build_root=str(build),short=report);save()
            if key in CONTROLS:
                target=args.output/('controls-'+key)
                if args.reuse_pilots and key=='hys2-snow1-original':target=args.reuse_pilots/f'groundwater-history-controls-hys2-snow-{args.optimization}-v1'
                if not (target/'RESULT.json').exists():invoke('groundwater_history_controls.py','--reference-work',args.reference_work,'--profile-root',short,'--output',target)
                control=json.loads((target/'RESULT.json').read_text())
                assert control['status']=='GROUNDWATER_HISTORY_ACTUAL_NATIVE_ACTIVE_AND_REPORTED_REFUSALS_PASS' and control['build_sha256']==runtime.m.sha(build/'BUILD.json')
                record['controls'][key]=dict(root=str(target),report=control);save()
            if full_selected:
                target=args.output/('full-'+key)
                if not (target/'RESULT.json').exists():invoke('groundwater_history_runtime.py',*options,'--phase','full','--reuse-build',build,'--existing-input',inputs,'--output',target)
                full=json.loads((target/'RESULT.json').read_text());assert full['status']=='ACTUAL_GROUNDWATER_CDE_HISTORY_FULL_COMPOUND_NATIVE_USER_FILES_PASS'
                assert full['trajectory']['build_sha256']==runtime.m.sha(build/'BUILD.json')
                record['cases'][key].update(full_root=str(target),full=full);save()
            print(key,args.optimization,'ACTUAL_GROUNDWATER_HISTORY_SELECTED_PERIOD_NATIVE_PASS',flush=True)
        left=Path(record['cases']['hys2-snow1-original']['short_root'])/'trajectory';right=Path(record['cases']['hys2-snow1-csv0']['short_root'])/'trajectory'
        assert runtime.m.physical(runtime.m.rows(left))==runtime.m.physical(runtime.m.rows(right))
        for day in (4,8,23,34,35):
            with zipfile.ZipFile(left/f'accepted-column-1-day-{day}.zip') as a,zipfile.ZipFile(right/f'accepted-column-1-day-{day}.zip') as b:
                for member in ('result.end','macro.bin'):assert a.read(member)==b.read(member),member
        assert runtime.m.physical(runtime.m.rows(Path(record['cases']['hys0-snow1-original']['short_root'])/'trajectory'))!=runtime.m.physical(runtime.m.rows(left))
        record['format_independence']=dict(all35_physical_days_exact=True,five_complete_native_payloads_exact=True)
        record['actual_hysteresis_changes_physical_trajectory']=True
        record['status']='SIXTEEN_GROUNDWATER_HISTORY_SHORT_FOURTEEN_FULL_TWELVE_NATIVE_CONTEXTS_PASS'
    except Exception as error:record.update(status='FAILED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
