# F-PE-TIMEARCH16 result — wet-zone AUTO eligibility guard

Date: 2026-09-28

Status: `CALIBRATION_ADVANCES_GUARD_M5`

Canonical base:

`integration/f-ci-canonical@284f658d7b19efde1da728e3521a40186221eb05`

Evidence:

- Actions run: `36433526041`;
- discovery job: `108965494453`;
- conclusion: SUCCESS.

## Candidate family

TIMEARCH15 flux-regime AUTO -> LEGACY_SAFE state machine was retained unchanged.

The only new rule was a permanent fallback from AUTO when an accepted FLUX endpoint top pressure head exceeded a frozen wet-zone guard.

Frozen guards:

- GUARD_M20: -20 cm;
- GUARD_M10: -10 cm;
- GUARD_M5: -5 cm.

## Result

All three candidates satisfy the frozen calibration gate.

### GUARD_M20

- P-C1: 16/16;
- all WET/POND: PASS;
- median deterministic work reduction: 33.6%;
- retry-fraction gate: PASS.

### GUARD_M10

- P-C1: 16/16;
- all WET/POND: PASS;
- median deterministic work reduction: 33.6%;
- retry-fraction gate: PASS.

### GUARD_M5

- P-C1: 16/16;
- all WET/POND: PASS;
- median deterministic work reduction: 33.6%;
- retry-fraction gate: PASS.

Regime median work reduction for GUARD_M5:

- DRY: 36.8%;
- TRANSITION: 29.6%;
- MOIST: 34.4%;
- WET: 11.4%;
- POND: 13.2%.

No regime has >5% median regression.

## Selection

The preregistered selection rule chooses:

`GUARD_M5`

because all three candidates tie on the primary work metric and the less conservative threshold wins the tie-break.

## Frozen candidate for validation

AUTO_REFERENCE research candidate:

1. start with internal bootstrap dt = 0.005 d;
2. AUTO proposal uses normalized accepted-state pressure-head movement with R=0.40;
3. AUTO has no normal operating DTMAX;
4. AUTO remains eligible only while:
   - accepted dynamic-top mode is FLUX;
   - accepted top pressure head <= -5 cm;
5. leaving eligibility enters LEGACY_SAFE permanently;
6. FLUX -> HEAD/runoff candidate transition uses REFINE4 before fallback;
7. AUTO nonlinear failure enters LEGACY_SAFE;
8. LEGACY_SAFE uses current Reference timestep policy;
9. hard event clipping and retry ownership remain separate.

## Decision

GUARD_M5 advances to independent validation.

No production controller is enabled by TIMEARCH16.
