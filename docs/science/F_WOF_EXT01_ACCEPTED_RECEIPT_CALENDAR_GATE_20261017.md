# F-WOF-EXT01 accepted SWAP hydrology provenance and calendar qualification (2026-10-17)

## Executed actual PCSE research gate

At PCSE research PR #9 commit `0a42436c589f72135f8d92b1c043e1e087844df3`, [Actions run 39063943625](https://github.com/abhedwig-cell/pcse/actions/runs/39063943625) completed SUCCESS (five actual detached PCSE transaction tests). Markers: `EXT01_AUTHENTIC_SWAP_RECEIPT_CALENDAR_MISMATCH_REJECTED`, `EXT01_REAL_PCSE_DISTINCT_ACCEPTED_ET_CONSUMED_PASS`, `EXT01_REAL_PCSE_BAD_EVENT_UNCHANGED_PASS`, `EXT01_REAL_PCSE_CANDIDATE_TAMPER_REJECTED`, `EXT01_REAL_PCSE_TRANSACTION_3_DAYS_PASS`.

The historically observed accepted SWAP5 rooted-weather receipt `SWAP5-rooted-weather-j1-d2-accepted` (accepted actual and potential uptake both `1.0370706377336118e-3` in the bounded native fixture) is dated against a 1999 reference epoch (1999-01-23 for relative day 2). PCSE's independently pinned EXT01 barley begins 2010-04-16. `AcceptedCropDay.require_calendar_alignment` correctly accepts the genuine SWAP fixture's date and rejects its substitution into the unrelated 2010 PCSE day. No synthetic date substitution or silent remapping is permissible.

The external detached PCSE worker accepts a versioned research envelope specifying a crop-day date, actual/potential transpiration and RFTRA, and refuses inconsistency between date, sequential day count and pre-commit crop state. Valid distinct synthetic ET values feed the *real* crop rates and produce distinct prepared crop-state digests. Candidate/prior/event digests, duplicate detection and rejection of malformed water input have now been executed. The accepted-hydrology provenance string in that worker remains declarative, not tied to an immutable SWAP runtime certificate or to SWAP state revision.

## Concrete end-to-end blocker

A real matching input must originate from the same SWAP5 calendar/column/weather/soil run as the PCSE crop day, with a post-acceptance event receipt containing calendar day, t0/t1, column id, accepted soil state revision, integrated root uptake, potential transpiration, units, hydrological mass-balance witness and event identity. It must be possible to distinguish an accepted day from a rejected hydrological trial; the crop candidate may commit *only after* real hydrology acceptance. The existing 1999 receipt is a valuable negative calendar test, not a positive matched-day science test. A study that merely replays its numbers into the 2010 barley weather is transport-only and cannot establish coupled equivalence.

## Decision

**PASS** authentic old-fixture date rejection, real detached PCSE event input and transaction gates. **NOT QUALIFIED** actual same-day SWAP5->PCSE accepted physical event composition, power-loss atomic crop commit, multiple physical scenarios, multi-column execution and performance. Keep F-WOF-EXT01 research-only; no canonical merge or production replacement. The next unit should implement a matched dated accepted SWAP event exporter and worker import/identity verification in one targeted end-to-end test, without altering accepted hydrological physics.
