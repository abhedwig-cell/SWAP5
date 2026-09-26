# F-PE-BALTOL02 closeout — production admission of scaled Reference balance floor

Date: 2026-09-26

Status: `CLOSED_PRODUCTION_ADMISSION_QUALIFIED`

## Production change

The serialized Reference backend now derives effective per-solve balance-rate tolerances as:

`effective_compartment = max(configured_compartment, 2.8e-16 cm / dt)`

`effective_total = max(configured_total, 2.8e-16 cm / dt)`

The configured parameter values themselves remain unchanged.

Only compartment and total balance convergence tolerances are affected.

Head tolerances, ponding tolerance, mass acceptance, temporal-certificate budget, nonlinear iteration caps, backtracking policy and practical/A2C tolerance ownership are unchanged.

Effective Reference tolerances are exposed in the serialized physical observation for auditability.

## Qualification

### G1/G2 request semantics

PASS.

Verified:

- strict configured tolerance is preserved whenever it is already above the numerical floor;
- the scaled floor is applied when the configured rate would fall below representable integrated-depth resolution;
- a looser configured tolerance remains authoritative.

### G3 difficult/oracle replay

PASS.

- broad difficult BALTOL01 matrix replay: PASS;
- recovered N=8/16/32 fixed-substep oracle: PASS;
- N=64 refinement exception closeout: PASS.

### G4 current-lineage regression authority

PASS for the authorities attributable to this production delta.

Green suites include:

- F-CI110 reconstructed performance admission;
- F-PE-APPROX02 exact/default, multistep, application-sequence and MODFLOW end-to-end qualification;
- zero-waste poison/runtime and current performance recomposition;
- canonical replay authorities through restart, Reference ET, forcing, root attribution, PTRA ownership, root uptake and related current-lineage checks.

Historical exact-source/postimage preservation jobs fail because BALTOL02 intentionally changes the serialized Reference backend. Those failures are source-identity guards, not behavioral regressions.

The remaining restricted-canonical preservation failure is inherited from the parent stack and reports drift in `src/transaction/mod_transaction_reference.f90`. That file is bit-identical between BALTOL02 base and head and is therefore outside BALTOL02 attribution.

## Scientific basis

The admitted rule is not an arbitrary relaxation.

It is anchored to BALTOL01 and earlier PUB-P2E06/P2E07 evidence that the limiting Reference residual floor scales approximately as a fixed integrated water-depth resolution dominated by representable theta-state resolution.

The qualified depth floor is:

`2.8e-16 cm`.

Across the difficult qualification domain this floor:

- recovers all known tolerance-floor failures;
- loses no strict successes;
- preserves state and flux to negligible numerical differences;
- retains complete mass accounting;
- restores the independent refined temporal oracle.

## Decision

The dt-scaled Reference balance floor is admitted in production on this branch.

No temporal-policy relaxation is admitted here.

No surrogate is reopened here.

## Next step

After parent/canonical admission, resume the temporal-policy line using the recovered refined Reference oracle. The next workunit should compare dynamic-history temporal-certificate candidates directly against that oracle and determine whether the current certificate should remain fixed, become history-aware/scaled, or be replaced by another exact acceptance strategy.