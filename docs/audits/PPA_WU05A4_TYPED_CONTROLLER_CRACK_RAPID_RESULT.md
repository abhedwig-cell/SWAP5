# PPA-WU05-A4 typed controller crack-history and rapid-drain qualification

Date: 2026-09-30

Status: `QUALIFIED_RESEARCH_RESULT / CRACK_AND_RAPID_THROUGH_TYPED_CONTROLLER`

Workflow run: `36769705960`

Head: `c3114c3d9cdc3122d61d15069367f7eb8d4b1c02`

## Purpose

Verify that two nontrivial A3 macropore process contracts survive migration into the typed A4 process/controller architecture:

- hysteretic dynamic crack history;
- externally owned rapid macropore drainage.

The test uses the real Reference Richards solver and the qualified typed outer coupling controller.

## Crack-history result

Two otherwise identical cases differ only in accepted `VlMpDyCp` history.

Fresh/no-crack history:

`VlMpDyCp(candidate) = 0.0 cm`.

Historical crack:

`VlMpDyCp(candidate) = 0.3092807260 cm`.

This reproduces the A3 E4 result through the full typed controller path.

The result confirms that:

- crack history remains physical continuation state;
- the controller does not erase or reconstruct it from current theta alone;
- candidate history remains separate from accepted history until external commit.

## Rapid-drain result

Research case:

- zero matrix/macropore absorption exchange;
- macropore volume = `0.5 cm`;
- macropore water = `0.5 cm`;
- domain bottom = `-100 cm`;
- drain level = `-95 cm`;
- resistance = `20 d`;
- step duration = `0.05 d`.

Observed external rapid-drain amount:

`0.0125 cm`.

Candidate macropore storage therefore becomes:

`0.4875 cm`.

The controller reports rapid drainage separately as:

`macropore_external_outflow_cm`.

The combined matrix + macropore + external-outflow balance passes.

## Ownership conclusion

The typed implementation preserves the A1/A3 ownership map:

- matrix/macropore absorption is internal exchange;
- dynamic crack volume is continuation history;
- rapid drainage is a single external water transfer;
- rapid drainage is not included in the internal exchange vector;
- combined mass reconciliation books the rapid outflow exactly once.

## Qualification

Markers:

- `PPA_WU05A4_CONTROLLER_CRACK_RAPID=PASS`;
- `PPA_WU05A4_RICHARDS_GATE=PASS`.

O0 and O2 produce identical output.

## Scope

This remains research-only.

Not yet established:

- production macropore activation;
- multi-domain rapid drainage;
- moving drain geometry;
- full exact B1.11 top-inflow redistribution;
- longer crack/open-close and rapid-drain trajectories.

## Next step

Run a short accepted-state trajectory through the same typed controller in which:

1. accepted crack history is carried from step to step;
2. matrix wetting can close or retain the crack according to the source-bound hysteresis rule;
3. rapid drainage removes external water on each accepted step;
4. strict and max-three controller policies remain transactionally consistent;
5. cumulative combined mass closes.
