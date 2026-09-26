# F-PE-APPROX02 A2C production binding preregistration

Date: 2026-09-26

Status: `PREREGISTERED_NOT_IMPLEMENTED`

Qualified envelope:
`A2C — joint local Richards convergence tolerances = 1e-8`

## Purpose

Bind the already qualified A2C envelope to one explicit production opt-in without creating a new solver algorithm.

## Production surface

Add one parameter flag:

`practical_richards_a2c_active`

Default:

`false`

When false:
- existing parameter values remain untouched;
- exact/default behavior must remain parent-identical.

When true:
- head absolute tolerance = `1e-8`;
- head relative tolerance = `1e-8`;
- compartment balance tolerance = `1e-8`;
- total balance tolerance = `1e-8`;
- ponding tolerance remains unchanged;
- transaction mass tolerance remains unchanged;
- timestep, retry, iteration and backtracking policy remain unchanged;
- constitutive physics remain unchanged.

## Provenance

The serialized production observation must expose:

- whether A2C was active;
- the effective four local Richards convergence tolerances.

The approximate route may not be represented as exact/default provenance.

## Hard constraints

No change to:
- solver equations;
- constitutive laws;
- transaction mass accounting;
- temporal policy;
- default numerical values;
- A1 tangent-cache configuration.

## Admission gates

1. parent-vs-current default-off identity;
2. explicit opt-in tolerance binding check;
3. explicit observation/provenance check;
4. 20-step A2C material/regime matrix;
5. canonical application-sequence mass gate;
6. three independent live MODFLOW6 A2C replicas.

## Rejection rule

Reject the production binding if default-off output drifts, if effective tolerances differ from the qualified quartet, or if any previously qualified A2C gate regresses.
