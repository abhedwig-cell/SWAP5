"""Native confined no-STO C0 component qualification; no coupled SWAP claim."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import numpy as np
from domain_oracle import N, DX, DY, PLANE, BASE, K, STAGE, C, solve


def total(cbc, text):
    records = cbc.get_data(text=text)
    assert records, 'missing budget ' + text
    return float(sum(np.sum(v['q']) if v.dtype.names and 'q' in v.dtype.names else np.sum(v)
                     for v in records))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--mf6', type=Path, required=True)
    ap.add_argument('--output', type=Path, required=True)
    args = ap.parse_args()
    exe = args.mf6.resolve()
    version = subprocess.check_output([str(exe), '-v'], text=True)
    assert '6.8.0' in version
    import flopy
    from flopy.mf6.utils.postprocessing import get_structured_faceflows
    assert flopy.__version__ == '3.9.5'
    args.output.mkdir(parents=True, exist_ok=True)
    result = dict(state='RUNNING', native_modflow=True, real_swap=False, canonical_admission=False,
                  version=version.strip(), executable_sha256=hashlib.sha256(exe.read_bytes()).hexdigest(),
                  head_limit_m=1e-8, rate_limit_m3_per_day=1e-10, cases=[], failures=[])
    try:
        for name in ('uniform', 'far_column_source'):
            folder = args.output / name
            source = np.full(N, 0.001) if name == 'uniform' else np.r_[np.zeros(N - 1), 0.001]
            expected, face_expected, drain_expected, _ = solve(source)
            sim = flopy.mf6.MFSimulation(sim_name='strip01c0', sim_ws=str(folder), exe_name=str(exe))
            flopy.mf6.ModflowTdis(sim, time_units='DAYS', perioddata=[(1, 1, 1)])
            flopy.mf6.ModflowIms(sim, outer_dvclose=1e-10, inner_dvclose=1e-11,
                               outer_maximum=200, inner_maximum=300, rcloserecord=1e-11)
            gwf = flopy.mf6.ModflowGwf(sim, modelname='strip', save_flows=True)
            flopy.mf6.ModflowGwfdis(gwf, nlay=1, nrow=1, ncol=N, delr=DX, delc=DY, top=PLANE, botm=BASE)
            flopy.mf6.ModflowGwfic(gwf, strt=STAGE)
            flopy.mf6.ModflowGwfnpf(gwf, icelltype=0, k=K, save_flows=True)
            flopy.mf6.ModflowGwfdrn(gwf, stress_period_data=[((0, 0, 0), STAGE, C)])
            if name == 'uniform':
                flopy.mf6.ModflowGwfrcha(gwf, recharge=0.001)
                source_name = 'RCHA'
            else:
                flopy.mf6.ModflowGwfwel(gwf, stress_period_data=[((0, 0, N - 1), 0.001)])
                source_name = 'WEL'
            flopy.mf6.ModflowGwfoc(gwf, head_filerecord='strip.hds', budget_filerecord='strip.cbc',
                                 saverecord=[('HEAD', 'ALL'), ('BUDGET', 'ALL')])
            sim.write_simulation(silent=True)
            ok, log = sim.run_simulation(silent=True, report=True)
            (folder / 'execution.log').write_text('\n'.join(log) + '\n')
            assert ok, 'native execution failed: ' + name
            h = flopy.utils.HeadFile(folder / 'strip.hds').get_data().ravel()
            cbc = flopy.utils.CellBudgetFile(folder / 'strip.cbc', precision='double')
            names = [x.decode().strip() for x in cbc.get_unique_record_names()]
            assert not any('STO' in x or 'CHD' in x for x in names), names
            frf, fff, flf = get_structured_faceflows(cbc.get_data(text='FLOW-JA-FACE')[0],
                                                   grb_file=folder / 'strip.dis.grb')
            source_rate, drain_rate = total(cbc, source_name), total(cbc, 'DRN')
            row = dict(name=name, heads_m=h.tolist(), head_error_m=float(np.max(np.abs(h - expected))),
                       source_m3_per_day=source_rate, drain_m3_per_day=drain_rate,
                       mass_residual_m3_per_day=source_rate + drain_rate,
                       internal_face_error_m3_per_day=float(np.max(np.abs(frf.ravel()[:-1] + face_expected))),
                       right_no_flow_m3_per_day=float(frf.ravel()[-1]),
                       base_no_flow_m3_per_day=float(np.max(np.abs(flf))), budget_records=names)
            result['cases'].append(row)
            assert row['head_error_m'] <= 1e-8, row
            assert abs(source_rate - source.sum()) <= 1e-10 and abs(drain_rate + drain_expected) <= 1e-10, row
            assert abs(row['mass_residual_m3_per_day']) <= 1e-10, row
            assert row['internal_face_error_m3_per_day'] <= 1e-10, row
            assert abs(row['right_no_flow_m3_per_day']) <= 1e-10 and row['base_no_flow_m3_per_day'] <= 1e-10, row
        result['state'] = 'NATIVE_C0_COMPONENT_PASS'
    except Exception as e:
        result['state'] = 'NATIVE_C0_COMPONENT_FAIL'
        result['failures'].append(repr(e))
        raise
    finally:
        (args.output / 'domain_native_result.json').write_text(json.dumps(result, indent=2) + '\n')
    print('STRIP01_NATIVE_C0_COMPONENT=PASS')


if __name__ == '__main__':
    main()
