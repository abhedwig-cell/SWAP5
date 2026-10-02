"""Independent fixed Reference sample; never bypasses coupling publication."""
import argparse
import ctypes
import json
from pathlib import Path


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--library', type=Path, required=True)
    ap.add_argument('--profile', choices=['C0', 'C1'], required=True)
    ap.add_argument('--trial-result', type=Path, required=True)
    ap.add_argument('--output', type=Path, required=True)
    args = ap.parse_args()
    lib = ctypes.CDLL(str(args.library.resolve()))
    init = lib.fgc49d_fixture_initialize_c
    init.argtypes = [ctypes.POINTER(ctypes.c_int64), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double)]
    h, a, b = ctypes.c_int64(), ctypes.c_double(), ctypes.c_double()
    assert init(ctypes.byref(h), ctypes.byref(a), ctypes.byref(b)) == 0
    fn = lib.strip01_floor_c
    fn.argtypes = [ctypes.c_int, ctypes.c_double, ctypes.c_double,
                   ctypes.POINTER(ctypes.c_int), ctypes.POINTER(ctypes.c_double)]
    observe = lib.strip01_observe_c
    observe.argtypes = [ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_int)]

    def state():
        s, r = (ctypes.c_double * 50)(), (ctypes.c_int * 50)()
        assert observe(s, r) == 0
        return list(s), list(r)

    initial = state()
    stage = -5 if args.profile == 'C0' else -1
    heads = json.loads(args.trial_result.read_text())['trial_heads_m']
    rows = []
    for slot, head in [(1, stage), (50, stage + 0.5), (1, heads[0]), (50, heads[-1])]:
        for dt in (0.001, 0.00001):
            codes, values = (ctypes.c_int * 4)(), (ctypes.c_double * 4)()
            assert fn(slot, head, dt, codes, values) == 0
            rows.append(dict(column=slot, head_m=head, duration_day=dt,
                             codes=list(codes), accepted_dt_day=values[0], native_mass_residual=values[1], storage_change_native=values[2], bottom_outward_exchange_native=values[3]))
    assert initial == state(), 'Reference samples mutated committed state'
    args.output.write_text(json.dumps(dict(state='REFERENCE_FLOOR_DIAGNOSIS_COMPLETED', profile=args.profile,
        code_fields=['floor_status', 'sample_valid', 'nonlinear_iterations', 'internal_retries'],
        committed_state_preserved=True, coupled_window_qualification=False, probes=rows), indent=2) + '\n')
    print([(r['column'], r['duration_day'], r['codes'][:2], r['accepted_dt_day']) for r in rows])


if __name__ == '__main__':
    main()
