# F-WOF-EXT01 architecture decision, evidence and execution closeout (research)
Date: 2026-10-17

## Decision: CONDITIONAL GO for an external daily crop backend contract; NO production admission

Scope: establish whether SWAP5's **accepted daily crop transaction** can host a backend-independent WOFOST crop kernel, initially Python, later independent Fortran. This is **not** a decision to merge an external backend, not science approval of Python WOFOST 8.1.1, and not a finding of identical Python/Fortran crop trajectories for the NEW EXT01 barley case.

### Proven evidence

1. SWAP5 uses accepted daily crop-event certificates, persistent crop transaction state, checkpoint/candidate/commit, exactly-once consumption and restart continuation. Its in-process native WOFOST81 state is currently concrete Fortran, not a plug-in interface.
2. SWAP5 research PR #1279 external **synthetic** worker shows protocol-level prepare/discard/repeat/commit/restore and failure isolation; that does not test real PCSE state.
3. PCSE research PR #9 ran real PCSE one model day out of process and compared it with the same PCSE in-process execution.
4. The PCSE real crop-only probe runs a WOFOST81 crop with no native soil-water balance, test-only externally supplied TRA/TRAMX/RFTRA and EVS, N potential-production module retained. The 60-day wheat/barley smoke scenarios qualify architecture only.
5. Genuine SWAP5 physically accepted rooted-weather daily uptake/potential pair was observed from run 39027378775: both 1.0370706377336118e-3 in the test's integrated native units. Replaying those **numbers** into a separate PCSE 2010 case is a transport witness, not a matched-day scientific test; units, date and weather must still be reconciled.
6. Historic F-WOF-PP01/PP02 qualify twelve crop-owned states for ten PCSE 6.0.13 spring barley potential-production cases, not RD/TRA. Their immutable case001 archive only contains forcing.dat, reference.csv, precision.csv; original parameter/calendar/full PCSE state not contained therein.
7. A NEW experimental barley fixture uses a pinned upstream Spring_barley_301 parameter blob (0a850879538bd43fe7bf2973d6238ae672d49bdb), synthetic weather, test external ET, 60-day N-potential run. It is NOT PP01 case001. New daily reference export/repeatability is tracked in PCSE PR #9.

### The stable boundary recommended

- SWAP5 owns soil water, accepted root-uptake fluxes, event identity, rollback and commit coordination, hydrological mass balance and root-water uptake geometry.
- WOFOST owns its crop production, assimilation, allocation, phenology, carbon and crop-N processes and complete crop continuation state.
- Soil-N realized supply shall have an explicit owner, eventually ANIMO5 where supported; do not let a hidden PCSE soil-N balance compete with ANIMO5.
- Daily input packet: schema/backend version, identity, time interval/date/phase, immutable meteorology, units, accepted integrated actual uptake, potential transpiration, oxygen/water stress decomposition when required, available N, crop-calendar event and parameter identity.
- Daily output packet: prepared candidate handle/state and validated crop-view, demand and supply accounting, diagnostics, state digest and exact consumed input-event id. Validity and ratio zero-demand policy require agreed science.
- Candidate must have no irreversible effect on committed crop and no extraneous Python global mutable state that changes other crop instances. Atomic commit must pair full crop state with event receipt. Idempotence and duplicates must be rejected.

### Blocking gates before production readiness

**G1 matched science:** supply the exact same fully documented inputs to new Python and Fortran backends, including weather, crop parameters, internal initialization, management, N and water mode; compare complete 12-var crop-owned trajectory against predefined limits. Existing PP01/PP02 evidence cannot be simply transferred to new EXT01.
**G2 state:** full PCSE state snapshot and restore after accepted and pending events; leaf cohorts, internal rates, phenology, management/timer and N; reject/rollback with bitwise or explicitly justified exactness.
**G3 flux:** remove competing PCSE soil water; single accepted SWAP flux owner, correct native unit conversion, dated daily provenance. A previous test modifying TRA behind a live PCSE MLWB failed mass balance; never repeat this as an admissible design.
**G4 Fortran integration:** one real SWAP5 kernel-executor crop transaction calls external backend and commits or discards without altering physical solver behavior.
**G5 performance:** benchmark warm worker vs one process per day, e.g. 1/50/500 crop instances and 30/100 days; report CPU walltime/peak RSS, initialisation vs per-day cost, IPC bytes, throughput and worker failures. No fabricated or predeclared speedups.
**G6 release science:** owner decision about PCSE formulation PART-01, qualified final Python source and explicit signed review before formal migration.

### Minimal next engineering package

Retain research PRs #1279 (SWAP5) and #9 (PCSE) until the tests above close. Prioritize finishing/archiving the new barley Python output, then implement an equivalently forced standalone Fortran *test driver* without touching SWAP5 production. Do not merge exploratory test-only patches into canonical. Do not waste broad CI runs when a local/offline targeted test is enough.

**Decision date:** research recommendation only. **Production merge/admission: NO.**
