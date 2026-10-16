# F-PE-TIMEINT01A preregistration — smooth-regime temporal-order characterization

Date: 2026-09-28

Status: `PREREGISTERED_BEFORE_RESULTS`

Parent: F-PE-TIMEINT01.

## Purpose

Empirically characterize the temporal order of the current Reference SWKIMPL=0 scheme in smooth fixed-regime cases.

This is a mechanism check, not a broad production qualification.

## Cases

Use repository-backed hydraulic archetypes:

- B01;
- O05.

Use two smooth forcing/state regimes:

- DRY: h0=-300 cm, rain=0.5 cm/day;
- TRANSITION: h0=-100 cm, rain=4 cm/day.

Only points that remain on the surface-flux dynamic-top route for the full ladder are used for the order estimate.

Horizon:

`0.04 d`.

## Fixed timestep ladder

Run exact fixed steps at:

- 0.010 d;
- 0.005 d;
- 0.0025 d;
- 0.00125 d.

The BALTOL02 effective balance floor remains active.

No adaptive timestep movement.

## Endpoint quantities

Record:

- top/mid/bottom pressure head;
- terminal storage;
- ponding;
- cumulative runoff;
- deterministic solver work;
- maximum ledger residual.

## Order estimate

For each scalar endpoint quantity y, define successive differences:

`D_h = |y_h - y_{h/2}|`

`D_h2 = |y_{h/2} - y_{h/4}|`.

When both are nonzero and well above roundoff, estimate:

`p = log2(D_h / D_h2)`.

Primary order signal:

- top-head convergence;
- secondary: storage and bottom head.

No order is inferred from quantities that are identically zero or roundoff dominated.

## Interpretation

Expected result from source reconstruction:

approximately first-order temporal convergence in smooth regimes.

A median estimated p in roughly [0.7,1.3] across usable top-head triplets supports the reconstruction.

A materially different result does not automatically falsify the source analysis; it triggers attribution of spatial/nonlinear/roundoff or coefficient-freezing effects.

