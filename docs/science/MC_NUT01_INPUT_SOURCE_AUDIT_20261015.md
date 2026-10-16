# Soil-management input: source facts and next implementation boundary

Status: completed source audit; proposed adapter boundary, **not implemented or
admitted file parsing**. Baseline and raw proof are in the
[calendar reconciliation](MC_NUT01_CALENDAR_RECONCILIATION_20261015.md).

## Pinned authority

The repository's `integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64`
is the executable historical authority. Its `SWAP/management_soil.f90` has SHA256
`0edba713f71840fca320d17162fd3d3e59ff2acf702df3393188fe4a2fd6c43b`.
The audit capsule also pins declarations and amendments bytewise.

The official [2016 report, DOI10.18174/400458](https://doi.org/10.18174/400458)
describes separate event and material files in boxes8.1.4.1/8.1.4.2. Retrieved
search excerpts locate those examples; both old official PDF URLs returned404,
and direct edepot retrieval returned403. No complete report bytes were recovered
or used as an executable oracle. Those examples must not override the later
4.3.1 source's actual field names or file layout.

The official [TTUTIL4.13 manual](https://swap.wur.nl/TTutil/427/TTutil4_13.pdf)
was retrieved:301543bytes, SHA256
`ad56367fb478c2fad9af4cf59f59a4e4ad4e523bdc2ceb2e8a7f53335f47b954`.
Sections5.2.5/5.3/5.4 describe day counts relative to1900-01-01, multiple date
spellings, tabular arrays and comments. This is syntax documentation, not proof
of exact 4.27 executable behavior. The repository's TTUTIL manifest lists source
digests but supplies no source bytes. The current official download requires
registration/license acceptance; no registration or acceptance was performed.

## Actual source versus implementation choices

| Topic | Pinned 4.3.1 source fact | Proposed bounded adapter requirement |
| --- | --- | --- |
| File | `management_soil`112/119 reads material definitions from `.snm`;129..132 reads events before closing the same unit.169.. reopens `.snm` for soil parameters. | Explicit source file/section contract; do not call a split-file example the 4.3.1 format or claim a generic full-project parser. |
| Definitions |120..126 reads `MatNum, MatName, AppAge, OrgMatFrac, OrgNFrac, NH4NFrac, NO3NFrac`; declarations9 bounds material rows at20. | Validate complete column lengths and preserve order; no implicit default material. |
| Association |130 writes `iMat` into the same `MatNum` array; amendments22 uses its value directly as an array position. | Require valid table positions. Do not reinterpret arbitrary declared IDs as lookup keys. Initially restrict definition IDs to their1-based row positions, explicitly rejecting ambiguous layouts. |
| Events |129..132 reads `smedate, iMat, Dosagekgha, VolatFraction`. | Preserve record order and validate referenced rows before constructing any plan. |
| Units |147..148 converts kg/ha by1e-4. | Keep dose in kg/ha until the admitted calendar performs its single conversion. |
| Time |136..143 rejects decreasing dates; existing B1-R2 authority handles equal dates and day-end triggering. | Produce integral daily dates on an explicit origin; retain same-date order. Reject unsupported intraday dates. |
| Age |122 reads0..5000; the admitted calendar bounds0..100 and later chemistry may reject additional combinations. | Intersect with the admitted domain; no automatic expansion to the wider legacy read range. |
| Volatilization |132 admits0..500000 at input; chemistry and current calendar admit a physical fraction0..1. | Reject values above1; do not propagate the historical input bound into physics. This is a narrower supported domain, not a newly qualified legacy correction. |
| Capacity | Declarations bound materials20/events1000; the admitted typed calendar separately bounds4096 records/64 per day. | Declare the file-reader intersection separately; larger typed capacity does not establish larger historical-file compatibility. |

Fresh O0/O2 executions call the unmodified original amendment routine after a
minimal post-input fixture overwrites declared identifiers with event index2.
Different mineral fractions in rows1/2 show that row2 is applied, including its
instantaneous volatilization. Static exact-byte checks separately bind the
original input-call order and shared destination array. Neither proof claims
that the absent TTUTIL source was executed.

## Required next proof

Before implementation, pin a bounded supported syntax and its failure behavior;
whole-file compatibility needs actual fixtures/source-reader comparison. Start
with complete material/event tables and daily dates, explicit origin and no
default activation. Unsupported syntax, incomplete/duplicate tables, invalid
dates, unknown positions, nonfinite/bounded-domain violations and malformed late
records must publish no valid plan. No partial table, hidden cursor or accepted
physical mutation may escape a failed read.

The adapter must return the existing immutable typed calendar and report errors
outside process/state ownership. The caller supplies the plan again on restart.
It must not add N inventories, persist forcing as committed model state, change
senescence ordering, bypass chemistry validation or introduce a second clock.
First qualify the small production input boundary at O0/O2; then compare parsed
and explicit plans through the actual current day and Richards routes, including
empty days, ordered same-date records, retry/replay, complete rollback and fresh
restart. Select owning integrated preservation from the actual dependency delta.
No parser, activation, heat, harvest, surface/pond or aquifer claim follows from
this completed audit.
