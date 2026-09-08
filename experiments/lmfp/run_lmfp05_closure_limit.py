from __future__ import annotations

import json
import math
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

from run_lmfp04_ab import SAND, CLAY
from run_lmfp02_testbench import mfp_difference


def material(code: int):
    return SAND if code == 1 else CLAY


def anchor_head(case_id: int, depth: float) -> float:
    d = [5.0, 15.0, 30.0, 50.0]
    if case_id == 1:
        hv = [-200.0, -120.0, -60.0, -30.0]
    elif case_id in (2, 3):
        hv = [-150.0, -100.0, -70.0, -50.0]
    else:
        raise ValueError(case_id)
    if depth <= d[0]:
        return hv[0] + (hv[1] - hv[0]) * (depth - d[0]) / (d[1] - d[0])
    if depth >= d[-1]:
        return hv[-1] + (hv[-1] - hv[-2]) * (depth - d[-1]) / (d[-1] - d[-2])
    for i in range(3):
        if d[i] <= depth <= d[i + 1]:
            return hv[i] + (hv[i + 1] - hv[i]) * (depth - d[i]) / (d[i + 1] - d[i])
    raise RuntimeError('interpolation failure')


def material_code(case_id: int, depth: float) -> int:
    if case_id == 1:
        return 1
    if case_id == 2:
        return 1 if depth < 20.0 else 2
    if case_id == 3:
        return 2 if depth < 20.0 else 1
    raise ValueError(case_id)


def grid(case_id: int, n: int):
    dx = 60.0 / n
    depths = [(i + 0.5) * dx for i in range(n)]
    heads = [anchor_head(case_id, z) for z in depths]
    codes = [material_code(case_id, z) for z in depths]
    return dx, depths, heads, codes


def arithmetic_flux(code_u: int, code_l: int, h_u: float, h_l: float, length: float) -> float:
    ku = material(code_u).conductivity(h_u)
    kl = material(code_l).conductivity(h_l)
    return 0.5 * (ku + kl) * (1.0 + (h_u - h_l) / length)


def homogeneous_mfp_flux(code: int, h_u: float, h_l: float, length: float) -> tuple[float, int]:
    mat = material(code)
    dh = h_u - h_l
    if abs(dh) <= 1.0e-12 * max(1.0, abs(h_u), abs(h_l)):
        ksec = mat.conductivity(0.5 * (h_u + h_l))
        return ksec * (1.0 + dh / length), 1
    dphi, evals = mfp_difference(mat, h_u, h_l)
    ksec = dphi / dh
    return ksec * (1.0 + dh / length), evals


def segment_flux(code: int, h_u: float, h_l: float, length: float) -> tuple[float, int]:
    return homogeneous_mfp_flux(code, h_u, h_l, length)


def heterogeneous_mfp_flux(code_u: int, code_l: int, h_u: float, h_l: float,
                           length_u: float, length_l: float,
                           tolerance: float = 1.0e-11, max_iterations: int = 80):
    # Solve one continuous interface pressure head so both half-segments carry
    # exactly the same full Darcy flux. Bracketing is expanded beyond endpoint
    # heads when gravity makes the equal-flux interface head lie outside them.
    def residual(h_i):
        q_u, e_u = segment_flux(code_u, h_u, h_i, length_u)
        q_l, e_l = segment_flux(code_l, h_i, h_l, length_l)
        return q_u - q_l, q_u, q_l, e_u + e_l

    scale_h = max(1.0, abs(h_u), abs(h_l), length_u + length_l)
    lo = min(h_u, h_l) - scale_h
    hi = max(h_u, h_l) + scale_h
    f_lo, _, _, evals = residual(lo)
    f_hi, _, _, e = residual(hi)
    evals += e
    expands = 0
    while f_lo * f_hi > 0.0 and expands < 30:
        span = hi - lo
        lo -= span
        hi += span
        f_lo, _, _, e1 = residual(lo)
        f_hi, _, _, e2 = residual(hi)
        evals += e1 + e2
        expands += 1
    if f_lo * f_hi > 0.0:
        raise RuntimeError(f'heterogeneous equal-flux bracket failed: {f_lo}, {f_hi}')

    for iteration in range(1, max_iterations + 1):
        mid = 0.5 * (lo + hi)
        f_mid, q_u, q_l, e = residual(mid)
        evals += e
        q = 0.5 * (q_u + q_l)
        if abs(f_mid) <= tolerance * max(1.0, abs(q_u), abs(q_l)):
            return q, mid, iteration, evals, q_u - q_l
        if f_lo * f_mid <= 0.0:
            hi = mid
            f_hi = f_mid
        else:
            lo = mid
            f_lo = f_mid
    mid = 0.5 * (lo + hi)
    f_mid, q_u, q_l, e = residual(mid)
    evals += e
    return 0.5 * (q_u + q_l), mid, max_iterations, evals, q_u - q_l


def metrics(values):
    if not values:
        return {'count': 0, 'max_abs': 0.0, 'mean_abs': 0.0, 'rmse': 0.0}
    return {
        'count': len(values),
        'max_abs': max(abs(v) for v in values),
        'mean_abs': sum(abs(v) for v in values) / len(values),
        'rmse': math.sqrt(sum(v * v for v in values) / len(values)),
    }


def probe_case(case_id: int, n: int):
    dx, depths, heads, codes = grid(case_id, n)
    same_delta = []
    interface = None
    max_quad_evals = 0
    max_interface_iterations = 0
    for i in range(n - 1):
        hu, hl = heads[i], heads[i + 1]
        cu, cl = codes[i], codes[i + 1]
        qa = arithmetic_flux(cu, cl, hu, hl, dx)
        if cu == cl:
            qm, evals = homogeneous_mfp_flux(cu, hu, hl, dx)
            max_quad_evals = max(max_quad_evals, evals)
            same_delta.append(qm - qa)
        else:
            qm, hi, iterations, evals, residual = heterogeneous_mfp_flux(
                cu, cl, hu, hl, 0.5 * dx, 0.5 * dx)
            max_quad_evals = max(max_quad_evals, evals)
            max_interface_iterations = max(max_interface_iterations, iterations)
            interface = {
                'face_depth_cm': 0.5 * (depths[i] + depths[i + 1]),
                'upper_code': cu,
                'lower_code': cl,
                'h_upper_cm': hu,
                'h_lower_cm': hl,
                'q_arithmetic_cm_d': qa,
                'q_mfp_cm_d': qm,
                'delta_cm_d': qm - qa,
                'relative_delta': abs(qm - qa) / max(abs(qa), abs(qm), 1.0e-12),
                'interface_head_cm': hi,
                'equal_flux_residual': residual,
                'iterations': iterations,
            }
    return {
        'n': n,
        'dx_cm': dx,
        'same_material_delta': metrics(same_delta),
        'material_interface': interface,
        'max_direct_quadrature_evaluations_per_face': max_quad_evals,
        'max_interface_bisection_iterations': max_interface_iterations,
    }


def reduction_sequence(rows, key_path):
    out = []
    previous = None
    for row in rows:
        value = row
        for key in key_path:
            value = value[key]
        item = {'n': row['n'], 'dx_cm': row['dx_cm'], 'value': value}
        if previous is not None and value > 0.0:
            item['previous_over_current'] = previous / value
        previous = value
        out.append(item)
    return out


def main():
    if len(sys.argv) != 2:
        raise SystemExit('usage: run_lmfp05_closure_limit.py EVIDENCE_JSON')
    ns = [6, 12, 24, 48, 96, 192, 384]
    evidence = {
        'schema_version': 1,
        'method': {
            'fullrichards_face_law': 'SWKMEAN=1 arithmetic endpoint conductivity times discrete Darcy gradient',
            'layeredmfp_face_law': 'direct-quadrature MFP secant; heterogeneous face solves one equal-flux interface head',
            'time_stepping_used': False,
            'reason': 'spatial face-closure attribution must not be contaminated by the observed non-monotone small-dt Reference retry behaviour',
            'mfp_table_used': False,
        },
        'cases': {},
        'tests': {},
    }
    names = {1: 'redistribution_sand', 2: 'sand_over_clay', 3: 'clay_over_sand'}
    all_rows = {}
    for cid in (1, 2, 3):
        rows = [probe_case(cid, n) for n in ns]
        all_rows[cid] = rows
        case = {
            'grids': rows,
            'same_material_max_abs_reduction': reduction_sequence(rows, ['same_material_delta', 'max_abs']),
        }
        if cid in (2, 3):
            case['interface_delta_sequence'] = reduction_sequence(rows, ['material_interface', 'relative_delta'])
        evidence['cases'][names[cid]] = case

    hom = all_rows[1]
    hom_first = hom[0]['same_material_delta']['max_abs']
    hom_last = hom[-1]['same_material_delta']['max_abs']
    hetero_interface_finite = all(
        row['material_interface'] is not None and math.isfinite(row['material_interface']['q_mfp_cm_d'])
        for cid in (2, 3) for row in all_rows[cid]
    )
    max_interface_residual = max(
        abs(row['material_interface']['equal_flux_residual'])
        for cid in (2, 3) for row in all_rows[cid]
    )
    evidence['tests']['homogeneous_closure_difference_reduces_with_refinement'] = {
        'pass': hom_last < 0.05 * hom_first,
        'first_max_abs_cm_d': hom_first,
        'last_max_abs_cm_d': hom_last,
        'last_over_first': hom_last / hom_first,
    }
    evidence['tests']['heterogeneous_interface_solved'] = {
        'pass': hetero_interface_finite and max_interface_residual < 1.0e-8,
        'max_equal_flux_residual': max_interface_residual,
    }
    evidence['structural_pass'] = all(v['pass'] for v in evidence['tests'].values())
    evidence['interpretation_guard'] = {
        'homogeneous_statement': 'For a smooth single-material profile, arithmetic-K and MFP-secant are expected to approach the same local constitutive flux as dx decreases; this probe measures that convergence directly.',
        'heterogeneous_statement': 'At a true material discontinuity the two numerical interface laws can have different nonzero limiting fluxes. This probe can establish persistence but cannot by itself establish which interface law best approximates the Richards weak solution.',
        'production_change_implied': False,
        'application_envelope_implied': False,
    }
    Path(sys.argv[1]).write_text(json.dumps(evidence, indent=2, sort_keys=True) + '\n')
    print(json.dumps(evidence, indent=2, sort_keys=True))
    raise SystemExit(0 if evidence['structural_pass'] else 1)


if __name__ == '__main__':
    main()
