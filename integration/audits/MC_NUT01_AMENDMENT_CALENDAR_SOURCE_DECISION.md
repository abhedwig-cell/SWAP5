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
