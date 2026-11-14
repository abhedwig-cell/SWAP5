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
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--prior',type=Path,required=True);p.add_argument('--output',type=Path,required=True);args=p.parse_args()
    prior=args.prior.resolve();out=args.output.resolve();out.mkdir(parents=True,exist_ok=False)
    bundle=prior/'harmonic-mean-O2-build';ref=prior/'provider';project=e.load(prior/'input-harmonic-mean')
    meta,case=validate_bundle(bundle,ref,project)
    assert h.sha(Path(shutil.which('gfortran')))==meta['identity']['compiler_sha256']
    for name in ('day_donor','day_kernel'):h.executable(bundle,name).chmod(0o755)
    warmdir=out/'warm';warmdir.mkdir();rows=[]
    with contextlib.ExitStack() as stack:
        stream=stack.enter_context((out/'warm.jsonl').open('w'))
        warm=h.DailyHost(stack,h.executable(bundle,'day_donor'),h.executable(bundle,'day_kernel'),case,warmdir,
            [h.ColumnStart(name='original')],runtime=True,checkpoint_enabled=True,binding=meta['binding'],project=project)
        for day in range(1,589):
            row=warm.step(1,checkpoint=day==588);assert row['committed'];rows.append(row);stream.write(json.dumps(row)+'\n')
        origin=warmdir/'accepted-column-1-day-588.zip';digest=h.sha(origin)
        stocks=warm.columns[0].stocks.copy();rejected=warm.step(1,checkpoint=True)
        stream.write(json.dumps(rejected)+'\n');stream.flush()
        assert not rejected['committed'] and rejected['day']==589
        assert 9e-9<abs(rejected['independent_residual_cm'])<1.1e-8
        assert warm.columns[0].day==588 and warm.columns[0].stocks==stocks
        assert not (warmdir/'accepted-column-1-day-589.zip').exists() and h.sha(origin)==digest
        warm.close()
    restored=out/'verified-origin';receipt=h.verify_checkpoint(origin,588,meta['binding'],restored)
    cold=out/'cold';cold.mkdir()
    with contextlib.ExitStack() as stack:
        host=h.DailyHost(stack,h.executable(bundle,'day_donor'),h.executable(bundle,'day_kernel'),case,cold,
            [h.ColumnStart(day=588,origin=restored,receipt=receipt,name='original')],runtime=True,checkpoint_enabled=True,binding=meta['binding'],project=project)
        stock=host.columns[0].stocks.copy();again=host.step(1,checkpoint=True)
        assert physical(again)==physical(rejected)
        assert host.columns[0].day==588 and host.columns[0].stocks==stock
        assert not list(cold.glob('accepted-*.zip')) and h.sha(origin)==digest
        host.close()
    result=dict(status='ORIGINAL_HARMONIC589_REFUSAL_REPRODUCED_NO_COMMIT',source_commit=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),
        original_run=43590665680,source_build=meta['identity'],accepted_days=588,refusal_day=589,refused=rejected,
        own588_restart_exact_refusal=True,no_rejected_publication=True,origin_unchanged=True,whole_period_pass=False,
        science='NOT_QUALIFIED; no tolerance or Richards repair')
    (out/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n');print(result['status'],flush=True)

if __name__=='__main__':main()
