"""Complete only the censored O2 cold replay from its real immutable origin."""
import argparse,contextlib,json,shutil,sys,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'app/hybrid_water'))
import daily_host as h
import experimental_project as e
from daily_coupling import validate_bundle
from check_nomacro_coverage import physical

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--prior-proof',type=Path,required=True)
    p.add_argument('--prior-cohort',type=Path,required=True)
    p.add_argument('--output',type=Path,required=True)
    args=p.parse_args();out=args.output.resolve();out.mkdir(parents=True,exist_ok=False)
    carrier=args.prior_proof.resolve()/'O2';cohort=args.prior_cohort.resolve()
    bundle=carrier/'fresh-build';project=e.load(cohort/'input-constitutive-3')
    meta,case=validate_bundle(bundle,cohort/'provider',project)
    assert meta['identity']['donor_flags'][0]=='-O2'
    assert h.sha(Path(shutil.which('gfortran')))==meta['identity']['compiler_sha256']
    for name in ('day_donor','day_kernel'):h.executable(bundle,name).chmod(0o755)
    rows=[json.loads(s) for s in (carrier/'warm.jsonl').read_text().splitlines()]
    assert len(rows)==365 and all(r['committed'] for r in rows[:-1])
    refused=rows[-1];assert refused['day']==365 and not refused['committed']
    assert 1.1<abs(refused['independent_residual_cm'])<1.2
    origin=carrier/'warm/accepted-column-1-day-364.zip';digest=h.sha(origin)
    restored=out/'verified-origin';receipt=h.verify_checkpoint(origin,364,meta['binding'],restored)
    assert receipt['stock_end_cm']==rows[-2]['stock_end_cm']
    cold=out/'cold';cold.mkdir()
    with contextlib.ExitStack() as stack:
        host=h.DailyHost(stack,h.executable(bundle,'day_donor'),h.executable(bundle,'day_kernel'),case,cold,
            [h.ColumnStart(day=364,origin=restored,receipt=receipt,name='original')],runtime=True,
            checkpoint_enabled=True,binding=meta['binding'],project=project)
        stock=host.columns[0].stocks.copy();again=host.step(1,checkpoint=True)
        (out/'refused.json').write_text(json.dumps(again,indent=2)+'\n')
        assert physical(again)==physical(refused)
        assert host.columns[0].day==364 and host.columns[0].stocks==stock
        assert not list(cold.glob('accepted-*.zip')) and h.sha(origin)==digest
        host.close()
    result=dict(status='EXACT_OWN_O2_NATIVE_REFUSAL_NO_COMMIT',source_commit=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),
        carrier_source='30dc4d1e7579872db664b32b0b6fd1dbec599b14',carrier_run=43600305896,
        source_build=meta['identity'],origin_sha256=digest,warm_journal_sha256=h.sha(carrier/'warm.jsonl'),
        refusal_day=365,accepted_days=364,refused=again,own_restart_exact_refusal=True,
        no_rejected_publication=True,origin_unchanged=True,whole_period_pass=False,
        scope='Only missing cold replay resumed; existing bundle identity verified without rebinding; original strict FAIL retained')
    (out/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n');print(result['status'],flush=True)

if __name__=='__main__':main()
