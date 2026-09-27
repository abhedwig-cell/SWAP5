# F-PE-TEMPORAL02 P3A result — displacement × temporal-budget completion surface

Date: 2026-09-26

Status: `SIGNED_FRONTIER_MAPPED`

## Protocol

Six difficult PROFILE06 origins were screened over signed displacements +/-0.001, +/-0.01, +/-0.05, +/-0.10 and +/-0.25 cm.

Temporal budgets were 5e-4, 1e-3, 2e-3, 5e-3, 1e-2, 2e-2 and 5e-2 cm.

One fresh process was used per matrix point. The exact Reference solver, retry scale, retry cap and P0 numerical controls were retained.

## Corrected signed common frontier

The first P3A summary script incorrectly merged positive and negative offsets before thresholding. The raw point records were correct; only the derived common-threshold line was affected.

Recomputing from the signed raw records gives:

| |dh| (cm) | Smallest tested common completing budget (cm) |
| ---: | ---: |
| 0.001 | 5e-4 |
| 0.01 | 5e-3 |
| 0.05 | 5e-2 |
| 0.10 | 5e-2 |
| 0.25 | none through 5e-2 |

Thus the original 0.05-cm summary value of 2e-2 was an analysis bug. O14-wet at -0.05 cm requires 5e-2 in the tested grid, making 5e-2 the correct common threshold.

## Structure

The required budget rises steeply with corrector displacement and is materially case-dependent.

Examples:

- at +/-0.01 cm, difficult wet cases generally require 5e-3 cm while B01-mid and B12-wet can complete at lower budgets;
- at +/-0.05 cm, O14-wet negative controls the common threshold at 5e-2 cm;
- at +/-0.10 cm, 5e-2 cm is again the first common completing budget;
- at +/-0.25 cm, several difficult points still fail at the tested 5e-2 cm ceiling.

## Interpretation

A fixed 1e-3 cm temporal head budget is only a small-displacement policy candidate. It does not define a useful envelope out to the original APPROX04 +/-0.25 cm response window.

The completion frontier is strongly displacement- and state-dependent. Any practical coupling policy therefore needs either:

- a bounded small-corrector envelope;
- a scale-aware temporal budget;
- or a different exact temporal acceptance strategy.

P3A does not choose among those options.

## Decision

Advance to P3B signed frontier replication.

P3B must confirm the threshold and immediately stricter tested budget at |dh| = 0.001, 0.01, 0.05 and 0.10 cm, and confirm that no common frontier exists at |dh| = 0.25 cm within the 5e-2 cm tested ceiling.

No production source change is authorized.