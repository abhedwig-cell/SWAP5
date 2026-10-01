# PPA-WU05-A9 qualification result — source-faithful direct surface top input

Date: 2026-10-01

Status: QUALIFIED_BOUNDED_ADMISSION_CANDIDATE

Qualified head: 1eb6985b93f038ca42228d0ee152a182ee4177ba

Qualification run: 36827968276

## Bounded capability

A9 extends the canonically admitted A8 macropore FMR route with source-faithful direct surface input from precipitation, irrigation and snowmelt.

The admitted-candidate ownership split is:

- direct P/I/M over macropore top area -> macropore top-input request;
- direct P/I/M over remaining area -> matrix top boundary;
- runon remains matrix/surface owned;
- FMR transaction mass ledger owns the complete external P/I/M + runon source;
- lateral overland-to-macropore input is represented in the typed process contract but remains fail-closed/not admitted in the first FMR route.

## Source authority

Exact B1.11 source map inherited from A5:

- FlwInTopPot = QMpLatSs + ArMpSs*(P+I+M)*dt;
- FlwInTopVrtDmPot = ArMpTpDm*(P+I+M)*dt;
- FlwInTopLatDmPot = ArMpTpDm/ArMpTp*QMpLatSs.

Upstream provenance reconciliation located QMpLatSs in the surface/ponding owner. A9 therefore does not invent or recompute runoff inside the macropore process.

## Production carriers

Immutable macropore physical configuration now optionally carries:

- surface_top_input_enabled;
- total top macropore area fraction;
- per-domain top macropore area fractions.

Step forcing now optionally carries:

- precipitation;
- irrigation;
- snowmelt;
- runon;
- lateral overland-to-macropore receipt.

No new persistent continuation state is introduced.

## Double-counting prevention

When surface top input is active, FMR requires the matrix top flux to equal:

-( (1-ArMpSs)*(P+I+M) + runon ).

A mismatch fails closed before candidate publication.

The external transaction mass ledger uses the full source:

-(P+I+M+runon),

not the reduced matrix-only top flux.

## Returned surface handling

The generic typed surface partition retains accepted and returned-surface receipts.

The first FMR production candidate does not yet own a source-faithful ponding/runoff sink for returned macropore top water. Therefore:

- lateral QMpLatSs must be zero;
- any non-negligible returned-surface amount causes retry;
- persistent capacity exhaustion terminates as transaction failure;
- rejected attempts publish no candidate and do not mutate committed state.

## Positive FMR evidence

Test forcing:

- precipitation = 0.01 cm/d;
- top macropore area = 0.20;
- dt = 0.001 d;
- matrix top flux = -0.008 cm/d.

Observed:

- macro storage gain = 0.000002 cm exactly within 1e-12;
- transaction mass residual = -2.3860579310974739e-16 cm;
- no retries;
- candidate ready and commit succeeds.

## Capacity/retry evidence

With fully saturated macropore storage and positive direct surface supply:

- canonical status = TRANSACTION_FAILED;
- attempts = 3;
- retries = 2;
- trial rollbacks = 3;
- candidate ready = false;
- committed revision/storage unchanged.

## Forcing mismatch evidence

When the matrix top flux is intentionally inconsistent with the 80/20 source partition:

- canonical execution does not complete;
- no candidate is published;
- committed state remains unchanged.

## Regression/restart evidence

The exact same A9 postimage also passes inherited A8 evidence:

- PPA_WU05A8_FMR_SERIALIZED_RUNTIME=PASS;
- PPA_WU05A8_FMR_REJECT_REPLAY=PASS;
- PPA_WU05A8_FMR_RESTART=PASS;
- PPA_WU05A8_FMR_MACRO_TRIAL=PASS;
- PPA_WU05A7_REAL_RICHARDS_RUNTIME=PASS.

Because A9 adds only immutable geometry and step forcing, and no new persistent state, A8 seven-field restart authority remains unchanged and executable on the A9 postimage.

## A9 markers

- PPA_WU05A9_SURFACE_TOP_INPUT=PASS;
- PPA_WU05A9_FMR_SURFACE_TOP_INPUT=PASS;
- PPA_WU05A9_FMR_SURFACE_CAPACITY_RETRY=PASS;
- PPA_WU05A9_FMR_SURFACE_FORCING_MISMATCH=PASS;
- PPA_WU05A9_SURFACE_REGRESSION_GATE=PASS.

## Decision

QUALIFIED_BOUNDED_FMR_DIRECT_SURFACE_TOP_INPUT_ADMISSION_CANDIDATE.

## Explicit non-claims

Not admitted by this result:

- lateral overland/runoff QMpLatSs in FMR;
- returned-surface reintegration into ponding/runoff;
- Black/Boesten dynamic evaporation composition with macropore surface partition;
- fixed-weir surface-water composition;
- perched-zone physics;
- rapid drainage;
- within-corrector dynamic crack geometry feedback;
- RossFast;
- parallel/concurrent MultiSWAP.