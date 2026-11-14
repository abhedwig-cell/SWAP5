"""Exercise actual chemical retry and exact restart at O0, using its own build."""
import argparse,contextlib,json,os,subprocess,sys,zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'app/hybrid_water'))
import daily_host as h
import experimental_project as e
import irrigation_forcing as ir
from daily_coupling import CoupledDailyColumn,validate_bundle,SURFACE_IRRIGATION_FORCING
from check_nomacro_surface import event,physical,payload

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--prior',type=Path,required=True);parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args();prior=args.prior.resolve();out=args.output.resolve();out.mkdir(parents=True,exist_ok=False)
    ref=prior/'provider';bundle=prior/'solute-salt-O0-extended'
    project=e.load(prior/'input-solute-salt',solute_step_policy=h.TRANSACTIONAL_SOLUTE_STEP_POLICY)
    meta,case=validate_bundle(bundle,ref,project)
    identity=meta['identity'];assert '-O0' in identity['donor_flags'] and '-O0' in identity['kernel_flags']
    assert h.sha(Path(__import__('shutil').which('gfortran')))==identity['compiler_sha256']
    assert subprocess.check_output(['gfortran','-dumpmachine'],text=True).strip()==identity['target']
    # GitHub artifact transport omits executable permissions, not binary bytes.
    for name in ('day_donor','day_kernel'):h.executable(bundle,name).chmod(0o755)
    rows=[];cold=[];warmdir=out/'warm';warmdir.mkdir()
    with contextlib.ExitStack() as stack:
        warm=h.DailyHost(stack,h.executable(bundle,'day_donor'),h.executable(bundle,'day_kernel'),case,warmdir,
            [h.ColumnStart(name='original')],runtime=True,checkpoint_enabled=True,binding=meta['binding'],project=project)
        owner=None
        for day in range(1,576):
            depth,conc,rate,enabled=event(day,True)
            (warm.columns[0].directory/ir.INPUT).write_text(ir.project_protocol(project)+' '+' '.join(map(str,[project.start_clock+day-1,int(enabled),depth,conc,rate]))+'\n')
            row=warm.step(1,checkpoint=day>=572);rows.append(row)
            if day==573:
                origin=warmdir/'accepted-column-1-day-572.zip';origin_sha=h.sha(origin)
                owner=CoupledDailyColumn(bundle,ref,out/'external',project,'transactional-O0',origin=origin,day=572,
                    adopt_native=True,forcing_mode=SURFACE_IRRIGATION_FORCING)
            if owner is not None:
                request=owner.irrigation_forcing(depth,conc,rate,'explicit-'+str(day),enabled=enabled)
                proposal=owner.prepare(irrigation=request)
                assert physical(proposal.budget)==physical(row)
                expected=payload(warmdir/f'accepted-column-1-day-{day}.zip')
                assert payload(owner._candidate[3])==expected
                if day==573:
                    owner.discard(proposal);assert h.sha(origin)==origin_sha
                    proposal=owner.prepare(irrigation=request)
                    assert physical(proposal.budget)==physical(row) and payload(owner._candidate[3])==expected
                accepted=owner.accept(proposal);cold.append(proposal.budget)
                assert payload(accepted)==expected and h.sha(origin)==origin_sha
        warm.close()
    retries=[line for line in (warmdir/'original/donor.stdout').read_text().splitlines() if line.startswith('HYBRID_CDE_RETRY ')]
    assert retries,'Actual negative chemical trial must be exercised at O0'
    assert all(abs(row['independent_residual_cm'])<=1e-10 and abs(row['solute_independent_residual_mg_cm2'])<=1e-10 for row in rows)
    (out/'warm.jsonl').write_text(''.join(json.dumps(row)+'\n' for row in rows))
    (out/'external.jsonl').write_text(''.join(json.dumps(row)+'\n' for row in cold))
    result=dict(status='TRANSACTIONAL_O0_ACTUAL_RETRY_EXACT_RESTART_PASS',source_commit=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),
        original_full_run=43587528984,original_build=identity,completed_days=575,external_days=[573,574,575],
        actual_retry_lines=retries,discard_replay_exact=True,every_exercised_native_exact=True,origin_unchanged=True,
        maximum_water_residual_cm=max(abs(row['independent_residual_cm']) for row in rows),
        maximum_solute_residual_mg_cm2=max(abs(row['solute_independent_residual_mg_cm2']) for row in rows),science='NOT_QUALIFIED')
    (out/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n');print(result['status'],flush=True)

if __name__=='__main__':main()
