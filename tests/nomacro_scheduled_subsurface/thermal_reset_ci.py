"""Scoped original Snow calendars; all short/native gates precede full periods."""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import sys
import zipfile
import thermal_reset_runtime as runtime

# Mode, hysteresis, format, cumulative reset, ET selector, full-period selection.
CASES={
    'explicit-hys2-binary':('explicit',2,3,1,0,True),
    'periodic-hys1-vector':('periodic',1,2,1,0,True),
    'terminal-hys0-ascii':('terminal',0,1,1,0,True),
    'explicit-hys1-ascii':('explicit',1,1,1,0,True),
    'periodic-hys0-cumulative-et1':('periodic',0,1,1,1,False),
    'terminal-hys2-binary':('terminal',2,3,1,0,False),
    'explicit-hys0-none':('explicit',0,0,1,0,False),
    'periodic-hys2-vector':('periodic',2,2,1,0,False),
}
CONTROLS=tuple(key for key,case in CASES.items() if case[-1])

def main():
    p=argparse.ArgumentParser()
    for key in ('reference-work','output'):p.add_argument('--'+key,type=Path,required=True)
    p.add_argument('--optimization',choices=('O0','O2'),required=True);p.add_argument('--reuse-pilots',type=Path);p.add_argument('--resume',action='store_true')
    a=p.parse_args();a.output=a.output.resolve();a.output.mkdir(exist_ok=a.resume)
    import user_prepare
    if not (a.reference_work/'PREPARED.json').exists():user_prepare.prepare(a.reference_work)
    user_prepare.validate(a.reference_work);shutil.copyfile(a.reference_work/'PREPARED.json',a.output/'PROVIDER.json')
    q=dict(status='RUNNING',source_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=runtime.ROOT,text=True).strip(),optimization=a.optimization,
        cases={},controls={},functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED')
    if a.resume:q['retained_previous_report']=json.loads((a.output/'RESULT.json').read_text())
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n',encoding='utf8')
    def invoke(script,*options):subprocess.run([sys.executable,'-B',str(Path(__file__).with_name(script)),*map(str,options)],cwd=runtime.ROOT,check=True,timeout=600)
    save()
    try:
        for key,(mode,hys,fmt,reset,et,full) in CASES.items():
            short=a.output/('short-'+key)
            if a.reuse_pilots and key=='explicit-hys2-binary':short=a.reuse_pilots/f'thermal-reset-explicit-{a.optimization}-v1'
            options=['--reference-work',a.reference_work,'--mode',mode,'--hysteresis',hys,'--format',fmt,'--reset',reset,'--et',et,'--optimization',a.optimization]
            if not (short/'RESULT.json').exists():invoke('thermal_reset_runtime.py',*options,'--output',short)
            report=json.loads((short/'RESULT.json').read_text());assert report['status']=='ACTUAL_WATER_SNOW_FLPRINTDT_RESET_SHORT_NATIVE_USER_OUTPUT_PASS'
            assert (report['mode'],report['hysteresis'],report['format'],report['reset'],report['et'],report['optimization'])==(mode,hys,fmt,reset,et,a.optimization)
            inputs=Path(report['input_root']);build=Path(report['build_root']);project=runtime.m.e.load(inputs,original_output=True)
            meta,_=runtime.m.validate_bundle(build,a.reference_work,project);assert meta['identity']['original_output']==report['original_output']
            q['cases'][key]=dict(short_root=str(short),input_root=str(inputs),build_root=str(build),short=report);save()
            if key in CONTROLS:
                target=a.output/('controls-'+key)
                if a.reuse_pilots and key=='explicit-hys2-binary':target=a.reuse_pilots/f'thermal-reset-controls-explicit-{a.optimization}-v1'
                if not (target/'RESULT.json').exists():invoke('thermal_reset_controls.py','--reference-work',a.reference_work,'--profile-root',short,'--output',target)
                control=json.loads((target/'RESULT.json').read_text());assert control['status']=='WATER_SNOW_FLPRINTDT_RESET_SIXTY_THREE_NATIVE_ACTIVE_AND_POLICY_REFUSALS_PASS'
                assert control['build_sha256']==runtime.m.sha(build/'BUILD.json') and len(control['native_refusals'])==63
                q['controls'][key]=dict(root=str(target),report=control);save()
            print(key,a.optimization,'ACTUAL_SHORT_CALENDAR_SOURCE_NATIVE_PASS',flush=True)
        q['all_short_and_native_gates_precede_full']=True;save()
        for key,case in CASES.items():
            if not case[-1]:continue
            mode,hys,fmt,reset,et,_=case;item=q['cases'][key];target=a.output/('full-'+key)
            options=['--reference-work',a.reference_work,'--mode',mode,'--hysteresis',hys,'--format',fmt,'--reset',reset,'--et',et,'--optimization',a.optimization]
            if not (target/'RESULT.json').exists():invoke('thermal_reset_runtime.py',*options,'--phase','full','--reuse-build',item['build_root'],'--existing-input',item['input_root'],'--output',target)
            full=json.loads((target/'RESULT.json').read_text());assert full['status']=='ACTUAL_WATER_SNOW_FLPRINTDT_RESET_FULL_NATIVE_USER_OUTPUT_PASS'
            assert full['trajectory']['build_sha256']==runtime.m.sha(Path(item['build_root'])/'BUILD.json')
            if fmt:
                for observed in full['user_output'].values():assert observed['stamps'][-1]=='2005-01-01 00:00:00',observed
            item.update(full_root=str(target),full=full);save();print(key,a.optimization,'ACTUAL_FULL_CALENDAR_SOURCE_NATIVE_PASS',flush=True)
        left=Path(q['cases']['monthly-hys2-binary']['short_root'])/'trajectory';right=Path(q['cases']['monthly-hys2-none']['short_root'])/'trajectory'
        assert runtime.m.physical(runtime.m.rows(left))==runtime.m.physical(runtime.m.rows(right))
        for day in (4,8,23,34,35):
            with zipfile.ZipFile(left/f'accepted-column-1-day-{day}.zip') as a0,zipfile.ZipFile(right/f'accepted-column-1-day-{day}.zip') as b:
                for name in ('result.end','macro.bin'):assert a0.read(name)==b.read(name),name
        q['format_independence']=dict(all35_physical_days_exact=True,five_complete_native_payloads_exact=True)
        q['status']='EIGHT_WATER_SNOW_FLPRINTDT_RESET_SHORT_FOUR_FULL_FOUR_NATIVE_CONTEXTS_PASS'
    except Exception as error:q.update(status='FAILED',error=repr(error));raise
    finally:save()

if __name__=='__main__':main()
