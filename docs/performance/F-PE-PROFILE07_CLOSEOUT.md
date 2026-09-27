# F-PE-PROFILE07_CLOSEOUT — post-TEMPORAL08 production performance rebaseline

Date: 2026-09-27

Status: `CLOSED_OBSERVATION_ONLY`

PR:
`#658 — F-PE-PROFILE07: post-TEMPORAL08 performance rebaseline`

Branch:
`work/f-pe-profile07-post-temporal-rebaseline`

Parent:
`#655 — F-PE-TEMPORAL08`

Measured head:
`d87616401d5f8e5f98b7946364d5536bdb7b5c38`

PROFILE07 changed no production source under `src/**`.

## Purpose

PROFILE07 rebuilt the runtime hotspot map after production admission of the frozen c=0.65 history-aware temporal budget. It also rechecked already qualified practical opt-ins so the next decision is based on the fastest qualified components rather than default-only execution.

## Current measurements

### Repeated application / Reference decomposition

Current-head N=10,000 application timing:

- median application runtime: `7641.2124 ns/column`;
- Reference backend share: `90.575221%`.

An earlier independent PROFILE07 run on the same parent stack measured:

- application median: `6420.9079 ns/column`;
- Reference share: `84.838675%`.

CI wall-clock variance is therefore material. The robust interpretation is not a single exact percentage, but that roughly 85-91% of this clean repeated application fixture remains inside the Reference / transaction backend.

The clean fixture reports per column:

- 1 application solver execution;
- 3 accepted internal solves;
- 3 nonlinear iterations;
- 3 Jacobian builds;
- 3 linear solves;
- 3 headcalc calls;
- zero internal retries.

Thus each accepted internal solve already converges in one nonlinear iteration in this fixture.

### Temporal c=0.65

The selected policy was reproduced on the current head:

- requests: 768;
- completed: 768;
- failures: 0;
- retries: 384;
- temporal rejections: 384;
- solver rejections: 0;
- fresh tangents: 96;
- tangent reuses: 672;
- median selected / c=0.50 runtime ratio: `0.743207083`.

An earlier PROFILE07 replicate measured `0.732890711`.

The planning statement is therefore that c=0.65 reduces this repeated-sequence runtime by about one quarter relative to c=0.50 while halving retries. There is no evidence here for immediately retuning the frozen coefficient.

The historical TEMPORAL06 O14-mid tangent-overlap negative remains reproduced as expected. It is not reinterpreted as a current production failure because later tangent and endpoint authority work resolved the publication issue before TEMPORAL08 admission.

### Practical Richards A2C

The production binding passes with the qualified values:

- head absolute tolerance: `1e-8`;
- head relative tolerance: `1e-8`;
- compartment balance tolerance: `1e-8`;
- total balance tolerance: `1e-8`.

The corrected current-head application-sequence measurement gives:

- runtime ratio: `0.802891188`;
- speedup: `19.710881%`;
- exact nonlinear iterations: 60;
- A2C nonlinear iterations: 60;
- accepted substeps: 20 versus 20;
- retries: 0 versus 0;
- mass residual: 0 in both arms;
- cumulative net-flow and storage differences: 0 in this fixture.

A preliminary PROFILE07 run accidentally exercised the runner default `1e-4` candidate. Its much larger apparent speedup is excluded from PROFILE07 evidence. The workflow was corrected before closure.

APPROX02 has already shown that looser 1e-4 and 1e-6 envelopes fail coupled robustness despite attractive local speed. PROFILE07 therefore does not reopen tolerance ratcheting.

### Direct-retention / AHL

Three independent current-head jobs give median candidate/reference ratios:

- `0.858820942`;
- `0.829429937`;
- `0.828267592`.

All tested production cases are speed-positive.

The central planning interpretation remains approximately 15-17% repeated solver gain, with ordinary CI timing variance. This reproduces the established conclusion that shared direct-retention representation remains useful.

Code inspection is important for the next decision: the direct-retention provider accelerates water-content-only and capacity-only demand. Conductivity-containing demands fall back to the analytical MvG provider, and the directional conductivity derivative remains analytical.

Therefore AHL does not exhaust the hydraulic-table opportunity.

### Constitutive versus linear algebra

Current microkernel localization again shows the constitutive path materially more expensive than the raw tridiagonal kernels.

Representative PROFILE07 medians:

- four-node full constitutive evaluation: about `0.59 us`;
- four-node demand-routed constitutive evaluation: about `0.71 us`;
- tridiagonal solve: about `0.054 us`;
- backsolve: about `0.047 us`.

These are localization measurements, not inclusive application percentages. They nevertheless reject the raw linear solve as the next principal optimization target.

### Directional / tangent route

Current PROFILE07 bottom-head directional timing gives:

- Reference median: `8870.7252 ns/interval`;
- directional median: `15118.4900 ns/interval`;
- ratio: `1.704312743`;
- incremental cost: `+70.431274%`.

An independent PROFILE07 run measured approximately +75.8%, and the repeated-decomposition route gave approximately +78.0%.

Directional work therefore remains expensive when evaluated fresh. However, the production-shaped temporal sequence reports 96 fresh tangent evaluations and 672 tangent reuses. PROFILE07 therefore does not equate the raw +70-78% fresh-directional increment with a +70-78% coupled-loop penalty.

## Hotspot interpretation

The rebaseline changes the next-step decision.

1. General outer application orchestration is still not the dominant target. The Reference / transaction route remains the majority of clean repeated runtime.

2. Generic Newton-iteration reduction is not the strongest immediate target on current evidence. The clean fixture already needs one nonlinear iteration per accepted internal solve, and A2C has already qualified the safe tolerance frontier.

3. Temporal retry work has been materially reduced by c=0.65. Retuning c is lower priority than attacking remaining accepted-solve cost.

4. Raw linear algebra is too small to justify a dedicated optimization line.

5. Constitutive hydraulic work remains material.

6. Direct-retention proves that tabulation/representation can buy material solver speed, but its current scope leaves conductivity and conductivity derivatives analytical.

7. Fresh directional work remains expensive, and its analytical K/dKdh route overlaps naturally with the remaining constitutive target. A conductivity-focused representation can therefore be tested for both ordinary accepted solves and tangent construction rather than opening another generic tangent-orchestration workunit first.

## Decision

Exactly one immediate workunit is selected:

`F-PE-HYDTABLE01 — bounded tabulated conductivity and directional derivative representation`

The initial workunit is research-only.

Primary question:

Can the remaining analytical MvG conductivity path, including smooth-branch dK/dh where required by the accepted-trajectory tangent, be represented more cheaply without increasing nonlinear effort or changing physical/coupling semantics?

The intended candidate is complementary to direct-retention:

- retain the qualified direct-retention theta/C path where applicable;
- target K(h) and smooth-branch dK/dh;
- preserve analytical fallback at branch boundaries and outside the qualified table domain;
- share immutable representation by material/profile rather than rebuilding per column.

## Deferred tracks

### SOLVE

Further solve-effort work remains credible for genuinely difficult states, but is deferred. A new solve workunit should require evidence of avoidable nonlinear effort beyond the already qualified A2C frontier, not just the fact that Richards remains expensive.

### HISTORY

Stronger accepted-history predictors remain credible, especially for difficult transient sequences. They are deferred until HYDTABLE01 establishes how much accepted-solve cost remains after constitutive acceleration.

### MULTI-PERF

Batching, parallel execution and data-layout work remain important for the final many-column MODFLOW use case. They stay separate from single-column algorithmic optimization so scaling gains are not confused with per-column gains.

## Closure statement

PROFILE07 is closed observation-only.

The current evidence supports a narrower next target than a generic solver rewrite: accelerate the still-analytical conductivity and conductivity-derivative work, qualify its effect on solver behavior, and only then reassess whether the next large gain lies in history-aware solve avoidance or many-column parallel execution.
