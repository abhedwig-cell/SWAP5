"""Research-only discriminator for the C2 rainfall-onset temporal history."""
import argparse
import ctypes
import json
from pathlib import Path
import subprocess
import sys

DURATIONS = [1e-3, 1e-4, 1e-5, 1e-6, 1e-7, 1e-8, 1e-9]


def bind_init(lib):
    init = lib.fgc49d_fixture_initialize_c
    init.argtypes = [ctypes.POINTER(ctypes.c_int64), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double)]
    init.restype = ctypes.c_int
    return init


def child(library, case, candidate_path=None):
    lib = ctypes.CDLL(str(library))
    handle, h1, h2 = ctypes.c_int64(), ctypes.c_double(), ctypes.c_double()
    if case == 'capture':
        budget = lib.strip01_seed_budget_c
        budget.argtypes = [ctypes.c_double]
        budget.restype = ctypes.c_int
        assert budget(10.0) == 0
    elif case == 'seeded':
        seed = json.loads(candidate_path.read_text())['history']
        arr = (ctypes.c_double * 20)(*seed)
        set_seed = lib.strip01_seed_derivative_c
        set_seed.argtypes = [ctypes.POINTER(ctypes.c_double)]
        set_seed.restype = ctypes.c_int
        assert set_seed(arr) == 0
    init_status = bind_init(lib)(ctypes.byref(handle), ctypes.byref(h1), ctypes.byref(h2))
    if init_status != 0:
        return {'case': case, 'initialization_status': init_status}
    set_rain = lib.fgc49d_fixture_set_rain_c
    set_rain.argtypes = [ctypes.c_double]
    set_rain.restype = ctypes.c_int
    assert set_rain(0.1) == 0

    if case == 'capture':
        fn = lib.strip01_candidate_history_c
        fn.argtypes = [ctypes.c_int, ctypes.c_double, ctypes.c_double,
                       ctypes.POINTER(ctypes.c_int), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double)]
        fn.restype = ctypes.c_int
        codes, heads, history = (ctypes.c_int * 8)(), (ctypes.c_double * 20)(), (ctypes.c_double * 20)()
        status = fn(1, -1.0, 0.001, codes, heads, history)
        return {'case': case, 'initialization_status': init_status, 'capture_status': status,
                'temporary_head_budget_cm': 10.0, 'codes': list(codes), 'heads_cm': list(heads),
                'history': list(history)}

    fn = lib.strip01_diagnose_detail_c
    fn.argtypes = [ctypes.c_int, ctypes.c_double, ctypes.c_double,
                   ctypes.POINTER(ctypes.c_int), ctypes.POINTER(ctypes.c_double)]
    fn.restype = ctypes.c_int
    trials = []
    for dt in DURATIONS:
        codes, values = (ctypes.c_int * 12)(), (ctypes.c_double * 6)()
        call_status = fn(1, -1.0, dt, codes, values)
        trials.append({'dt_day': dt, 'call_status': call_status, 'codes': list(codes), 'observations': list(values)})
    return {'case': case, 'initialization_status': init_status, 'forcing_cm_per_day': 0.1,
            'frozen_head_budget_cm': 1e-5, 'trials': trials}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--library', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--child-case', choices=['capture', 'zero', 'seeded'])
    parser.add_argument('--candidate', type=Path)
    args = parser.parse_args()
    if args.child_case:
        print(json.dumps(child(args.library.resolve(), args.child_case, args.candidate), indent=2))
        return
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    candidate_path = output / 'candidate_history.json'
    capture = subprocess.run([sys.executable, __file__, '--library', str(args.library.resolve()),
                              '--output', str(output), '--child-case', 'capture'],
                             check=True, text=True, capture_output=True)
    captured = json.loads(capture.stdout)
    candidate_path.write_text(json.dumps(captured, indent=2) + '\n')
    cases = {}
    for mode in ('zero', 'seeded'):
        cmd = [sys.executable, __file__, '--library', str(args.library.resolve()), '--output', str(output),
               '--child-case', mode]
        if mode == 'seeded':
            cmd += ['--candidate', str(candidate_path)]
        completed = subprocess.run(cmd, check=True, text=True, capture_output=True)
        cases[mode] = json.loads(completed.stdout)
    result = {'experiment': 'F-GC-STRIP01-C2-TEMPORAL-SEED-DISCRIMINATOR',
              'classification': 'research_only_not_qualification', 'capture': captured, 'cases': cases,
              'observation_columns': ['result_status', 'accepted_substeps', 'solver_rejections',
                                      'temporal_rejections', 'mass_rejections', 'admission_rejections',
                                      'attempts', 'retries', 'solver_status', 'temporal_status',
                                      'temporal_available', 'head_budget_valid'],
              'value_columns': ['temporal_head_inf_bound_cm', 'temporal_head_budget_cm',
                                'normalized_temporal_indicator', 'top_flux_cm_per_day',
                                'bottom_flux_cm_per_day', 'solver_equation_residual']}
    (output / 'result.json').write_text(json.dumps(result, indent=2) + '\n')
    print(output / 'result.json')


if __name__ == '__main__':
    main()
