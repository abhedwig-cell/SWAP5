"""Isolate the first-window SWAP response without MODFLOW or publication."""
import argparse
import ctypes
import json
from pathlib import Path


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--profile', choices=['C0','C1'], default='C0')
    ap.add_argument('--library', type=Path, required=True)
    ap.add_argument('--trial-result', type=Path, required=True)
    ap.add_argument('--output', type=Path, required=True)
    args = ap.parse_args()
    lib = ctypes.CDLL(str(args.library.resolve()))
    init = lib.fgc49d_fixture_initialize_c
    init.argtypes = [ctypes.POINTER(ctypes.c_int64), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double)]
    handle, a, b = ctypes.c_int64(), ctypes.c_double(), ctypes.c_double()
    assert init(ctypes.byref(handle), ctypes.byref(a), ctypes.byref(b)) == 0
    fn = lib.strip01_diagnose_c
    fn.argtypes = [ctypes.c_int, ctypes.c_double, ctypes.c_double, ctypes.c_int,
                   ctypes.POINTER(ctypes.c_int), ctypes.POINTER(ctypes.c_double)]
    observe = lib.strip01_observe_c
    observe.argtypes = [ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_int)]

    def state():
        s, r = (ctypes.c_double * 50)(), (ctypes.c_int * 50)()
        assert observe(s, r) == 0
        return list(s), list(r)

    stage = -5 if args.profile == 'C0' else -1
    initial = state()
    heads = json.loads(args.trial_result.read_text())['trial_heads_m']
    rows = []
    for slot, head, dt, tangent in (
        [(slot, heads[slot - 1], dt, True) for slot in (1, 50)
         for dt in (0.001, 0.0005, 0.0001, 0.00001)]
        + [(1, stage, 0.001, False), (50, stage + 0.5, 0.001, False),
           (1, heads[0], 0.001, False), (1, stage, 0.001, True), (50, stage + 0.5, 0.001, True)]
    ):
        codes, completed = (ctypes.c_int * 8)(), ctypes.c_double()
        assert fn(slot, head, dt, tangent, codes, ctypes.byref(completed)) == 0
        rows.append(dict(column=slot, head_m=head, duration_day=dt, tangent_requested=tangent,
                         codes=list(codes), completed_t_day=completed.value))
    final = state()
    assert initial == final, 'diagnostic trials mutated committed origins'
    result = dict(state='ISOLATED_RESPONSE_DIAGNOSIS_COMPLETED', profile=args.profile,
        code_fields=['canonical_status', 'accepted_substeps', 'solver_rejections', 'temporal_rejections',
                     'mass_rejections', 'admission_rejections', 'attempts', 'retries'],
        canonical_status={'0': 'COMPLETED', '2': 'TRANSACTION_FAILED'},
        committed_state_preserved=True, probes=rows, canonical_admission=False)
    args.output.write_text(json.dumps(result, indent=2) + '\n')
    print(result['state'])


if __name__ == '__main__':
    main()
