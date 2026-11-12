# F-WOF-EXT01: actual PCSE detached daily transaction qualification (2026-10-17)

Research-only executed result, **not end-to-end SWAP5 accepted hydrology coupling**.

## Actual runs and code

PCSE research PR #9 candidate `d3d7475159fb99866cfa3b0b15c1b5357a90230a`; [GitHub Actions run 39063219911](https://github.com/abhedwig-cell/pcse/actions/runs/39063219911), job `117485341583`, finished **SUCCESS**, including four real-PCSE transaction unit tests. Previous [39062911948](https://github.com/abhedwig-cell/pcse/actions/runs/39062911948) and [39063153286](https://github.com/abhedwig-cell/pcse/actions/runs/39063153286) also succeeded.

The test-only detached worker restores a real PCSE-WOFOST81 crop state in a newly initialized Python process and calculates one day. Its external ET provider now consumes the explicit candidate event TRA/TRAMX/RFTRA (cm/day), rather than silently reusing hardcoded fixed stress. Events carry a dated crop-day identity and a hydrological-provenance string, but the provenance here is a **synthetic fixture label, not a verifiable accepted SWAP5 certificate**. Candidate reply binds event digest, prior committed crop-state digest and candidate crop-state digest.

Executed log markers:
- `EXT01_REAL_PCSE_TRANSACTION_3_DAYS_PASS`: prepare/retry consistency, unchanged committed prior, three sequential commits, duplicate refusal and full observable crop trajectory agreement with an uninterrupted PCSE run for fixed research ET.
- `EXT01_REAL_PCSE_BAD_EVENT_UNCHANGED_PASS`: invalid flux ratios, negative/overpotential inputs, wrong day and wrong calendar date rejected before commit.
- `EXT01_REAL_PCSE_CANDIDATE_TAMPER_REJECTED`: mutated candidate blocked and prior state retained.
- `EXT01_REAL_PCSE_DISTINCT_ACCEPTED_ET_CONSUMED_PASS`: valid RFTRA 0.5 versus 1.0 events produce different actual crop candidate digests, while both committed states remain unchanged during prepare.

## Scope and outstanding gates

**PASS:** genuine PCSE candidate transaction and distinct daily external water-stress input in a bounded experimental process boundary. Direct new-process crop continuation and native matched Python/Fortran barley evidence are independently supported by runs `39062036608` and `39059061721`.

**NOT QUALIFIED:** production SWAP5 accepted-event transport to this worker, physical flux unit/time transformation from authentic accepted hydrology, idempotent persistence across worker/crash and coordinator crash boundaries, power-loss atomic commit of event receipt plus complete state, real rejected hydro trial coupling, multicolumn concurrency, performance and multi-crop scientific matching. A locally supplied provenance string is not cryptographic or process-level proof of SWAP acceptance.

Decision: CONDITIONAL GO for architecture research, **NO production substitution**. Continue with one authenticated/versioned SWAP5 hydrological receipt packet for an exactly dated matched PCSE day, strict unit/phase validation and crash-recovery qualification before considering admission.
