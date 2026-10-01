# PPA-WU05-A8 selective canonical admission candidate

Date: 2026-10-01

Status: QUALIFIED_CANONICAL_ADMISSION_CANDIDATE

Canonical base: `integration/f-ci-canonical@0b231d1669cf38d069f14c6d2f0f07cd3bb1c5b1`
Qualified code postimage: `23f264c0dc1267b96c039a360a356d73ba96eed6`
Selective admission workflow: `PPA-WU05-A8 canonical admission` run `36821398193`

## Admitted candidate scope

The candidate is deliberately bounded to:

- Reference Richards;
- serialized single-column FMR;
- standard macropore storage semantics;
- seven-field macropore continuation state;
- outer matrix/macropore coupling while the inner HeadCalc macropore flag remains inactive;
- external full/half transaction acceptance;
- candidate-only publication, rollback/discard and restart.

Unsupported configurations remain fail-closed:

- perched-zone macropore exchange;
- surface-connected macropore top-input forcing;
- rapid drainage in the FMR admission route;
- within-trial dynamic crack-geometry feedback;
- parallel/concurrent MultiSWAP macropore execution.

## Qualification evidence

Selective admission run `36821398193` passed on O0 and O2.

Transactional FMR receipt:

- status 0, completed;
- external full/half temporal acceptance source;
- zero temporal, mass and solver rejections;
- mass residual `-3.1084076285159412e-16 cm`.

Bounded active FMR trial:

- zero admission rejections;
- one transaction call and one attempt;
- zero retries;
- 3 HeadCalc calls;
- 13 nonlinear iterations;
- candidate ready;
- mass residual `-2.1337098754514727e-16 cm`;
- macropore storage changed from `0.2000000000` to `0.1999916196 cm`.

The same executable proves:

- committed authority is unchanged by an uncommitted trial;
- discard leaves committed state unchanged;
- repeated trial from the same checkpoint reproduces the candidate;
- commit advances the committed revision;
- persistence export/restore preserves macropore continuation state;
- uninterrupted and restarted continuation produce the same next candidate.

Markers:

- `PPA_WU05A8_FMR_SERIALIZED_RUNTIME=PASS`
- `PPA_WU05A8_FMR_REJECT_REPLAY=PASS`
- `PPA_WU05A8_FMR_RESTART=PASS`
- `PPA_WU05A8_FMR_MACRO_TRIAL=PASS`
- `PPA_WU05A8_REAL_RICHARDS_GATE=PASS`

## Canonical reconciliation

The preceding canonical delta introduced the non-default moving-interface manager and related timestep/profile evidence only. It did not change the macropore/FMR/transaction/restart/Reference-Richards dependency surface used by this candidate.

## Admission decision

`QUALIFIED_CANONICAL_ADMISSION_CANDIDATE_READY_FOR_MERGE_REVIEW`.

Admission of this PR must not be paraphrased as full SWAP 4.3.1 macropore feature coverage. The unsupported routes listed above remain outside the admitted boundary.