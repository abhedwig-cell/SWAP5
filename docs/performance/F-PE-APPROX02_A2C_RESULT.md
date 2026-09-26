# F-PE-APPROX02 A2C result — strict-practical Richards convergence envelope

Date: 2026-09-26

Status: `QUALIFIED_ENVELOPE_PENDING_EXPLICIT_OPT_IN`

Candidate:
joint head + compartment/total balance tolerances of `1e-8`, with all other solver controls unchanged.

## Why A2C exists

Two looser candidates were rejected on replicated coupled robustness:

- A2 at `1e-4`;
- A2B at `1e-6`.

Both delivered strong local speedups and small state errors, but at least one independent live MODFLOW replica produced a new SWAP trial failure.

A2C moved two orders of magnitude back toward the exact reference.

## 20-step material/regime matrix

Across B01/B12/O05/O14 wet/mid/dry:

- all 12 cases converged;
- median speedup approximately `27.9%`;
- minimum case speedup approximately `9.6%`;
- maximum relative pressure-head deviation approximately `3.54e-10`;
- maximum final-head relative deviation approximately `2.36e-10`;
- maximum relative water-content deviation approximately `2.99e-11`;
- maximum relative bottom-flux deviation approximately `1.79e-10`;
- maximum cumulative bottom-exchange relative deviation approximately `5.70e-11`.

Hard-case nonlinear work was still materially reduced. Examples:

- B01-wet: 250 -> 174 nonlinear iterations;
- O05-wet: 236 -> 165;
- O14-wet: 180 -> 126.

## Canonical production application sequence

A 20-step production application sequence passed with:

- speedup approximately `15.7%`;
- exact and A2C accepted substeps identical;
- zero retries in both arms;
- zero canonical mass residual in both arms;
- zero cumulative net-flow difference;
- zero cumulative storage difference;
- zero maximum step-net difference.

That application fixture did not reduce the reported nonlinear count, so its speedup should not be interpreted as a simple iteration-count ratio.

## Replicated live SWAP + MODFLOW6 gate

Three independent jobs were required.

All three passed.

For every replica:

- final MODFLOW head was exactly identical to the exact arm;
- final SWAP groundwater exchange flux was exactly identical;
- cumulative accepted interface ledger exchange was exactly identical;
- coupled iteration count remained 2 in both arms;
- no new SWAP trial failure occurred.

Measured coupled-loop speedups:

- approximately `2.86%`;
- approximately `13.94%`;
- approximately `12.25%`.

Median:

approximately `12.25%`.

Mean:

approximately `9.69%`.

The coupling loop is sub-millisecond in this fixture, so the spread is treated as timing variance. The robust coupled claim is 3/3 successful, speed-positive runs with exact endpoint identity.

## Decision

The `1e-8` joint convergence envelope is qualified.

Unlike A2 and A2B, A2C passed the replicated coupled robustness gate.

The exact default remains authority.

## Remaining admission work

The solver already exposes the four tolerance values as production parameters.

Before A2C can be called a production practical mode, the repository still needs:

1. an explicit default-OFF opt-in marker;
2. deterministic binding of that marker to the qualified `1e-8` tolerance quartet;
3. explicit provenance in production diagnostics/observation;
4. parent-vs-current default-off identity;
5. re-run of the A2C qualification gates against the real opt-in implementation rather than a test-local parameter override.

No new solver equation or separate numerical algorithm is required.
