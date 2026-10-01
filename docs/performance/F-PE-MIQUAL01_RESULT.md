# F-PE-MIQUAL01 result — broad post-admission moving-interface qualification

Date: 2026-10-01

Status:

`MIQUAL01_REFERENCE_DOMAIN_LIMITATION`

Qualification authority:

- corrected workflow run: `36819243347`;
- job: `110231006391`;
- workflow conclusion: SUCCESS.

Canonical authority rechecked before persistence:

`integration/f-ci-canonical@0b231d1669cf38d069f14c6d2f0f07cd3bb1c5b1`

Canonical is unchanged from the preregistered baseline.

## Aggregate result

The frozen 8-case broad hydraulic-archetype bank cannot qualify as a manager portability bank because 3/8 full-reference trajectories fail before the adaptive manager is evaluated.

Classification:

`MIQUAL01_REFERENCE_DOMAIN_LIMITATION`

This is a reference-domain limitation, not a moving-interface physical mismatch.

Per preregistration, failed reference cases are not dropped or replaced after exposure.

## Reference-valid cases

Five full-reference trajectories complete all 4,000 intervals under the frozen explicit MAXIT16 evidence profile:

- B01_N64_T49;
- B12_N32_T25;
- B12_N64_T49;
- O05_N32_T25;
- O05_N64_T49.

Their reported maximum physical ledgers remain approximately 7.4e-17 to 1.2e-15 cm, far below the hard 5e-8 cm gate.

## Reference-domain failures

Three frozen full-reference trajectories do not complete:

### B01_N32_T25

- last accepted interval: 3456;
- failure interval: 3457;
- status: retry advised after the MAXIT16 ceiling;
- final diagnostic route: `legacy-reference-retry`;
- ledger before failure remains approximately 1.19e-15 cm.

### O14_N32_T25

- last accepted interval: 2865;
- failure interval: 2866;
- status: retry advised after the MAXIT16 ceiling;
- diagnostic route: `legacy-reference-retry`;
- ledger before failure remains approximately 1.19e-15 cm.

### O14_N64_T49

- last accepted interval: 285;
- failure interval: 286;
- status: retry advised after the MAXIT16 ceiling;
- diagnostic route: `legacy-reference-retry`;
- ledger before failure remains approximately 1.19e-15 cm.

All three failures are therefore nonlinear reference-solvability limits under the frozen evidence profile. They are not mass failures.

## Interpretation

MIQUAL01 answers an important qualification-design question.

The current canonical moving-interface manager cannot be assessed on a broad 8-case bank merely by extending the Z43E fixed-dt/MAXIT16 harness. The limiting factor is the full Heritage reference route itself on three frozen trajectories.

This does not invalidate:

- Z43E candidate evidence;
- Z43F canonical admission;
- the explicit non-default manager seam;
- the approximately 23% deterministic-work reduction already qualified in Z43E;
- the approximately 7.8% trajectory timing gain already qualified in Z43E.

It does invalidate using this exact 8-case fixed-dt/MAXIT16 bank as the next broad portability authority.

## Consequence

Do not tune MAXIT upward or silently remove difficult cases inside MIQUAL01.

The next useful qualification step should use production-valid temporal/retry ownership rather than a fixed 4,000-step no-retry reference harness. In particular, broad qualification should allow the reference production timestep machinery to perform its normal accepted-state retry/subdivision policy while comparing the manager against the same accepted physical contract.

That successor should retain all four hydraulic archetypes, including O14.

## Qualified claim boundary

Qualified:

- current canonical was re-tested on the frozen expanded preflight bank;
- 5/8 fixed-dt MAXIT16 full-reference trajectories complete;
- 3/8 hit a nonlinear reference retry ceiling without mass failure;
- the failure is upstream of manager comparison;
- the exact expanded bank is unsuitable as broad manager portability authority.

Not qualified by MIQUAL01:

- manager behavior on the three reference-invalid trajectories;
- broad hydraulic-archetype portability;
- forcing-regime portability;
- whole-SWAP or MultiSWAP runtime speedup;
- production-default activation.

## Production boundary

No source/default change.

The moving-interface manager remains canonically admitted as explicit opt-in.

`LEGACY_NUMERICS` remains production default.
