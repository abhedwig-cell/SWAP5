import pathlib
import sys

import numpy as np

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[2] / "research" / "hydrofit"))
from hydrofit import FitConfig, MvGParameters, Observation, evaluate, fit, multistart_fit, swap_theta, textbook_theta


def synthetic_observations(p, semantics="swap_default_mvg"):
    heads = np.array([-0.005, -0.01, -0.1, -1.0, -10.0, -100.0, -1000.0, -10000.0])
    theta, kval = evaluate(heads, p, semantics)
    obs = [Observation("theta", float(h), float(v), sigma=1e-3) for h, v in zip(heads, theta)]
    obs += [Observation("K", float(h), float(v), sigma=0.02) for h, v in zip(heads, kval)]
    return obs


def test_forward_physical_limits():
    p = MvGParameters(0.05, 0.45, 0.02, 1.6, 50.0)
    heads = np.array([0.0, -1e-3, -1.0, -100.0, -1e6])
    theta, kval = evaluate(heads, p, "swap_default_mvg")
    assert np.all(theta >= p.theta_r)
    assert np.all(theta <= p.theta_s)
    assert np.all(kval > 0.0)
    assert np.all(kval <= p.Ks)


def test_near_saturation_semantics_are_not_silently_equivalent():
    p = MvGParameters(0.05, 0.45, 0.5, 1.6, 50.0, h_entry=0.0)
    h = np.array([-0.005])
    assert abs(float(swap_theta(h, p)[0] - textbook_theta(h, p)[0])) > 1e-8


def test_exact_synthetic_recovery_swap_native():
    truth = MvGParameters(0.06, 0.43, 0.015, 1.7, 35.0)
    cfg = FitConfig(semantics="swap_default_mvg", fixed_l=0.5, fixed_h_entry=0.0)
    initial = MvGParameters(0.10, 0.48, 0.008, 1.4, 15.0)
    result = fit(synthetic_observations(truth), initial, cfg)
    assert result.success
    got = result.parameters
    assert np.allclose(
        [got.theta_r, got.theta_s, got.alpha, got.n, got.Ks],
        [truth.theta_r, truth.theta_s, truth.alpha, truth.n, truth.Ks],
        rtol=2e-5, atol=2e-7,
    )
    assert result.objective < 1e-8


def test_information_removal_worsens_identifiability():
    truth = MvGParameters(0.06, 0.43, 0.015, 1.7, 35.0)
    cfg = FitConfig(semantics="swap_default_mvg", fixed_l=0.5, fixed_h_entry=0.0)
    initial = MvGParameters(0.10, 0.48, 0.008, 1.4, 15.0)
    full = synthetic_observations(truth)
    reduced = [o for o in full if o.family == "theta" and -100.0 <= o.head_cm <= -0.1]
    a = fit(full, initial, cfg)
    b = fit(reduced, initial, cfg)
    assert np.isfinite(a.condition_number)
    assert b.condition_number > a.condition_number or not np.isfinite(b.condition_number)


def test_multistart_converges_to_same_exact_solution():
    truth = MvGParameters(0.06, 0.43, 0.015, 1.7, 35.0)
    cfg = FitConfig(semantics="swap_default_mvg", fixed_l=0.5, fixed_h_entry=0.0)
    starts = [
        MvGParameters(0.02, 0.36, 0.003, 1.2, 5.0),
        MvGParameters(0.12, 0.55, 0.08, 2.5, 150.0),
        MvGParameters(0.08, 0.46, 0.012, 1.5, 25.0),
    ]
    best, results = multistart_fit(synthetic_observations(truth), starts, cfg)
    assert best.success
    assert len(results) == 3
    for result in results:
        assert result.success
        p = result.parameters
        assert np.allclose(
            [p.theta_r, p.theta_s, p.alpha, p.n, p.Ks],
            [truth.theta_r, truth.theta_s, truth.alpha, truth.n, truth.Ks],
            rtol=5e-5, atol=5e-7,
        )


def test_theta_only_exposes_unidentifiable_ks_direction():
    truth = MvGParameters(0.06, 0.43, 0.015, 1.7, 35.0)
    cfg = FitConfig(semantics="swap_default_mvg", fixed_l=0.5, fixed_h_entry=0.0)
    all_obs = synthetic_observations(truth)
    theta_only = [o for o in all_obs if o.family == "theta"]
    initial = MvGParameters(0.10, 0.48, 0.008, 1.4, 15.0)
    result = fit(theta_only, initial, cfg)
    assert result.success
    assert result.singular_values[-1] < 1e-10 or not np.isfinite(result.condition_number) or result.condition_number > 1e12
