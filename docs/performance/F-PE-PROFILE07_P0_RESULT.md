# F-PE-PROFILE07 P0 result — exact live outer-cost map

Date: 2026-09-27

Status: `PASS_DEEPER_SWAP_ATTRIBUTION_JUSTIFIED`

PR:
`#657 — F-PE-PROFILE07: exact live-corrector cost decomposition`

Workflow run:
`36302289868 — F-PE-PROFILE07 exact live cost decomposition`

## Scope

P0 profiles the exact E0 live coupling path over the same 12 difficult groups used by SOLVE01 P2B.

The measured coupled-loop buckets are:

- MODFLOW prepared-solve iteration;
- full exact SWAP participant trial;
- response extraction;
- discard of rejected exact candidates;
- remaining Python/orchestration loop work.

Publication/finalization is measured separately and is not included in the coupled-loop denominator.

No production source is modified.

## Aggregate live-loop cost map

Across the 12 group medians:

- MODFLOW: `58.3807490%`;
- exact SWAP trial: `20.8443761%`;
- response extraction: `2.0492780%`;
- discard: `0.4885784%`;
- remaining loop/orchestration: `17.7241594%`.

Aggregate coupled-loop time represented by the 12 medians:

`10,148,013 ns`.

Absolute aggregate bucket times:

- MODFLOW: `5,924,486 ns`;
- exact SWAP trial: `2,115,290 ns`;
- response extraction: `207,961 ns`;
- discard: `49,581 ns`;
- residual loop/orchestration: `1,798,650 ns`.

## Group behavior

The exact SWAP-trial share is consistently material:

- minimum observed group share: approximately `19.7%`;
- maximum observed group share: approximately `23.5%`;
- aggregate share: approximately `20.8%`.

Representative groups:

- B01 mid: about 20.0%;
- B01 wet: about 20.7-21.1%;
- B12 wet: about 19.7-19.8%;
- O05 wet: about 20.9-22.3%;
- O14 mid: about 20.3%;
- O14 wet: about 20.5-23.5%.

Thus exact SWAP work is not the largest system-level bucket, but it is large enough to satisfy the PROFILE07 threshold for deeper exact-preserving attribution.

## Solver-work correlation

The live exact groups retain the same demand structure found in SOLVE01.

Two-iteration groups typically execute:

- 4 accepted substeps across the two trials;
- 6 attempts;
- 2 retries;
- 2 temporal rejections;
- no solver rejection.

Four-iteration wet B01/O05 groups execute:

- 8 accepted substeps;
- 12 attempts;
- 4 retries;
- 4 temporal rejections;
- no solver rejection.

Nonlinear work varies materially by material:

- B12 wet: 12 nonlinear iterations for two live trials;
- B01 mid: 14;
- O14 mid: 18;
- O14 wet: 22;
- B01 wet: 36 for four live trials;
- O05 wet: 44 for four live trials.

Backtracking attempts equal the reported nonlinear iteration counts in this fixture.

## Interpretation

At system level, MODFLOW is the largest measured live-loop cost.

PROFILE07 does not optimize MODFLOW and does not change MODFLOW solver settings.

Within the SWAP performance scope, the full exact participant trial remains the only outer bucket large enough to justify deeper decomposition.

Response extraction and discard are too small to justify separate optimization lines.

The next PROFILE07 phase therefore decomposes the exact SWAP trial itself into:

1. forcing materialization;
2. serialized backend/transaction/Richards work;
3. remaining participant validation and response construction.

This remains observation-only.
