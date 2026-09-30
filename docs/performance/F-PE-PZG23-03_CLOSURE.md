# F-PE-PZG23-03 — post-qualification closure

Date: 2026-09-30

Status: CLOSED_LOCAL_NONLINEAR_SOLVER_REJECTION_BLOCKER

Canonical baseline:
`integration/f-ci-canonical@f133e47f8f7899f3d70db79f9ea63fbb730b2da0`

Qualified research authority:
- branch: `research/f-pe-pzg23-03-rejection-channel-attribution`;
- qualified postimage: `72dcbadcf4234af04a04a1da79cdc92474b9016c`;
- result commit: `bee3be6a7d90ce5f0c94634ea052f40b52393673`;
- workflow run: `36762761678`;
- job: `110049227230`;
- conclusion: SUCCESS.

## Closed attribution

The two localized pZg23 second-interval failures are dominated by the explicit
kernel solver-rejection channel.

Across origins 10 and 11:

- solver rejections = 34;
- temporal rejections = 3;
- mass rejections = 0;
- admission rejections = 0;
- checkpoint rejections = 0.

Origin 11 has zero temporal rejections and still fails.

Hard mass is not the failure mechanism.

## Causal narrowing across PZG23-01..03

The blocker is:

- localized to h0=+2 cm with positive forcing +0.035/+0.05 cm/day;
- after a valid committed interval A;
- not worker/OpenMP related;
- not caused by accepted temporal-history content;
- not caused by hidden solver scratch outside the committed carrier;
- not caused by hard mass;
- dominated by local nonlinear solver rejection/backtracking.

Classification:

`QUALIFIED_PZG23_LOCAL_NONLINEAR_SOLVER_REJECTION_BLOCKER`.

## Governance consequence

No production change follows.

Do not modify:

- the admitted 0.20 cm application budget;
- hard mass;
- temporal-history ownership;
- worker-count policy;
- GENERATED ELAS;
- solver tolerances or retry limits.

## Closure

F-PE-PZG23-03 and the pZg23 scheduler-blocker attribution line are closed.

Any actual solver repair is a separate workstream and should only be opened if
the production value justifies solving this localized numerical edge case.
