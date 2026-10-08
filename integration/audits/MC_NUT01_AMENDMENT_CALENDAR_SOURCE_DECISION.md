# MC-NUT01 amendment calendar source correction

Status: **ACCEPTED_REFERENCE_CORRECTION**

Date: 2026-10-07

Capability: `SW431-NUT-AMEND`

## Exact source issue

B1.11 `management_soil.f90` explicitly sorts soil-management events by
`smedate` before grouping equal dates. During the swap it exchanges the date,
dosage and volatilisation fields, but the material-number block contains:

`idum = MatNum(j)`
`MatNum(i) = MatNum(i)`
`MatNum(j) = idum`

The middle assignment is a no-op. For unsorted input this can detach the
material identity from the dosage/date record.

## Intended semantics

The surrounding code is unambiguous about intent:

1. sort dosages/events by application time;
2. keep all fields of one event together;
3. convert dosage kg/ha to kg/m2;
4. group adjacent sorted events whose dates differ by less than `1e-3`;
5. apply the whole group when `abs(TimeAmend(isme)+1-t1900)<1e-3`;
6. advance `isme` once.

## Decision

SWAP5 treats the `MatNum(i)=MatNum(i)` statement as a source defect and sorts
**complete typed amendment records atomically**: source time, material
definition, dosage and volatilisation remain one record.

Grouping and application timing retain the B1.11 source semantics. Each group
receives a monotone event id and is committed exactly once through the
transactional Soil-N management-event owner.

## Qualification requirement

The exact-source gate retains the defective assignment as a witness while the
typed calendar tests prove that:

- unsorted records retain their material/dosage association after sorting;
- events within `1e-3` are grouped;
- groups receive monotone event ids;
- a group is not applied before `TimeAmend+1`;
- restart rejects replay and preserves the next-event cursor.

This correction changes no amendment chemistry; the exact B1.11 material split
and volatilisation equations remain separately source-gated.

## 2026-10-08 source provenance review pending

The earlier text above is **not sufficient evidence of B1.11 equivalence**.
The NUT/SOL authority archive is a subset, not a full historical source tree.
The qualification failure in run `37726458263` proves only that
`SWAP/cropgrowth.f90` is not an archive member, not that GitHub lacks the file.
The SWAP-model/SWAP GitHub tree has `src/crop/cropgrowth.f90` and
`src/crop/management_soil.f90`, but its `main` ref is corroboration only.

An additional source audit indicates that the archived management implementation
may reject unsorted dates and use the strict expression
`smedate(isme)-smedate(isme-1) < 0.d-3`, which would invalidate the
claimed B1.11 sorting/grouping oracle above. **Until this discrepancy is
replayed against SHA-pinned exact-source bytes, treat the calendar-equivalence
claim and the purported MatNum defect as disputed, not admitted authority.**
Do not loosen the source gate to accommodate the original claim. Typed
exactly-once event state remains an implementation candidate; its equivalence
and any deliberate reference correction require an explicit decision.

## 2026-10-08 verified GitHub corroboration, explicit discrepancy

Read the live `SWAP-model/SWAP` `main` source through the GitHub connector:

- `src/crop/management_soil.f90`, Git blob
  `e890863a953be3d6c34a602fd08b052d86196c95`, lines 153-159:
  sort is present and `MatNum(i) = MatNum(i)` really is a no-op;
- same file, line 183:
  `if(smedate(isme)-smedate(isme-1).lt.0.d-3)then`;
- line 360 uses `abs(TimeAmend(isme)+1-t1900)<1.d-3` for **application timing**, not grouping;
- `src/crop/cropgrowth.f90`, Git blob
  `41e407a952c9654c1babf0840da17aaecbb7e3c5`, lines 1923-1936
  confirms separate soil demand and biological fixation expressions.

The live SWAP5 candidate in
`src/runtime/mod_fmr_b111_soil_n_amendment_calendar.f90`
(Git blob `8dfba45096cb3fb360c3367d5ab9d9973d9ec526`)
**groups events within `1e-3`**, unlike the corroborating source's
strict `<0.d-3`. For chronologically sorted finite dates the latter
cannot group even equal dates; the conditions are not semantically equivalent.
The `1e-3` margin at application time must not be misread as the grouping
criterion. The preceding document sections asserting B1.11 `1e-3`
grouping are therefore **withdrawn as an equivalence claim**.

This proves an inconsistency against an identified public SWAP blob,
**not yet byte-exact B1.11**. No code-level grouping change or accepted
reference correction has been authorized by this corroboration alone.
Qualification of SW431-NUT-AMEND remains blocked on a separately SHA-pinned
B1.11 management source and an explicit choice between literal source
semantics and corrected grouped-event behaviour. The typed exactly-once
management-event candidate remains present and unadmitted.

## 2026-10-08 independent tagged-source corroboration

The upstream repository also exposes a fixed release ref `v4.2.0`, not only
mutable `main`. Reading that tag directly gives exact Git blobs:

- `SWAP-model/SWAP@v4.2.0:src/management_soil.f90`, blob
  `926245c9fa05423be10933669cd65c1ceb9997c9`:
  line 130 contains `MatNum(i)=MatNum(i)`, line 155 has the strict
  `smedate(isme)-smedate(isme-1)<0.d-3` grouping predicate, and line
  332 has a distinct `1.d-3` application-time tolerance.
- `SWAP-model/SWAP@v4.2.0:src/cropgrowth.f90`, blob
  `6c2248cedbef805ab8c0c198ad630a7b990f32ff`:
  lines 1746-1747 contain distinct soil-demand and fixation expressions.

The same management defect/predicate is present on both public `main` and
`v4.2.0`. This strengthens corroboration but is **not** proof that the
separately supplied B1.11 bundle has these identical bytes. No rewrite of
SWAP5 calendar or change in admission state follows from this comparison.
