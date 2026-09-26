# F-PE-TEMPORAL02 P3B result — signed frontier replication

Date: 2026-09-26

Status: `SIGNED_FRONTIER_CONFIRMED`

## Protocol

Three fresh processes per signed point replicated each P3A frontier and its immediately stricter tested budget.

## Confirmed common completion frontier

| |dh| (cm) | Stricter tested budget | Stricter all-pass | Frontier budget | Frontier all-pass |
| ---: | ---: | :---: | ---: | :---: |
| 0.001 | 2e-4 | no | 5e-4 | yes |
| 0.01 | 2e-3 | no | 5e-3 | yes |
| 0.05 | 2e-2 | no | 5e-2 | yes |
| 0.10 | 2e-2 | no | 5e-2 | yes |

At |dh| = 0.25 cm, the tested ceiling 5e-2 cm completed only 6/12 signed points. No common frontier exists within the tested budget ceiling.

All replicated point signatures were deterministic.

## Important regime detail

Passing the common frontier does not always mean first-attempt acceptance.

Examples:

- O14-wet +/-0.001 cm at 5e-4 still use one temporal retry;
- O14-wet -0.01 cm at 5e-3 uses a temporal retry;
- O14-wet +0.01 cm at 5e-3 includes both temporal and solver rejection before completion;
- O14-wet +0.05 cm at 2e-2 can complete despite multiple retries, but the negative sign fails there, so 2e-2 is not a common frontier;
- O14-wet +/-0.10 cm at 5e-2 can still require one temporal retry.

Thus 'common completion budget' and 'direct first-attempt acceptance budget' are distinct quantities.

## Interpretation

The temporal budget required for robust exact participant completion increases sharply with corrector displacement.

The current 1e-5 cm fixture authority is orders of magnitude stricter than the common-completion budget once displacements reach 0.01 to 0.10 cm.

However, the results do not justify a single larger fixed production budget:

- the frontier is material/regime/sign dependent;
- the 0.25-cm envelope is not recovered within the tested ceiling;
- some frontier points still rely on retry/substepping;
- physical temporal accuracy remains unqualified.

## Decision

P3B closes the completion-surface mapping.

The next phase must address history representativeness and independent temporal error authority before any policy admission.

No production source change is authorized.