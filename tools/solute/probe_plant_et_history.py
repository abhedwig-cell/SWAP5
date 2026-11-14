"""Read-only original plant/ET history discriminator; no accepted publication."""
import argparse,contextlib,json,shutil,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/'app/hybrid_water'))
import daily_host as h
import experimental_project as e
from daily_coupling import validate_bundle
from check_nomacro_coverage import physical

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--prior',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
    prior=a.prior.resolve();out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
    base=prior/'factor-partition-soil-O2-build';ref=prior/'provider';project=e.load(prior/'input-factor-partition-soil')
    meta,case=validate_bundle(base,ref,project);identity=meta['identity']
    assert h.sha(Path(shutil.which('gfortran')))==identity['compiler_sha256']
    source=prior/'factor-partition-soil-O2-control/accepted-column-1-day-365.zip';digest=h.sha(source)
    origin=out/'verified-origin';receipt=h.verify_checkpoint(source,365,meta['binding'],origin)
    target=out/'private-carrier';shutil.copytree(base,target);(target/'BUILD.json').rename(target/'CARRIER_BUILD.json')
    main=target/'swap_main.f90';assert h.sha(main)==identity['donor_generated']['swap_main.f90']
    text=main.read_text(encoding='cp1252')
    text=h.replace(text,'use MOD_grid, only: numnod','use MOD_grid, only: numnod\nuse plant_interface,only:icrop,swcf,cf,ch,albedo,rsc,rsw,kdif,kdir,vcover,co2,fco2amax,fco2eff,fco2tra,fl_cropemergence')
    text=h.replace(text,'t1900, flrunend, h, gwl, qbot','t1900, flrunend, h, gwl, qbot, cfbs')
    trace="write(*,'(a,2(1x,i0),14(1x,es25.17e3),1x,l1)') 'DIAG_PLANT_ET',icrop,swcf,t1900,cfbs,cf,ch,albedo,rsc,rsw,kdif,kdir,vcover,co2,fco2amax,fco2eff,fco2tra,fl_cropemergence\n"
    for anchor in ["   write(*,'(a,1x,f16.8)') 'HYBRID_READY', t1900", "      write(*,'(a,i0,1x,f18.8)') 'HYBRID_DAY_RETURN ', window, t1900"]:
        text=h.replace(text,anchor,trace+anchor)
    main.write_text(text,encoding='cp1252')
    for name in ('day_donor','day_kernel'):h.executable(target,name).chmod(0o755)
    objects=ref/'build/swap-obj';ttutil=ref/'build/ttutil-obj'
    replacements={Path(name).with_suffix('.o').name:target/Path(name).with_suffix('.o').name for name in identity['donor_generated']}
    commands=[['gfortran',*identity['donor_flags'],'-I',str(objects),'-I',str(ttutil),'-c','swap_main.f90'],
        ['gfortran','-o',str(h.executable(target,'day_donor')),*[str(replacements.get(p.name,p)) for p in sorted(objects.glob('*.o'))],str(target/'hybrid_step_budget.o'),str(ttutil/'libttutil.a')]]
    logs=[]
    for command in commands:
        r=subprocess.run(command,cwd=target,capture_output=True,text=True,timeout=90);logs.append(dict(command=command,returncode=r.returncode,stdout=r.stdout,stderr=r.stderr));assert r.returncode==0,r.stderr
    (out/'COMPILATION.json').write_text(json.dumps(logs,indent=2)+'\n')
    records={}
    for label,start,last in [('warm',h.ColumnStart(name='original'),366),('cold',h.ColumnStart(day=365,origin=origin,receipt=receipt,name='original'),1)]:
        model=out/label;model.mkdir();rows=[]
        with contextlib.ExitStack() as stack:
            host=h.DailyHost(stack,h.executable(target,'day_donor'),h.executable(target,'day_kernel'),case,model,[start],runtime=True,checkpoint_enabled=True,project=project)
            for _ in range(last):rows.append(host.step(1))
            host.close()
        assert not list(model.glob('accepted-*.zip'))
        lines=[line.split()[1:] for line in (model/'original/donor.stdout').read_text().splitlines() if line.startswith('DIAG_PLANT_ET ')]
        records[label]=dict(last_row=rows[-1],initial_plant_et=lines[0],terminal_plant_et=lines[-1],accepted365_plant_et=lines[-2] if label=='warm' else None)
    original_warm=[json.loads(line) for line in (prior/'factor-partition-soil-O2-control/daily.jsonl').read_text().splitlines()][365]
    original_cold=json.loads((prior/'factor-partition-soil-O2-resumed/daily.jsonl').read_text().splitlines()[0])
    assert physical(records['warm']['last_row'])==physical(original_warm)
    assert physical(records['cold']['last_row'])==physical(original_cold)
    assert h.sha(source)==digest
    result=dict(status='READ_ONLY_ORIGINAL_PLANT_ET_HISTORY_REPRODUCED',source_commit=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),
        original_run=43593959340,origin_sha256=digest,no_publication=True,origin_unchanged=True,
        trace_fields=['icrop','swcf','t1900','cfbs','cf','ch','albedo','rsc','rsw','kdif','kdir','vcover','co2','fco2amax','fco2eff','fco2tra','fl_cropemergence'],
        private_source_sha256=h.sha(main),private_executable_sha256=h.sha(h.executable(target,'day_donor')),records=records,science='NOT_QUALIFIED')
    (out/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n');print(result['status'],flush=True)

if __name__=='__main__':main()
