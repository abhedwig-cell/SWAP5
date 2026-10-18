#!/usr/bin/env python3
"""Fit retention only; never invent conductivity or spatially transfer old cores."""
import argparse
import csv
import hashlib
import json
from pathlib import Path

import numpy as np
from scipy.optimize import least_squares


def curve(parameters, theta_s, head):
    theta_r, log_alpha, n = parameters
    return theta_r + (theta_s - theta_r) * (1 + (10 ** log_alpha * head) ** n) ** (1 / n - 1)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    source = Path(__file__).resolve().parent.parent / 'local_sources/historical_retention_1981.csv'
    rows = list(csv.DictReader(source.open()))
    head = 10 ** np.array([1.70, 2.00, 2.54, 3.01, 4.19])
    keys = ['pf1_70', 'pf2_00', 'pf2_54', 'pf3_01', 'pf4_19']
    fitted, excluded = [], []
    for row in rows:
        identity = {k: row[k] for k in ['table', 'pdf_page', 'profile', 'horizon', 'row_variant']}
        if row['basis'] != 'volume_percent' or row['identity_status'] != 'consistent':
            excluded.append(dict(identity, reason='missing measured density for mass-to-volume conversion'
                                 if row['basis'] != 'volume_percent' else 'unresolved source horizon identity'))
            continue
        theta_s = float(row['porosity_percent']) / 100
        theta = np.array([float(row[k]) / 100 for k in keys])
        assert np.all(np.diff(theta) <= 0) and 0 < theta[-1] < theta_s < 1
        bounds = ([0, -5, 1.001], [float(theta[-1]) - 1e-10, 1, 10])
        # Deterministic multistart, all five measured points equally weighted.
        solutions = [least_squares(lambda p: curve(p, theta_s, head) - theta,
                                  [theta[-1] / 2, log_alpha, n], bounds=bounds,
                                  ftol=1e-12, xtol=1e-12, gtol=1e-12)
                     for log_alpha in [-3, -2, -1] for n in [1.3, 2, 4]]
        fit = min(solutions, key=lambda s: s.cost)
        assert fit.success and np.all(np.isfinite(fit.x))
        singular = np.linalg.svd(fit.jac, compute_uv=False)
        residual = curve(fit.x, theta_s, head) - theta
        fitted.append(dict(identity, theta_r=float(fit.x[0]), theta_s=theta_s,
                           alpha_per_cm=float(10 ** fit.x[1]), n=float(fit.x[2]),
                           m=float(1 - 1 / fit.x[2]),
                           measured_theta=theta.tolist(), fitted_theta=curve(fit.x, theta_s, head).tolist(),
                           residual_theta=residual.tolist(), rmse_theta=float(np.sqrt(np.mean(residual ** 2))),
                           max_abs_residual_theta=float(np.max(np.abs(residual))),
                           jacobian_condition=float(singular[0] / singular[-1]),
                           active_bounds=fit.active_mask.tolist(), conductivity_cm_day=None,
                           status='RETENTION_FIT_ONLY_NOT_A_COMPLETE_SWAP_SOIL'))
    result = {'input_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
              'method': 'van Genuchten m=1-1/n; theta_s fixed to reported total porosity; equal-weight least squares',
              'fitting_bounds': {'theta_r': '0 to smallest measured theta', 'alpha_per_cm': [1e-5, 10], 'n': [1.001, 10]},
              'pressure_heads_abs_cm': head.tolist(), 'rows': len(rows), 'fits': fitted, 'excluded': excluded,
              'limitations': ['Porosity equals theta_s only by an explicit model assumption.',
                              'No measured saturation point, conductivity, hysteresis or fitted uncertainty.',
                              'Fit error and Jacobian conditioning are not parameter uncertainty.',
                              'Profiles 3b/4b excluded, not silently relabelled.',
                              'Two profile-2 A1 rows are retained separately, not assigned fictitious subdepths.',
                              'No automatic mapping to present-day cells or vegetation.']}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({'rows': len(rows), 'fitted': len(fitted), 'excluded': len(excluded),
                      'max_rmse_theta': max(r['rmse_theta'] for r in fitted)}))


if __name__ == '__main__':
    main()
