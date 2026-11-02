"""Read immutable full Hupsel ledgers to locate the wet-cut stock discrepancy.

No native execution, source change, checkpoint rewrite or scientific promotion.
The original failed maximum-error gate remains unchanged.
"""
import argparse, base64, hashlib, io, json, math, tarfile
from pathlib import Path
from scientific_followup import native_data, rows

ROOT = Path(__file__).resolve().parents[2]
OWNER = ROOT / 'integration/dataqual15_hupsel'
sha = lambda raw: hashlib.sha256(raw).hexdigest()


def analyze():
    native, crop, _, literal, _, _ = native_data()
    manifest = json.loads((OWNER / 'SPRINT03_SCIENCE_MANIFEST.json').read_text())
    archive = OWNER / manifest['archive']
    assert sha(archive.read_bytes()) == manifest['archive_sha256']
    with tarfile.open(archive) as t:
        def get(name):
            raw = t.extractfile(name).read()
            assert sha(raw) == manifest['members'][name], name
            return raw
        fine = rows(get('original/dtmax-0.0003125/result_output.csv'))
        bounds = json.loads(get('science/FROZEN_BOUNDS_BEFORE_HOLDOUT.json'))
        original_caps = {}
        for prefix, caps in [('science', [.04, .02, .01, .005, .0025, .00125]),
                             ('original', [.000625, .0003125])]:
            for cap in caps:
                ref = rows(get(prefix + '/dtmax-' + str(cap) + '/result_output.csv'))
                assert len(ref) == 1097
                original_caps[str(cap)] = dict(
                    first_day_drainage_cm=float(ref[1]['DRN']),
                    first_day_water_cm=sum(float(ref[1][k]) for k in ['WTOT','PD_VOL','IC_VOL']))
    assert len(native) == 1096 and len(fine) == 1097
    byday = {int(r['day']): r for r in crop}
    stock = lambda r: math.fsum(float(r[k]) for k in ['WTOT','PD_VOL','IC_VOL'])
    # The selected grass period has all canopy water inside the physical carrier.
    # Its only external outputs are canopy/soil/pond evaporation, root uptake,
    # runoff and drainage. Hence the missing reported canopy term is identifiable.
    event = []
    for day in sorted({d+offset for d in [930,956,989,1033] for offset in [-1,0,1]}):
        n, r = native[day-1], fine[day]
        canopy = n['water_out_cm'] - math.fsum(n[k] for k in [
            'soil_evaporation_cm','pond_evaporation_cm','actual_transpiration_cm',
            'drainage_cm','runoff_cm'])
        entry = dict(day=day, native_stock_cm=n['water_end_cm'],
                     original_stock_cm=stock(r), stock_difference_cm=n['water_end_cm']-stock(r),
                     native_inferred_canopy_external_out_cm=canopy,
                     original_canopy_external_out_cm=float(r['EIC']),
                     canopy_external_out_difference_cm=canopy-float(r['EIC']),
                     native_water_residual_cm=n['water_residual_cm'],
                     original_reported_water_residual_cm=float(r['BALDEV']),
                     native_leaf_kg_ha=float(byday[day]['wlv']),
                     original_leaf_kg_ha=float(r['WLV']),
                     original_canopy_stock_cm=float(r['IC_VOL']))
        assert abs(entry['native_water_residual_cm']) < 1e-10
        event.append(entry)
    differences = [n['water_end_cm']-stock(r) for n,r in zip(native,fine[1:])]
    limit = bounds['water_global']['limit']
    crossings = [i+1 for i,x in enumerate(differences) if abs(x)>limit]
    assert crossings == [930,956,989,1033], crossings
    assert all(float(byday[d]['wlv'])<float(byday[d-1]['wlv']) for d in crossings)
    assert all(float(byday[d]['cut_index'])>float(byday[d-1]['cut_index']) for d in crossings)
    assert all(float(fine[d]['HRVDM'])>float(fine[d-1]['HRVDM']) for d in crossings)
    assert max(range(1096),key=lambda i:abs(differences[i]))+1 == 930
    assert float(byday[930]['wlv']) < float(byday[929]['wlv'])
    assert float(fine[930]['WLV']) < float(fine[929]['WLV'])
    b1 = ROOT/'integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64'
    with tarfile.open(fileobj=io.BytesIO(base64.b64decode(b1.read_bytes()))) as t:
        code = {name:t.extractfile(name).read() for name in [
            'SWAP/MOD_cropdevelopment.f90','SWAP/integral.f90']}
    assert b'siccaploss = sicact - siccap' in code['SWAP/MOD_cropdevelopment.f90']
    assert b'iintc  = iintc + siccaploss' in code['SWAP/integral.f90']
    backend = ROOT/'src/runtime/mod_fmr_serialized_reference_backend.f90'
    source = backend.read_text()
    assert 'call rutter_local_base%capacity_candidate' in source
    assert 'step%rutter_evaporation_cm=rutter_process_result%reservoir_outflow_cm_per_day*step_duration+rutter_local_capacity_export' in source
    initial = native[0]['water_start_cm']-stock(literal[0])
    assert abs(initial)<1e-10
    return dict(
        scope='IMMUTABLE_FULL_TRAJECTORY_LEDGER_AND_SOURCE_TIMING_DIAGNOSIS',
        native_full_days=1096, new_native_executions=0, production_changed=False,
        scientific_gate_reassessed=False, full_scientific_qualification=False,
        original_scientific_bounds_unchanged=True,
        scientific_archive_sha256=manifest['archive_sha256'],
        native_archive_sha256=sha((OWNER/'UNION_C3_HUPSEL_EVIDENCE.tar.xz').read_bytes()),
        b1_authority_sha256=sha(b1.read_bytes()),
        selected_original_source_sha256={k:sha(v) for k,v in code.items()},
        current_backend_sha256=sha(backend.read_bytes()),
        initial_total_water_difference_cm=initial,
        first_day_native_drainage_cm=native[0]['drainage_cm'],
        first_day_original_refinement=original_caps,
        first_day_native_vs_finest_drainage_difference_cm=native[0]['drainage_cm']-float(fine[1]['DRN']),
        frozen_whole_period_water_limit_cm=limit,
        days_exceeding_unchanged_water_stock_bound=crossings,
        event_days=event,
        paired_event_canopy_external_out_difference_cm={str(d):math.fsum(r['canopy_external_out_difference_cm'] for r in event if r['day'] in [d,d+1]) for d in crossings},
        development_failure='Initial exploratory single-crossing assertion failed: actual complete raw series contains four crossings, all four on cutting days. Full observations retained; no gate changed.',
        classification='Wet-cut event accounting is applied at different boundaries: original crop update versus next native hydraulic trial. Retained ledgers show opposite-day canopy export differences and recovery of the stock gap. Exact native canopy stock and capacity at the event were not retained; the amount attribution is not an exact paired state proof.',
        remaining='Root-search first-growth cause is studied separately. The day1 small hydrologic difference and later crop/solute/energy differences are not repaired or scientifically qualified here.')


if __name__ == '__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args()
    result=analyze()
    args.output.write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({k:v for k,v in result.items() if k not in ['event_days','first_day_original_refinement']},indent=2))
