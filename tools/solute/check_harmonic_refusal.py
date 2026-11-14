"""Preserve actual original harmonic589 refusal and its own restart, no repair."""
import argparse,contextlib,json,shutil,sys,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'app/hybrid_water'))
import daily_host as h
import experimental_project as e
from daily_coupling import validate_bundle
from check_nomacro_coverage import physical

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--prior',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--weighted',action='store_true');args=p.parse_args()
    prior=args.prior.resolve();out=args.output.resolve();out.mkdir(parents=True,exist_ok=False)
    reports=[]
    key='weighted-harmonic-mean' if args.weighted else 'harmonic-mean'
    for opt in (['O0','O2'] if args.weighted else ['O2']):
        target=out/opt;target.mkdir()
        reports.append(exercise(prior,target,key,opt,args.weighted))
    (out/'RESULT.json').write_text(json.dumps(dict(status='RETAINED_HARMONIC_REFUSALS_QUALIFIED',profiles=reports,science='NOT_QUALIFIED'),indent=2)+'\n')


def exercise(prior,out,key,opt,weighted):
    failure_day=367 if weighted else 589
    minimum,maximum=(1e-10,1.1e-10) if weighted else (9e-9,1.1e-8)
    bundle=prior/(key+'-'+opt+'-build');ref=prior/'provider';project=e.load(prior/('input-'+key))
    if not bundle.exists():
        bundle=out/'fresh-build'
        command=[sys.executable,'-B',str(ROOT/'tools/solute/run_water.py'),'--model',e.MODEL,'--experimental-project',project.input_directory,'--reference-work',str(ref),'--build-only','--output',str(bundle),'--donor-opt',opt,'--kernel-opt',opt]
        built=subprocess.run(command,capture_output=True,text=True,timeout=90);(out/'build.log').write_text(built.stdout+built.stderr);assert built.returncode==0
    meta,case=validate_bundle(bundle,ref,project)
    assert h.sha(Path(shutil.which('gfortran')))==meta['identity']['compiler_sha256']
    for name in ('day_donor','day_kernel'):h.executable(bundle,name).chmod(0o755)
    warmdir=out/'warm';warmdir.mkdir();rows=[]
    with contextlib.ExitStack() as stack:
        stream=stack.enter_context((out/'warm.jsonl').open('w'))
        warm=h.DailyHost(stack,h.executable(bundle,'day_donor'),h.executable(bundle,'day_kernel'),case,warmdir,
            [h.ColumnStart(name='original')],runtime=True,checkpoint_enabled=True,binding=meta['binding'],project=project)
        for day in range(1,failure_day):
            row=warm.step(1,checkpoint=day==failure_day-1);assert row['committed'];rows.append(row);stream.write(json.dumps(row)+'\n')
        origin=warmdir/f'accepted-column-1-day-{failure_day-1}.zip';digest=h.sha(origin)
        stocks=warm.columns[0].stocks.copy();rejected=warm.step(1,checkpoint=True)
        stream.write(json.dumps(rejected)+'\n');stream.flush()
        assert not rejected['committed'] and rejected['day']==failure_day
        assert minimum<abs(rejected['independent_residual_cm'])<maximum
        assert warm.columns[0].day==failure_day-1 and warm.columns[0].stocks==stocks
        assert not (warmdir/f'accepted-column-1-day-{failure_day}.zip').exists() and h.sha(origin)==digest
        warm.close()
    restored=out/'verified-origin';receipt=h.verify_checkpoint(origin,failure_day-1,meta['binding'],restored)
    cold=out/'cold';cold.mkdir()
    with contextlib.ExitStack() as stack:
        host=h.DailyHost(stack,h.executable(bundle,'day_donor'),h.executable(bundle,'day_kernel'),case,cold,
            [h.ColumnStart(day=failure_day-1,origin=restored,receipt=receipt,name='original')],runtime=True,checkpoint_enabled=True,binding=meta['binding'],project=project)
        stock=host.columns[0].stocks.copy();again=host.step(1,checkpoint=True)
        assert physical(again)==physical(rejected)
        assert host.columns[0].day==failure_day-1 and host.columns[0].stocks==stock
        assert not list(cold.glob('accepted-*.zip')) and h.sha(origin)==digest
        host.close()
    result=dict(status='ORIGINAL_HARMONIC_REFUSAL_REPRODUCED_NO_COMMIT',source_commit=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),
        original_run=43591575148 if weighted else 43590665680,source_build=meta['identity'],configuration=key,optimization=opt,accepted_days=failure_day-1,refusal_day=failure_day,refused=rejected,
        own_restart_exact_refusal=True,no_rejected_publication=True,origin_unchanged=True,whole_period_pass=False,
        science='NOT_QUALIFIED; no tolerance or Richards repair')
    (out/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n');print(result['status'],opt,flush=True)
    return result

if __name__=='__main__':main()
