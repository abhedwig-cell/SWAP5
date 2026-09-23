# TAB-HYD-KX04 — typed Reference-Richards KSATEXM solver gate preregistration

Date: 2026-09-23

Status: **PREREGISTERED_RESEARCH_ONLY**

## Entry authority

KX03 constitutive PASS:

- run `35858102782`;
- zero global/local F-SI39 branch mismatch;
- explicit F-SI39 active-branch K exactly equal to canonical;
- base raw-head400 theta/C/K errors inside the established generated-provider envelope.

Current canonical:

- `integration/f-ci-canonical@a2d99ddd149ffaa422d9c422f96bd66e92c8555d`.

## Research question

When the generated K0 provider retains F-SI39 as the explicit analytical sub-branch qualified by KX03, does the typed Reference-Richards solver reproduce the canonical analytical-F-SI39 trajectory for a controlled two-layer Hupsel column without changing solver settings?

## Controlled column

Use the existing four-node Reference-Richards research seam and assign:

- nodes 1-2: exact Hupsel upper hydraulic material;
- nodes 3-4: exact Hupsel lower hydraulic material.

This preserves the exact two material authorities while remaining a bounded solver test. It is not the exact whole-Hupsel 34-compartment application profile.

Exact material values are the recovered M1-C3/F-SI39 values:

Upper:
- theta_r=0.02;
- theta_s=0.433878;
- alpha=0.021645 /cm;
- n=1.34877;
- Ksatfit=83.24164 cm/d;
- l=7.202077;
- KSATEXM=832.4163 cm/d;
- H_ENPR=0.

Lower:
- theta_r=0.02;
- theta_s=0.387064;
- alpha=0.016083 /cm;
- n=1.524418;
- Ksatfit=22.76176 cm/d;
- l=2.439662;
- KSATEXM=227.6176 cm/d;
- H_ENPR=0.

F-SI39 threshold metadata must be derived exactly from the source hthr=-2 cm formulas, not hard-coded approximations.

## Cases

Use identical K0 numerical settings in analytical and generated routes.

1. `below_threshold`
   - initial head = -5 cm;
   - explicit top flux = +0.02 cm/d;
   - prescribed bottom flux = 0;
   - step duration = 0.04 d.

2. `transition`
   - initial head = -2 cm;
   - explicit top flux = +0.02 cm/d;
   - prescribed bottom flux = 0;
   - step duration = 0.04 d.

3. `active_extension`
   - initial head = -1 cm;
   - explicit top flux = +0.02 cm/d;
   - prescribed bottom flux = 0;
   - step duration = 0.04 d.

If a case does not converge under the unchanged shared solver settings, classify the failure; do not tune tolerances or forcing after observing the result.

## Frozen solver settings

Use the same settings for both providers:

- SWKIMPL=0;
- arithmetic K mean;
- max nonlinear iterations = 16;
- max backtracking = 8;
- min step = 1e-8 d;
- compartment and total balance tolerance = 1e-10;
- head absolute/relative tolerance = 1e-10;
- ponding tolerance = 1e-10.

No root sink, drainage, macropore, frost or dynamic top-boundary process is active.

## Scientific gates

Both routes must converge.

Candidate versus analytical:

- head max abs <= 0.05 cm;
- head RMS <= 0.01 cm;
- theta max abs <= 0.02;
- |analytical mass residual| <= 1e-8 cm;
- |candidate mass residual| <= 1e-8 cm;
- top-flux and bottom-flux differences reported;
- mass-residual difference reported;
- nonlinear iterations and linear solves reported for both routes.

No exact iteration-count equality is preregistered as a scientific gate.

## Performance

Order-balanced repeated timing may be collected because both providers are already research-qualified for cost characterization. Performance is secondary to scientific closure.

Do not generalize from this four-node solver gate to whole-Hupsel runtime.

## Decision

If all three regimes pass, KX03 is solver-qualified for a bounded exact-Hupsel-KSATEXM material envelope and may be handed back to F-TAB02 for a separately owned production-scope decision.

If any regime fails, stop before changing F-TAB02 and diagnose the solver-level discrepancy.
