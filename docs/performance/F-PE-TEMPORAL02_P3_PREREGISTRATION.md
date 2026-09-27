# F-PE-TEMPORAL02 P3 — displacement × temporal-budget completion surface

Date: 2026-09-26

Status: `PREREGISTERED_RESEARCH`

## Trigger

P0-P2R establish that 1e-3 cm is the preferred performance candidate for +/-0.001 cm correctors:

- 12/12 completion;
- no temporal or solver rejection;
- direct/direct runtime indistinguishable from 5e-4 where paths match;
- ~2.30x faster where 5e-4 still retries.

A useful coupled-corrector policy must cover more than +/-0.001 cm.

## Purpose

Map the completion/retry surface as a function of corrector displacement and temporal head budget.

## Matrix

Six difficult PROFILE06 origins.

Signed offsets:

- +/-0.001 cm;
- +/-0.01 cm;
- +/-0.05 cm;
- +/-0.10 cm;
- +/-0.25 cm.

Temporal budgets:

- 5e-4 cm;
- 1e-3 cm;
- 2e-3 cm;
- 5e-3 cm;
- 1e-2 cm;
- 2e-2 cm;
- 5e-2 cm.

Keep the P0 exact Reference numerical controls and retry policy fixed.

## Phase P3A

Run one fresh process per matrix point as a deterministic coarse screen. Record:

- completion status;
- first rejection reason;
- ordered retry sequence;
- temporal rejection count;
- solver rejection count.

P3A is descriptive only.

## Phase P3B

After P3A, identify the smallest common completing budget for each displacement magnitude and repeat the boundary points three times.

## Interpretation

Do not extrapolate linearly from +/-0.001 cm. The temporal indicator is state- and material-dependent.

Advance only if there is a bounded practical window in which a common budget completes all six difficult origins without entering the nonlinear retry-collapse regime.

No production source change is allowed.