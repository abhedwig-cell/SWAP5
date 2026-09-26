# F-PE-TEMPORAL07 P0 result

Date: 2026-09-26

Status: `QUALIFIED_PASS`

Preregistration:

`docs/performance/F-PE-TEMPORAL07_PREREGISTRATION.md`

Harness:

`tests/fpe/run_fpe_temporal07_p0_linear_response.sh`

## Scope

The frozen c=0.65 response was evaluated on ten difficult dynamic origin/history groups:

- B01 wet;
- B12 wet;
- O05 wet;
- O14 wet;
- O14 mid;
- history imbalance -0.10 and +0.10.

For each group the fresh c=0.65 q(H) response and accepted-trajectory tangent were evaluated with tangent caching disabled.

The affine response

`q_linear(H+dH) = q(H) + dq/dH * dH`

was compared to an independent c=0.65 trial from the same captured origin.

## Result

All center and probe candidates completed.

No solver rejection occurred.

Maximum relative q linearization error:

- through +/-0.01 cm: `1.20277135053985114e-06`;
- through +/-0.05 cm: `4.83999642543446202e-03`;
- through +/-0.10 cm: `1.01380407741323685e-02`.

Frozen gates:

- <=1% at +/-0.01 cm: PASS;
- <=2% at +/-0.05 cm: PASS.

The +/-0.10 cm arm was characterization only.

## Temporal path changes

Twelve wider probe points changed temporal path.

The clearest case is O14 mid:

- center: one accepted full-window step, zero retry;
- sufficiently large head perturbation: two accepted half-window steps, one retry.

Even across that path change, the +/-0.05 cm linearization error remained below 0.5%.

## Decision

P0 passes.

The c=0.65 accepted-trajectory tangent provides a bounded local MODFLOW-facing affine response for the tested dynamic origins under the preregistered limits.
