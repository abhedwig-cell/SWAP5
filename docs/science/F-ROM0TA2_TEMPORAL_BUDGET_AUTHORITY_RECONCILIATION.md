# F-ROM0TA2 — Temporal budget authority reconciliation

## Decision

**TEMPORAL_AUTHORITY_REQUIRES_NEW_REFERENCE_CAPABILITY**

F-ROM0TA2 reconciles the ROM-0 temporal-authority evidence against the already admitted application-accuracy governance. It does not select a numeric head budget and does not modify production/reference source.

## Reconciled authorities

### ROM-P / ROM-0

The governing ROM proposition requires the numerical Reference floor to be established before projection error is interpreted. ROM-P explicitly defers the error envelope until ROM-0 has measured numerical/reference reproducibility and the capability need is visible.

The first ROM capability is pure one-column hydraulics. Its primary reduced-output quantities are accepted total storage, fixed upper/lower band storage, top exchange, bottom exchange and mass diagnostics. Pressure-head and water-content profiles are retained as diagnostic explanatory state, not as the primary reduced-output accuracy contract.

### F-GC07 / F-GC08 / F-GC09 / F-GC10

The independent coupling programme already resolved the generic policy question that F-ROM0TA1 reached.

F-GC07 qualifies numerical temporal/coupling characterization but explicitly does not instantiate an application accuracy requirement or universal allocation coefficient.

F-GC08 establishes the leakage rule: a numerical error magnitude, decision threshold, solver closure criterion, calibration residual or measurement detectability does not become application prediction accuracy merely because it is available. A numeric temporal budget requires an independently governed application accuracy requirement and an independently governed allocation rule.

F-GC09 materializes that governance as:

`H_temporal_budget = H_app * A_temporal`

where both inputs are explicitly available, separately qualified and provenance-bound. Absence fails closed.

F-GC10 confirms the current Reference-Richards model binding:

`C_h = B_inf / H_temporal_budget`

and explicitly retains the nonclaims: no universal `H_app`, no universal `A_temporal`, no numeric project budget.

Those semantics are now canonically admitted by the later F-CI44 path.

## F-ROM0TA1 result

The preregistered B01/B14 matrix showed:

- 8/8 direct full/refined Reference comparisons converged;
- 8/8 F-SI38 indicators available;
- 8/8 within the frozen hard mass gate;
- no empirical `B_inf` underestimation on the finite matrix;
- `B_inf / max|h_full-h_2half|` approximately 138 to 3620;
- actual full-versus-two-half head difference approximately second order under dt halving;
- `B_inf` approximately first order under dt halving.

So the mechanism is usable but strongly non-tight. This evidence cannot choose an application/scientific budget.

## The circularity

The current model-certificate transaction requires a positive native head budget before a transient step can be accepted.

For an application/coupling run that is correct: external application accuracy owns the budget.

For ROM-0 Reference-floor construction it is not sufficient, because:

1. ROM-P says the ROM error envelope is set only after the Reference numerical floor is visible.
2. ROM-0 needs an accepted transient trajectory to establish that floor.
3. F-GC governance forbids deriving `H_app` or `A_temporal` from the numerical error being characterized.
4. Therefore using the existing application-budget route to construct the prerequisite floor would make the reference instrument depend on the downstream tolerance it is supposed to inform.

This is an authority circularity, not a failure of F-SI38 mathematics or FMR history transport.

## Rejected shortcuts

The following do not resolve the circularity:

- reuse the FMR44R qualification-only `2.5e-11 cm` budget;
- set `H_budget` equal to measured `B_inf`;
- set `H_budget` equal to measured full-versus-two-half head difference;
- choose a fixed fraction of either after seeing the data;
- reinterpret nonlinear solver tolerances as temporal accuracy;
- use the existing F-GC09/F-GC10 coupling contract with a fabricated ROM `H_app`;
- accept a direct Reference solver attempt as committed trajectory authority;
- increase retries/iterations or reduce the 1% perturbation until the old R2 route passes.

## Required successor capability

ROM-0 requires a separate **Reference-floor qualification capability** whose semantics are distinct from application temporal acceptance.

Minimum contract:

1. Purpose is numerical Reference-floor construction only.
2. It uses the existing Reference-Richards physics/solver and existing transactional state ownership.
3. It must preserve solver failure, mass closure, rollback and commit provenance.
4. It must not require an application accuracy budget to exist before the floor can be measured.
5. It must expose a preregistered temporal-resolution ladder and common physical horizons.
6. It must keep every resolution-specific trajectory distinct; no rejected candidate may become accepted evidence.
7. It must support exact replay/restart qualification of the selected floor trajectory.
8. It must publish the output-specific floor for the ROM-P capability outputs, including upper/lower band storage and exchanges, not only pressure head.
9. It must not silently become a production timestep policy.
10. Promotion from qualification instrument to any production Reference policy would require a separate architecture/admission workunit.

## Architecture options for the successor

### Option A — qualification-only fixed-resolution accepted transaction mode

Add an explicitly qualification-only transaction mode that commits a converged, mass-complete Reference step at a preregistered fixed resolution without claiming application temporal adequacy. Temporal convergence is assessed between independently committed resolution ladders.

Advantage: directly separates Reference-floor measurement from application acceptance.

Risk: it creates a new transaction semantic and therefore requires explicit canonical authority. It cannot be smuggled into tests as a bypass.

### Option B — separate Reference-floor trajectory service over canonical state ownership

Create a governed service that owns checkpoint/advance/mass/commit semantics for a fixed prescribed resolution ladder, while remaining unavailable to normal application execution.

Advantage: stronger separation from production timestep selection.

Risk: if implemented outside the canonical transaction substrate it could duplicate transaction ownership. The design must prove that it composes existing checkpoint/commit primitives rather than inventing a second physical state authority.

### Option C — force the application-certificate route

Rejected for ROM-0. It requires the downstream accuracy envelope before the upstream Reference floor and violates the established F-GC provenance rule.

## Recommended architecture binding for the successor

The next design workunit should investigate Option A first because it can remain closest to the existing transaction substrate. The required semantic is not “temporal error is acceptable”; it is “this fixed-resolution trajectory is a valid committed numerical Reference sample for cross-resolution qualification.”

That distinction must be represented explicitly in type/status/provenance and may not reuse `TX_TEMPORAL_MODEL_CERTIFICATE` with a synthetic large budget.

No implementation is authorized by F-ROM0TA2 itself.
