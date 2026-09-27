# F-PE-APPROX02 A2B result — conservative Richards convergence envelope

Date: 2026-09-26

Status: `REJECTED_COUPLED_ROBUSTNESS`

Candidate:
joint head + compartment/total balance tolerances of `1e-6`, with all other solver controls unchanged.

## Positive evidence

A2B was strongly positive in local and application-shaped tests.

### 20-step production material/regime matrix

Across B01/B12/O05/O14 wet/mid/dry:

- all 12 cases converged;
- median speedup approximately `37.5%`;
- minimum speedup approximately `25.9%`;
- maximum relative pressure-head deviation approximately `5.35e-8`;
- maximum relative water-content deviation approximately `2.96e-9`;
- maximum relative bottom-flux deviation approximately `3.37e-8`;
- maximum cumulative bottom-exchange relative deviation approximately `5.59e-9`.

The nonlinear work reduction was large in the hard cases, for example:

- B01-wet: 250 -> 138 nonlinear iterations;
- O05-wet: 236 -> 130;
- O14-wet: 180 -> 97.

### Canonical production application sequence

A 20-step production application sequence passed with:

- speedup approximately `24.1%`;
- exact and A2B nonlinear counts both 60 in that particular application fixture;
- identical accepted substeps;
- zero retries in both arms;
- zero canonical mass residual in both arms;
- zero cumulative net/storage difference in the qualified sequence.

This confirms that A2B can be materially faster even when the application fixture does not reduce the diagnostic nonlinear count, likely through cheaper internal convergence work.

## Replicated live SWAP + MODFLOW6 gate

Three independent jobs were required.

Two replicas passed and produced exact coupled endpoint identity:

- final MODFLOW head identical;
- final SWAP groundwater exchange flux identical;
- final accepted interface ledger identical;
- coupled iteration count identical.

Measured coupled-loop speedups in the two successful jobs:

- approximately `21.0%`;
- approximately `6.1%`.

However, the third independent job failed in the A2B arm before the coupling loop at the first SWAP corrector probe:

`GW_SWAP_PARTICIPANT_TRIAL_FAILED (status 6)`

The exact arm did not show this failure.

This is the same failure class that caused rejection of A2 at `1e-4`.

## Decision

A2B is rejected as a production-shaped opt-in.

The A2B preregistration explicitly states that any replicated live MODFLOW job showing a new SWAP trial failure is sufficient for rejection.

Two successful replicas do not override one independent failure.

No production default is changed.

## Interpretation

The direct and multistep error frontier remains scientifically useful:

- relaxing the local Richards convergence criteria to `1e-6` can remove roughly one third to one half of local solver runtime in hard cases;
- hydrological trajectory deviations remain extremely small in the tested matrix;
- canonical mass accounting can remain exact.

But coupled robustness is not yet sufficiently reliable at this envelope.

The limiting issue is therefore no longer state-error magnitude. It is trial robustness under production-shaped coupled corrector execution.

## Handoff

The next candidate must be more conservative than `1e-6`.

A2C will test `1e-8` joint head + compartment/total balance tolerances with all other controls unchanged.

A2C must pass the same replicated live MODFLOW gate. If a new trial failure still appears, fixed tolerance relaxation should be considered unsuitable as a production practical mode and APPROX02 should shift to a different solve-effort lever rather than continue ratcheting tolerances indefinitely.
