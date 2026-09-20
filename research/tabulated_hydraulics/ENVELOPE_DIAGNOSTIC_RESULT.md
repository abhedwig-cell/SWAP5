# TAB-HYD broad-envelope diagnostic result

Date: 2026-09-20

Status: **DIAGNOSTIC CLOSED FOR ORIGINAL CANDIDATE / PREREGISTERED GATE REMAINS FAILED**

This document explains the failed preregistered envelope. It does not alter the gate, acceptance limits, or candidate after seeing the result.

## Matrix completion

The repaired non-fail-fast diagnostic executed all 20 route/scenario combinations:

- 16 completed;
- 4 timed out at 30 s;
- no other process failures.

All five analytical `SWKIMPL=0` routes and all five table `SWKIMPL=0` routes completed.

For `SWKIMPL=1`:

- analytical completed for both coarse scenarios;
- analytical timed out for clay-wet, loam-mid and loam-capillary;
- table completed for clay-wet, both coarse scenarios and loam-capillary;
- table timed out for loam-mid.

The original preregistered requirement that every route complete is therefore not met.

## Completed analytical-table comparisons

The completed pairs show two different regimes.

### Coarse B4/O5 cases

Both K0 and K1 are extremely close between analytical and table routes.

For coarse-dry-free:

- K0 GWL max abs `0.00013 cm`, RMSE `2.97e-5 cm`;
- K1 GWL max abs `0.00013 cm`, RMSE `3.01e-5 cm`.

The strong infiltration-pulse case is similarly close.

### Loam and clay cases

The original 250-row direct-TSPACK candidate is not a faithful K0 surrogate in two free-drainage scenarios.

Loam-mid B9/O9, K0:

- GWL max abs `1193.93982 cm`;
- GWL RMSE `51.04687 cm`;
- DRAINAGE max abs `0.05943 cm`;
- DSTOR max abs `0.20195 cm`.

Clay-wet B12/O13, K0:

- GWL max abs `105.50664 cm`;
- GWL RMSE `7.47117 cm`;
- DRAINAGE max abs `0.36502 cm`;
- TACT max abs `0.10968 cm`;
- DSTOR max abs `0.36502 cm`.

The loam-capillary K0 pair remains close:

- GWL max abs about `2e-5 cm`;
- QBOTTOM max abs `0.0085 cm`;
- DSTOR max abs `0.00539 cm`.

This demonstrates that the representation error is state-dependent, not merely a parameter-label effect.

## Numerical-route controls

Where both K0 and K1 completed, analytical and table routes show nearly identical K0-vs-K1 behavior for the coarse cases. For example coarse-dry-free has:

- analytical K0-vs-K1 GWL max abs `0.31046 cm`;
- table K0-vs-K1 GWL max abs `0.31038 cm`.

For clay-wet, the analytical K1 route does not complete, while table K1 does. That table success must not be interpreted as superior faithful numerics because TAB-HYD-004 shows that the table conductivity spline substantially changes the near-saturation residual/Jacobian in this soil.

## Clay horizon ladder

For clay-wet B12/O13 under corrected analytical K1:

- 7 days completes in about `0.03 s`;
- 31 days completes in about `5.11 s`;
- 180 and 365 day probes time out at 20 s.

The original table candidate completes all four horizons, including 365 days in about `0.78 s`.

Combined with the direct constitutive evidence, this difference is diagnostic of changed numerical behavior, not evidence that the original table representation passed the fidelity gate.

## Root-cause classification

Two facts now line up:

1. the analytical default-MvG residual contains a finite K jump at the `Se > 1-1e-6` Ksat clamp for many Staring parameterizations;
2. the first generated table candidate represents K with one continuous TSPACK spline through the sub-threshold branch and the saturated Ksat endpoint.

For B12 and O13 this smooth bridge causes large K and dK/dh distortions. TAB-HYD-004 records the constitutive evidence.

The original broad-envelope candidate is therefore rejected as a general representation. The failed preregistered gate remains the authoritative result.

## Next research candidate

The next diagnostic is intentionally a **new candidate**, not a gate repair: split the generated conductivity representation at the analytical Ksat plateau. The continuous sub-threshold branch is interpolated directly; the plateau remains an explicit K=Ksat, dK/dh=0 branch. Theta/C interpolation remains separate.

That candidate must be judged as new evidence and cannot retroactively change this closeout.
