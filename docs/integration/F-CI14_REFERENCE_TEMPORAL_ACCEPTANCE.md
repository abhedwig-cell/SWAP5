# F-CI14 — Reference Temporal Acceptance Contract

## Scope

F-CI14 defines the temporal accept/retry contract needed by the B1.10 full-accuracy reference transaction path. It does not change SWAP physics, HeadCalc, constitutive relations, Jacobians, nonlinear convergence criteria, internal timestep reduction, mass tolerances or calendar-event rules.

## Key semantic correction

F-CI12 characterized both endpoint state and lagged continuation variables. F-CI14 makes their roles explicit.

`h`, `theta`, `pond`, `gwl`, `volact`, `ldwet`, `spev` and `saev` represent endpoint quantities at the requested trial endpoint and may participate in a full-versus-two-half temporal comparison.

`hm1`, `thetm1`, `pondm1` and `gwlm1` are former-time-level continuation variables. Legacy `SoilWaterStateVar(1)` overwrites them from the current state before an internal soil-water step. Therefore a full trial and a two-half trial can end at the same `t1` while these lagged values legitimately refer to different preceding internal time levels. F-CI14 keeps their F-CI12 differences as diagnostics but excludes them from temporal acceptance.

## Unit-aware normalization

`mod_b1_10_reference_temporal_policy` requires eight explicit limits:

- pressure head `h` [cm];
- volumetric water content `theta` [-];
- ponding depth [cm];
- groundwater level [cm];
- soil-column water storage `volact` [cm];
- Black evaporation-memory length `ldwet` [cm];
- cumulative potential evaporation-memory `spev` [cm];
- cumulative actual evaporation-memory `saev` [cm].

No numerical defaults are supplied. An unconfigured policy is invalid and fails closed.

For a configured candidate profile each physical difference is first divided by its own same-unit limit. Only those dimensionless ratios are combined, using their maximum. A normalized error <= 1 means every endpoint criterion is within its explicit limit. A zero limit means exact equality is required for that metric.

This scalar is therefore not an arbitrary mixing of heads and water contents: the unit conversion/acceptance meaning resides in the explicit per-metric reference policy.

## Optional process state

F-CI12 does not yet characterize thermal, solute, irrigation, crop or WOFOST state numerically. If any such optional state is active, `process_scope_complete` is false and F-CI14 temporal assessment remains incomplete. It does not silently ignore active physics.

## Numerical profile deliberately not admitted

The canonical VQ material contains no independently qualified temporal limits for this full-versus-two-half comparison. F-CI14 therefore materializes an executable **candidate-policy** model only. It can be used by qualification/calibration harnesses, but `reference_execution_admitted()` remains false because `qualified_numeric_profile` is false.

Solver convergence criteria such as `CritDevBalCp`, `CritDevBalTot`, `CritDevh*`, `dtmin` and `MaxIt` are not reused as temporal-accuracy tolerances. Doing so would mix nonlinear solver policy with time-discretization accuracy.

## Focused executable gate

The F-CI14 deterministic backend introduces a controlled `O(dt^2)` endpoint bias while maintaining exact trial mass closure. The O0/O2 test proves:

- no-default fail-closed policy;
- unit-aware endpoint normalization;
- lagged continuation differences do not trigger temporal rejection;
- an endpoint limit exceedance does trigger rejection;
- optional process state remains fail-closed;
- the existing generic reference transaction can consume normalized error with threshold 1.0;
- a rejected full interval rolls back and retries at half the interval;
- accepted state remains the two-half route;
- hard mass accounting remains unchanged.

This is a contract test, not numerical qualification of a B1.10 temporal tolerance profile.

## Remaining qualification hold

A production B1.10 reference temporal policy still requires independent calibration/qualification of the eight endpoint limits over representative B1.10 cases and difficult columns, with explicit provenance and sensitivity evidence. Optional active process classes require their own temporal characterization before admission.

Until that evidence exists, B1.10 `execute_reference_interval` remains not admitted as a production reference entrypoint.
