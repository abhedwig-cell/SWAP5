# SWAP-002 qualification evidence

Current B1 admission status: **QUALIFIED CANDIDATE FOR B1.10**

## Exact provenance

```text
canonical B0 / ordered B1.9 tillage.f90 SHA-256
731a873e0aa5ac25626a6d392c1668e66e57ee3fdc1d94b3eab127b8e343a486
stored fix.patch SHA-256
e6f501f510f0de3599cfb2ef208744862e7ef9173c9cf1bf434f2e3ea450613b
corrected tillage.f90 SHA-256
eaf1976238f7c659c1acb02f54685a7aafdf03d50d0978bbcc788b6ada441ca3
```

No admitted B1.1-B1.9 patch touches `tillage.f90`; the ordered B1.9 preimage therefore equals canonical B0. The stored patch is SWAP-002-only and contains none of the historical SWAP-003 or SWAP-004 tillage changes.

## Historical audit qualification

The central issue register classifies SWAP-002 `FIX_TESTED`, very-high certainty and high severity. The audit testbank reports six start-position cases passing after the correction: before the first event, exactly the first event, between events, exactly the second event, after the final event, and rejection of non-chronological event dates.

The audit explicitly states the intended semantics: `iTill` is the next event still to execute; if the run starts between historical events, load the most recent preceding event's tillage/consolidation parameters.

## Fresh compiled source-bound gate

A fresh GNU Fortran 14.2 harness was compiled with strict checks from the exact candidate logic bound to the stored patch. It exercises the same six cases and additionally verifies which previous event is loaded.

```text
B0
PASS before_first
PASS exact_first
FAIL between_1_2
FAIL exact_second
FAIL after_last
PASS unsorted
RESULT 3/6

SWAP-002 candidate
PASS before_first
PASS exact_first
PASS between_1_2
PASS exact_second
PASS after_last
PASS unsorted
RESULT 6/6
```

Expected candidate state:

| Start position | `iTill` | loaded previous event |
| --- | ---: | ---: |
| before first | 1 | none |
| exactly first | 1 | none |
| between 1 and 2 | 2 | 1 |
| exactly event 2 | 2 | 1 |
| after final | `Ntill+1` | final |
| unsorted dates | rejected | n/a |

## Behavioural envelope

B1.10 may differ from B1.9 only when the simulation start lies on/after later tillage events. The correction changes initialization of the next-event pointer and the historical tillage parameter set loaded at start. No new tillage physics is introduced.

A full packaged SWAP 4.3.1 tillage scenario is not supplied with B0. Therefore this admission is qualified specifically for `set_iTill` start-state semantics; it does not claim exhaustive qualification of the entire tillage module or interactions with frost/solute/macropore options.

## Mass boundary

The patch itself runs during tillage initialization and does not alter any water-balance tolerance. Because the corrected historical parameter initialization can legitimately alter later tillage trajectories in cases that previously started from the wrong event state, such downstream differences must remain attributable to SWAP-002 and must still satisfy the unchanged hard mass criteria in later B2/full-model qualification.

## Prospective B1.10 identity

Independent local reconstruction first reproduced the published B1.9 manifest exactly, then applied only SWAP-002:

```text
members          63
source bytes      1,863,575
manifest SHA-256  2dfc004f1bae3fc249f384d4f947a07ed4627e83e251ce6557d03092f0b4d1b1
```
