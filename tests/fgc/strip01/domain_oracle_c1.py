"""Independent confined, zero-storage limiting-domain oracle; no SWAP/MF6 claim."""
import argparse
import json
from pathlib import Path
import numpy as np

N = 50
DX = DY = 1.0
PLANE = -2.0
BASE = -10.0
K = 0.5
T = K * (PLANE - BASE)
STAGE = -1.0
C = 100.0


def solve(source):
    source = np.asarray(source, dtype=float)
    if source.shape != (N,) or not np.isfinite(source).all():
        raise ValueError('invalid source vector')
    if source.sum() <= 0:
        raise ValueError('inactive DRN zero-storage branch has no unique draining solution')
    g = T * DY / DX
    matrix = np.zeros((N, N))
    for i in range(N - 1):
        matrix[i, i] += g
        matrix[i + 1, i + 1] += g
        matrix[i, i + 1] -= g
        matrix[i + 1, i] -= g
    matrix[0, 0] += C
    rhs = source.copy()
    rhs[0] += C * STAGE
    h = np.linalg.solve(matrix, rhs)
    if h.min() <= PLANE + 0.001 or h.max() >= 0:
        raise ValueError('saturated lower-domain or surface-emergence envelope violated')
    flow_left = g * np.diff(h)
    drain = C * (h[0] - STAGE)
    if drain < 0:
        raise ValueError('drain cannot supply water')
    return h, flow_left, drain, float(np.max(np.abs(matrix @ h - rhs)))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', required=True)
    args = parser.parse_args()
    cases = []
    for name in ('uniform', 'far_column_source'):
        q = np.full(N, 0.001) if name == 'uniform' else np.r_[np.zeros(N - 1), 0.001]
        h, flow, drain, residual = solve(q)
        expected = STAGE + q.sum() / C + np.r_[0, np.cumsum(np.cumsum(q[:0:-1])[::-1] / T)]
        error = float(np.max(np.abs(h - expected)))
        assert error < 1e-10 and residual < 1e-10 and abs(drain - q.sum()) < 1e-10
        if name == 'far_column_source':
            assert np.max(np.abs(flow - 0.001)) < 1e-10
        cases.append(dict(name=name, heads_m=h.tolist(), flow_left_m3_per_day=flow.tolist(),
                          source_m3_per_day=q.tolist(), drain_m3_per_day=float(drain),
                          oracle_error_m=error, rate_residual_m3_per_day=residual))
    negatives = []
    for name, q in [('net_extraction', np.full(N, -0.001)), ('no_source', np.zeros(N)),
                    ('surface_emergence', np.full(N, 0.1))]:
        try:
            solve(q)
        except ValueError as e:
            negatives.append(dict(name=name, rejected=True, reason=str(e)))
        else:
            raise AssertionError('negative case accepted: ' + name)
    result = dict(state='ANALYTICAL_C1_LIMITING_DOMAIN_ORACLE_PASS', native_modflow=False,
                  real_swap=False, canonical_admission=False, fixed_plane_m=PLANE,
                  swap_interval_m=[PLANE, 0], modflow_interval_m=[BASE, PLANE],
                  transmissivity_m2_per_day=T, independent_modflow_storage_m3=0,
                  cases=cases, negatives=negatives,
                  continuum_uniform_midpoint_rise_m=0.001 * 50**2 / (2 * T),
                  balance='P-ET-runoff-Q_DRN = delta_S_SWAP; interface cancels once',
                  limitations=['confined zero-storage lower domain, not the convertible A/B aquifer',
                               'steady prescribed-source oracle, not a transient coupled experiment',
                               'DRN owner is excluded by current production bootstrap'])
    Path(args.output).write_text(json.dumps(result, indent=2) + '\n')


if __name__ == '__main__':
    main()
