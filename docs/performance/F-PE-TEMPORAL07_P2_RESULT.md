# F-PE-TEMPORAL07 P2 result

Date: 2026-09-26

Status: `BLOCKED_BY_DYNAMIC_ENDPOINT_AUTHORITY_NOT_C065_ATTRIBUTABLE`

## Protocol

P2 binds the frozen c=0.65 dynamic O14-mid corrector response into the admitted one-SWAP/one-MODFLOW-cell fixed-interface closeout architecture.

The existing production contract is preserved:

- accepted-trajectory dq_swap/dH relinearization;
- live MODFLOW6 6.8.0 prepared solve;
- same accepted SWAP origin for all correctors;
- rejected trials have zero authority;
- all preflights before publication;
- MODFLOW -> SWAP -> ledger publication;
- exactly-once accepted interface mass.

The independent endpoint search inherited from the historical closeout required one harness-only bracket repair because the dynamic-origin flux scale placed the root outside the old fixed +/-2e-6 m search interval. The acceptance tolerances were not changed.

## c=0.65 live result

Frozen budget:

`0.02742801138756619 cm`

Production coupling:

- converged in 4 coupled iterations;
- final head: `-0.75000062715641813 m`;
- final q_swap: `9.9710423475088018e-08 m/s`;
- final q_groundwater: `9.9710423475088098e-08 m/s`;
- production external residual: `-7.9409338805090657e-23 m/s`.

Independent endpoint oracle:

- bracket half-width required: `8e-6 m`;
- independent endpoint head: `-0.75000062715507554 m`;
- endpoint oracle residual: `1.3951281150878568e-16 m/s`;
- production versus independent head error: `-1.3425927036792018e-12 m`.

The frozen endpoint-head gate passes.

MODFLOW and publication gates:

- native model balance: PASS;
- API component identity: PASS;
- stopping-flow gate: PASS;
- corrector relinearization: PASS;
- rejected-trial zero authority: PASS;
- publication order: PASS;
- exactly-once mass: PASS.

However, the historical independent q(H) fit evaluated at the production endpoint gives:

`2.7351284738496517e-14 m/s`

which exceeds the frozen `1e-15 m/s` independent physical residual gate.

Therefore c=0.65 cannot be admitted from P2 under the current endpoint authority.

## c=0.50 causal attribution comparator

A separately preregistered comparator repeated the same dynamic O14-mid live setup and changed only:

`c = 0.50`

Result:

- independent endpoint head: `-0.75000062586326399 m`;
- endpoint oracle residual: `1.5049938470004559e-16 m/s`;
- production versus independent head error: `-1.3421486144693517e-12 m`;
- independent physical residual at production endpoint:
  `2.7354625687903394e-14 m/s`;
- production q_swap/q_groundwater residual:
  approximately `-7.94e-23 m/s`;
- independent physical residual gate: FAIL.

The c=0.50 and c=0.65 failures are equal to the reported precision for the quantity that blocks admission.

## Attribution

The P2 residual failure is not attributable to the selected c=0.65 coefficient.

Both policies:

- converge on the production coupled residual;
- satisfy the frozen endpoint-head gate;
- satisfy MODFLOW model/component balance;
- preserve mass and transaction invariants;
- miss the historical independent physical residual gate at essentially the same `2.735e-14 m/s` scale.

This localizes the blocker to dynamic-origin endpoint qualification, specifically the inherited independent q(H) oracle / stopping-resolution relationship, rather than to c=0.65 response semantics.

## Decision

P2 does not pass the frozen admission gate.

TEMPORAL07 therefore cannot claim production admission.

At the same time, P2 does not provide evidence for rejecting c=0.65 relative to c=0.50.

The direct next work belongs in a separate dynamic-origin endpoint-authority workunit. That work must resolve why the historical independent residual gate is inconsistent with two production-coupled solutions whose heads agree with the independent endpoint to about 1.34e-12 m and whose production residuals close to about 1e-22 m/s.

No acceptance tolerance is changed in TEMPORAL07.
