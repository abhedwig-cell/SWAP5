"""Real bounded calendar trajectories, original budgets and exact native cold seams."""
import argparse,hashlib,json,math,struct,subprocess,sys,zipfile
from pathlib import Path
R=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(R/'app/hybrid_water'),str(R/'tests/nomacro_scheduled_subsurface')]
from explicit_bottom9_runtime import m,own
from frost_calendar_output import metadata
from frost_calendar_state import selection as input_selection
from frost_calendar_state_probe import budgets
from frost_history_state_central import original_history
from frost_analytical_composition import native_domain


def snapshots(folder,meta,data,selected,days):
    result=[];expected_magic=meta['identity']['original_output']['native_codec'].encode();nodes=meta['project']['nodes'];solute=int(selected['kind']=='cde');hys=selected['hysteresis']
    for day in sorted(days):
        with zipfile.ZipFile(folder/f'accepted-column-1-day-{day}.zip') as z:
            q=json.loads(z.read('checkpoint.json'));assert q['binding']==meta['binding'] and q['receipt']==data[day-1]
            assert all(hashlib.sha256(z.read(name)).hexdigest()==value for name,value in q['files'].items())
            raw=z.read('macro.bin');assert raw[:8]==expected_magic
            native_domain(raw,selected,nodes)
            thermal=struct.pack('<10i',1,nodes,0,solute,hys,1,1,0,1,2);assert raw.count(thermal+thermal)==1
            header=struct.pack('<4i',1,nodes,solute,7);assert raw.count(header+header)==1
            at=raw.index(header+header)+32;snow=struct.unpack_from('<7d',raw,at);assert all(math.isfinite(value) and value>=0 for value in snow)
            if solute:
                n=20+nodes;header=struct.pack('<3i',2,nodes,n);assert raw.count(header+header)==1;at=raw.index(header+header)+24;values=struct.unpack_from('<'+str(2*n)+'d',raw,at);assert values[:n]==values[n:] and all(map(math.isfinite,values))
            if selected['implicit']:
                header=(5,nodes,solute,1,hys,selected['bottom'],1,0);assert struct.unpack('<16i',raw[-96:-32])==header+header;values=struct.unpack('<4d',raw[-32:]);assert values[:2]==values[2:] and all(map(math.isfinite,values))
            original=original_history(z.read('result.end'),selected['kind'],hys)
        result.append(dict(day=day,snow_output_totals=list(snow),original=original,original_private_cde_version=2 if solute else None))
    return result


def main():
    p=argparse.ArgumentParser()
    for name in ('build-record','reference-work','output'):p.add_argument('--'+name,type=Path,required=True)
    p.add_argument('--days',type=int,required=True);p.add_argument('--year-seam',action='store_true');a=p.parse_args();assert a.days in (8,12,35);a.output.mkdir()
    report=json.loads(a.build_record.read_text());assert report['returncode']==0
    git=lambda *args:subprocess.check_output(['git',*args],cwd=R)
    head=git('rev-parse','HEAD').decode().strip();assert not git('diff',report['actual_source'],head,'--','app','src','tools','reference')
    project=m.e.load(report['input_root'],original_output=True,time_step_policy='original-adaptive-event-closure-v1');build=Path(report['build_root']);meta,_=m.validate_bundle(build,a.reference_work,project);selected=input_selection(project.input_directory,True);assert selected and selected.get('analytical_frost_models') and selected['drainage']==0 and selected['implicit']==selected['hysteresis']==0
    windows=[(2,4),(19,23),(30,34)] if a.days==35 else [(2,a.days)]
    if a.year_seam:
        if a.days==35:windows.append((15,19))
        else:windows.append((5,9))
    cuts={a.days}|{x for pair in windows for x in pair}
    q=dict(status='RUNNING_ACTUAL_ANALYTICAL_FROST_CALENDAR_NOT_QUALIFIED',source=report['actual_source'],actual_controller_source=head,build_root=str(build),input_root=report['input_root'],kind=selected['kind'],duration_days=a.days,selection=selected,output=metadata(project),compiler_executions=0,canonical_admission=False)
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
    save()
    try:
        q['trajectory'],data=m.trajectory(build,a.reference_work,project,a.output/'trajectory',a.days,cuts,240);save()
        q['independent_original_budgets']=budgets(a.output/'trajectory',selected['kind'],a.days);save()
        q['own']=[]
        for start,end in windows:q['own'].append(own(build,a.reference_work,project,a.output/'trajectory',data,start,end,a.output/('own-'+str(start))));save()
        q['native_samples']=snapshots(a.output/'trajectory',meta,data,selected,cuts)
        assert git('rev-parse','HEAD').decode().strip()==head
        q['status']='ACTUAL_ANALYTICAL_FROST_CALENDAR_ORIGINAL_BUDGETS_NATIVE_MODEL_HISTORY_COLD_AND_USER_OUTPUT_PASS_NOT_ADMITTED'
    except Exception as error:q.update(status='FAILED_ACTUAL_ANALYTICAL_FROST_CALENDAR_NOT_QUALIFIED',error=repr(error));raise
    finally:save()
    print(q['status'],a.days,selected['kind'],flush=True)


if __name__=='__main__':main()
