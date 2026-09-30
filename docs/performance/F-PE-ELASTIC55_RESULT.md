# F-PE-ELASTIC55 — multi-profile mode-7 defect scaling holdout result

Date: 2026-09-30

Status: QUALIFIED_RESEARCH_RESULT

Branch:
`research/f-pe-elastic55-multiprofile-holdout`

Qualified postimage:
`730ce1edc3d4e2b595f14dc978500c388f34f02f`

Canonical baseline:
`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`

Workflow run:
`36675146027`

Job:
`109758392158`

Conclusion:
SUCCESS.

## Question

Does the ELASTIC54 frozen global conservative relation

`H_INF <= 0.17320259355765216 * Binf`

survive independent BRO/BOFEK profile/material holdout without refitting?

## Deterministic profile selection

The preregistered selection algorithm chose exactly four independent profiles
from the frozen BRO GeoPackage:

1. profile `11060`
   - soilunit `Zn30A`;
   - 1 horizon;
   - Staringreeks blocks `[205]`.

2. profile `10260`
   - soilunit `Zd30`;
   - 2 horizons;
   - blocks `[105,205]`.

3. profile `8016`
   - soilunit `EZg21`;
   - 3 horizons;
   - blocks `[101,101,201]`.

4. profile `3030`
   - soilunit `gY30`;
   - 4 horizons;
   - blocks `[105,205,205,205]`.

Profile `90116260`, used in ELASTIC46-54, was excluded by preregistration.

For each selected profile:
- source horizons came from the same frozen BRO artifact;
- geometry was materialized into the same 16-node representation rule;
- admitted Staringreeks-2018 `wcr,wcs,alpha,npar` varied by source block;
- Ksat/lambda remained frozen to the parent fixture because this ELASTIC source
  chain does not contain an admitted full Ksat/lambda catalog;
- GENERATED Ss was materialized independently from the selected source profile.

No profile was hand-picked after numerical results.

## Bank

Per profile:
- 4 initial states: `-75,-20,+2,+10 cm`;
- 4 perturbations: `-0.05,-0.035,+0.035,+0.05 cm/day`;
- OFF, FIXED_1E6 and GENERATED;
- 9-step dt retry ladder.

Total requested cases:
`4 * 432 = 1728`.

Qualification:
- all requested cases executed;
- O0/O2 semantic identity passed per profile;
- Binf was finite/nonnegative whenever full solve converged;
- realized H_INF was used only for paired full+half1+half2 convergence;
- alpha remained exactly frozen from ELASTIC54;
- zero `src/**` production changes.

## Primary result

The global ELASTIC54 envelope survived the entire paired multi-profile holdout.

Aggregate:
- full-converged observations: `1089`;
- paired full/half observations: `801`;
- envelope failures: `0`;
- maximum realized `H_INF/Binf = 0.08983446673654746`.

Frozen limit:
`alpha_global = 0.17320259355765216`.

The worst realized ratio is therefore approximately 52% of the frozen global
limit.

Classification of the primary envelope test:

`MULTIPROFILE_HOLDOUT_PASS`.

## Per-profile maximum realized ratio

### profile 11060, Zn30A

- paired observations: `200`;
- maximum ratio: `0.08983447`;
- generated Ss range:
  `3.8092882e-6 ... 3.8092882e-6 cm^-1`.

Regime maxima:
- OFF: `0.0234553`;
- FIXED_1E6: `0.0560064`;
- GENERATED: `0.0898345`.

### profile 10260, Zd30

- paired observations: `205`;
- maximum ratio: `0.0778700`;
- generated Ss range:
  `3.4545299e-6 ... 4.0448203e-6 cm^-1`.

Regime maxima:
- OFF: `0.0136267`;
- FIXED_1E6: `0.0628452`;
- GENERATED: `0.0778700`.

### profile 8016, EZg21

- paired observations: `170`;
- maximum ratio: `0.0765775`;
- generated Ss range:
  `2.5640257e-6 ... 3.0948251e-6 cm^-1`.

All three regimes reached the same reported maximum ratio:
`0.0765775`.

### profile 3030, gY30

- paired observations: `226`;
- maximum ratio: `0.0797879`;
- generated Ss range:
  `4.0798204e-6 ... 4.8054990e-6 cm^-1`.

Regime maxima:
- OFF: `0.0339243`;
- FIXED_1E6: `0.0528041`;
- GENERATED: `0.0797879`.

## New caveat: Binf monotonicity is not universal

ELASTIC54 observed zero monotonicity violations over its 41 eligible sequences.

ELASTIC55 broadened retention material and profile geometry and found:

- eligible sequences with at least three full-converged Binf points: `170`;
- monotonicity violations under decreasing dt: `15`.

Per profile:
- 11060: 1 violation / 40 sequences;
- 10260: 5 / 43;
- 8016: 4 / 44;
- 3030: 5 / 43.

Therefore the statement

`Binf always decreases monotonically as dt decreases`

is falsified over the broader retention-material bank.

This does not falsify the frozen global conservative envelope:
all 801 paired observations still satisfy it.

It does mean Binf cannot yet be assumed to be a universally monotone controller
signal across arbitrary profile/material combinations.

## Interpretation

ELASTIC55 materially strengthens one part of the ELASTIC54 result and weakens
another.

Strengthened:
- the global conservative scaling was not specific to profile 90116260;
- it survived four independently selected profile geometries/material
  signatures;
- it survived 801 directly observed full-versus-two-half endpoint comparisons;
- the observed worst-case ratio remained well inside the frozen envelope.

Weakened:
- monotonic Binf refinement behavior is not universal across the broader
  profile/material space.

This distinction matters.

A conservative error envelope can remain valid even when the indicator itself
is locally non-monotone with dt. Such non-monotonicity may still complicate an
adaptive timestep controller, because a controller generally benefits from a
predictable relation between refinement and indicator reduction.

## Hypothesis outcome

Frozen global scaling survives multi-profile holdout:
SUPPORTED, 0 / 801 failures.

Profile/material independence within the tested retention envelope:
SUPPORTED for the four preregistered independent profiles.

Universal monotonic Binf decrease with dt:
FALSIFIED, 15 violations over 170 eligible sequences.

Production-readiness of the controller signal:
NOT ESTABLISHED.

## Decision

Classification:

`QUALIFIED_MULTIPROFILE_GLOBAL_ENVELOPE_RESEARCH_CANDIDATE_WITH_MONOTONICITY_CAVEAT`.

No production admission is authorized.

The next bounded workunit should attribute the 15 monotonicity violations:
- identify their profile/state/regime/forcing/dt locations;
- distinguish genuine indicator non-monotonicity from convergence-window
  discontinuity;
- quantify violation magnitude;
- determine whether a controller can remain stable with a conservative
  envelope despite local non-monotonicity.

Only after that attribution should end-to-end timestep-controller integration or
production admission be considered.
