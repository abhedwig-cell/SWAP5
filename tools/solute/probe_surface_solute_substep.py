"""Read-only paired CDE-floor discriminator from a sealed refused surface history.

No prepared BUILD or accepted checkpoint is rebound. Private binaries receive
an exact verified native origin, publish no checkpoint, and carry separate IDs.
"""
import argparse,contextlib,hashlib,json,math,re,shutil,subprocess,sys,zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/'app/hybrid_water'))
import daily_host as h
import experimental_project as e
import irrigation_forcing as ir


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--prior',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
    old=a.prior.resolve();out=a.output.resolve();out.mkdir()
    base=old/'solute-salt-O2-extended';reference=old/'provider';case=old/'input-solute-salt'
    meta=json.loads((base/'BUILD.json').read_text());identity=meta['identity'];project=e.load(case)
    assert identity['time_step_policy']==h.ORIGINAL_TIME_POLICY and identity['floating_point_profile']==h.no_macro_fp_profile()
    assert subprocess.check_output(['gfortran','-dumpmachine'],text=True).strip()==identity['target']
    assert h.sha(Path(shutil.which('gfortran')))==identity['compiler_sha256']
    assert h.sha(h.executable(base,'day_donor'))==meta['executable_sha256']['donor']
    rows=[json.loads(line) for line in (old/'solute-salt-O2-warm.jsonl').read_text().splitlines()]
    day=rows[-1]['day'];assert day==572
    source=old/f'solute-salt-O2-warm/accepted-column-1-day-{day}.zip';before=h.sha(source)
    origin=out/'verified-origin';receipt=h.verify_checkpoint(source,day,meta['binding'],origin)
    assert receipt==rows[-1]
    original=(base/'solute.f90').read_text(encoding='cp1252')
    assert h.sha(base/'solute.f90')==identity['donor_generated']['solute.f90']
    diagnostic=original.replace('            dtsolu  = max(dtsolu,dtmin)',
        "            if(dtsolu<dtmin)write(*,'(a,4(1x,es25.17e3))') 'DIAG_CDE_FLOOR',dt,dtmin,dtsolu,dt-tcumsol\n            dtsolu  = max(dtsolu,dtmin)",1)
    diagnostic=diagnostic.replace('               if (cmsy(i) < vsmall) then',
        "               if(cmsy(i)<0d0)write(*,'(a,1x,i0,4(1x,es25.17e3))') 'DIAG_CDE_NEGATIVE',i,cmsy(i)*dz(i),dt,dtmin,dtsolu\n               if (cmsy(i) < vsmall) then",1)
    assert diagnostic!=original
    candidate=diagnostic.replace('            dtsolu  = max(dtsolu,dtmin)',
        '            ! CDE substeps retain their own stability/remaining-time bound; no water-step floor.',1)
    reports=[]
    for name,source_text in [('unchanged-cde-observed',diagnostic),('independent-cde-substep',candidate)]:
        target=out/name;shutil.copytree(base,target);(target/'BUILD.json').rename(target/'CARRIER_BUILD.json')
        (target/'solute.f90').write_text(source_text,encoding='cp1252')
        for exe in ('day_donor','day_kernel'):h.executable(target,exe).chmod(0o755)
        objects=reference/'build/swap-obj';ttutil=reference/'build/ttutil-obj'
        commands=[['gfortran',*identity['donor_flags'],'-I',str(objects),'-I',str(ttutil),'-c','solute.f90']]
        replacements={Path(n).with_suffix('.o').name:target/Path(n).with_suffix('.o').name for n in identity['donor_generated']}
        commands.append(['gfortran','-o',str(h.executable(target,'day_donor')),
            *(str(replacements.get(f.name,f)) for f in sorted(objects.glob('*.o'))),str(target/'hybrid_step_budget.o'),str(ttutil/'libttutil.a')])
        logs=[]
        for command in commands:
            result=subprocess.run(command,cwd=target,capture_output=True,text=True,timeout=90)
            logs.append(dict(command=command,returncode=result.returncode,stdout=result.stdout,stderr=result.stderr));assert result.returncode==0,result.stderr
        (target/'COMPILATION.json').write_text(json.dumps(logs,indent=2)+'\n')
        private=target/'private-input';shutil.copytree(case,private)
        (private/ir.INPUT).write_text(f'S5IRR001 {project.start_clock+day} 0 0 0 0\n')
        model=target/'model';model.mkdir();budget=None;failure=None
        with contextlib.ExitStack() as stack:
            host=h.DailyHost(stack,h.executable(target,'day_donor'),h.executable(target,'day_kernel'),private,model,
                [h.ColumnStart(day=day,origin=origin,receipt=receipt,name='original')],runtime=True,checkpoint_enabled=True,project=project)
            try:
                budget=host.step(1);host.close()
            except (ValueError,RuntimeError) as error:
                failure=str(error)
                for proc in [host.host,*[c.worker for c in host.columns]]:
                    if proc.poll() is None:proc.kill()
        text=(model/'original/donor.stdout').read_text(encoding='cp1252');lines=text.splitlines()
        frames={}
        for tag in ('HYBRID_STOCK_FLUX','HYBRID_EXTERNAL_FLUX','HYBRID_HYDRAULIC','HYBRID_SOLUTE_LEDGER'):
            frames[tag]=list(map(float,[line for line in lines if line.startswith(tag+' ')][-1].split()[1:]))
        ledger=frames['HYBRID_SOLUTE_LEDGER'];end,delta,rain,irrig,bottom,drain,decay,root,reported=ledger
        independent=math.fsum([end,-receipt['solute_end_mg_cm2'],-rain,-irrig,-bottom,drain,decay,root])
        floors=[list(map(float,line.split()[1:])) for line in lines if line.startswith('DIAG_CDE_FLOOR ')]
        negatives=[list(map(float,line.split()[1:])) for line in lines if line.startswith('DIAG_CDE_NEGATIVE ')]
        record=dict(variant=name,private_only=True,accepted_checkpoint_published=False,origin_sha256=before,
            original_source_sha256=identity['donor_generated']['solute.f90'],source_sha256=h.sha(target/'solute.f90'),
            executable_sha256=h.sha(h.executable(target,'day_donor')),failure=failure,budget=budget,frames=frames,
            floors=floors,negative_clips=negatives,sum_negative_clipped_mg_cm2=math.fsum(v[1] for v in negatives),
            independent_solute_residual_mg_cm2=independent,reported_solute_residual_mg_cm2=reported)
        assert not list(model.glob('accepted-*.zip')) and h.sha(source)==before
        (target/'PRIVATE_VARIANT.json').write_text(json.dumps(record,indent=2)+'\n');reports.append(record)
        print(name,'residual',independent,'floors',len(floors),'negative',len(negatives),flush=True)
    baseline,trial=reports
    assert baseline['failure'] and abs(baseline['independent_solute_residual_mg_cm2'])>1e-10
    assert baseline['floors'] and baseline['negative_clips']
    passed=trial['failure'] is None and not trial['negative_clips'] and abs(trial['independent_solute_residual_mg_cm2'])<=1e-10
    result=dict(status='FOCUSED_HYPOTHESIS_SUPPORTED_NOT_FULL_QUALIFICATION' if passed else 'FOCUSED_HYPOTHESIS_REJECTED',
        source_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
        original_run=43583516947,refused_day=573,variants=reports,
        original_checkpoint_unchanged=True,no_publication=True,science='NOT_QUALIFIED')
    (out/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n')
    assert passed,'CDE floor hypothesis did not repair the actual refused day'


if __name__=='__main__':main()
