# F-PE-NLGLOB14Z result — late saturated-block retreat and disappearance control exposure

Date: 2026-09-29

Status:

`BLOCKED_NLGLOB14Z_CONTROL_EXPOSURE`

with qualified partial physical evidence:

`NLGLOB14Z_FINE_GRID_LATE_RETREAT_SIGNAL`

Primary qualification authority:

- disappearance workflow run: `36608794784`;
- coarse-attribution workflow run: `36609648621`;
- coarse-attribution job: `109547487997`.

Canonical authority rechecked before persistence:

`integration/f-ci-canonical@b6c9079c209eb6d1fe2db2fd61ff330941770166`.

The canonical delta since the parent research postimage does not touch the NLGLOB/TIMEINT/Richards/surface-evaporation dependency surface.

## Frozen question

Does the persistent saturated-KLAG control continue to retreat beyond `7:16`, and does the saturated block disappear within the preregistered staged horizon through 6.40 d?

## Aggregate frozen classification

The preregistered aggregate classification is:

`BLOCKED_NLGLOB14Z_CONTROL_EXPOSURE`.

Reason: the two coarsest dt=2.5e-4 fixtures do not complete the 6.40 d control horizon.

This is not a process crash, mass failure, noncontiguous state or saturation-indicator inconsistency.

## Coarse-dt failure attribution

Both dt=2.5e-4 fixtures terminate cleanly with:

- process return code = 0;
- terminal reason = `ENDPOINT_SOLVE_FAILURE`;
- solver status = 2;
- physical state finite;
- accepted-state mass ledger still near roundoff;
- lower saturated tail still `7:16`;
- dry top route = `surface-flux`.

HEAD:

- transition step: 4599;
- time approximately 1.14975 d;
- max accepted-interval ledger about `1.41e-14 cm`;
- cumulative ledger about `2.69e-14 cm`.

RUNOFF:

- transition step: 4565;
- time approximately 1.14125 d;
- max accepted-interval ledger about `1.07e-14 cm`;
- cumulative ledger about `6.30e-14 cm`.

Thus the blocker is a coarse fixed-dt endpoint-solve limit in the persistent-KLAG control before the late retreat is reached.

It is not evidence that the late physical retreat is absent.

## Fine-grid physical signal

The remaining six fixtures, dt = 1.25e-4, 6.25e-5 and 3.125e-5 d in both route families, complete the full 6.40 d horizon.

All six expose exactly one additional accepted physical retreat beyond `7:16`:

`7:16 -> 8:16`.

HEAD:

- dt 1.25e-4 d: 2.442875 d;
- dt 6.25e-5 d: 2.442875 d;
- dt 3.125e-5 d: 2.442875 d.

RUNOFF:

- dt 1.25e-4 d: 2.439750 d;
- dt 6.25e-5 d: 2.4396875 d;
- dt 3.125e-5 d: 2.43971875 d.

Across these six complete fixtures:

- accepted saturated geometry remains contiguous;
- no skipped node occurs;
- no reverse late retreat occurs;
- no disappearance occurs by 6.40 d;
- final saturated tail is `8:16`;
- maximum accepted-interval ledger is about `2.36e-14 cm`;
- maximum cumulative ledger is about `1.14e-12 cm`.

This is strong fine-grid evidence for a real later retreat, but NLGLOB14Z cannot elevate it to the aggregate preregistered positive class because 2/8 frozen fixtures are incomplete.

## Scientific interpretation

The late lower-edge retreat continues physically.

The coarse dt=2.5e-4 control loses endpoint solvability before reaching it, whereas the three finer dt levels in both route families expose an extremely stable accepted retreat time near 2.44 d.

The appropriate next question is therefore timestep refinement and event qualification, not forcing modification or a new release threshold.

## Consequence

Open a separately preregistered refinement successor that:

- keeps the forcing and physics unchanged;
- excludes no failed evidence from history;
- adds finer dt levels to the three successful levels;
- tests convergence of the accepted `7:16 -> 8:16` retreat time;
- attributes whether dt=2.5e-4 is simply outside the stable late-horizon resolution range.

Do not use MAXIT/BALTOL tuning as a substitute.

Complete saturated-block disappearance remains unqualified.

## Production boundary

Research only.

No production `src/**` change.

No production temporal-ownership or numerical default changed.

`LEGACY_NUMERICS` remains production default.
