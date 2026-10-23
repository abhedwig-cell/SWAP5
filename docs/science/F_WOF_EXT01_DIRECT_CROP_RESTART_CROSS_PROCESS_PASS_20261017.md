# F-WOF-EXT01 true new-process direct crop continuation, 2026-10-17

**Bounded research PASS, not production admission.**

## Executed controlled experiments

At PCSE PR #9 research commit `948c5d8d98a19ec92f28c533fc2491d62b5d4f10`, [GitHub run 39062036608](https://github.com/abhedwig-cell/pcse/actions/runs/39062036608), job `117481800431` completed SUCCESS.

The pinned Spring_barley_301 PCSE-WOFOST81 crop-only simulation was stopped after days **10, 30 and 45**. At each boundary, a JSON research state image was written in one Python child process; that process exited. Another **fresh Python process** initialized a new Engine at its ordinary emergence/start state, restored the saved continuation image and ran only the remaining 50, 30 or 15 days, respectively. No historical day replay occurred during restore. All **61 dated output records** for the twelve crop-owned variables were identical to a separate uninterrupted 60-day reference. Internal leaf cohort (LV, SLA, LVAGE) and bounded crop projection also matched at the last day. The same direct continuation tests passed in-process at splits 10/30/45. Log markers:
- `EXT01_DIRECT_SEPARATE_PROCESS_RESTART_PASS 10 61`
- `EXT01_DIRECT_SEPARATE_PROCESS_RESTART_PASS 30 61`
- `EXT01_DIRECT_SEPARATE_PROCESS_RESTART_PASS 45 61`
- `EXT01_DIRECT_RESTART_SPLIT_EQUAL 10 61`, corresponding 30 and 45.
- Incompatible schema and foreign published kiosk variable are rejected (`EXT01_DIRECT_RESTART_FOREIGN_STATE_REJECTED`).

## Actual scientific state dependencies discovered

The research codec version `F-WOF-EXT01/DIRECT-RESTART-EXPERIMENT/2` serializes current traits/rates for crop and nested components, including nitrogen demand/uptake component, original published VariableKiosk values with registration whitelist, timer date/counter, already published output for trajectory checking, bounded crop leaf projection, and hidden assimilation seven-day minimum-temperature deque. Restoring traits alone failed at first; preserving partition namedtuple fixed a type mismatch; published kiosk restoration resolved an N uptake mismatch. A later early-day-10 divergence revealed omitted nested nitrogen demand/uptake state (added to the codec). Hidden seven-day TMIN rolling history is explicitly handled. The final run passes all three split points.

## Explicit boundary

This is a real, direct, separate-process **research-engine** checkpoint continuation for one fixed barley crop, pinned parameterization, fixed forcing, synthetic external ET and no PCSE-owned soil-water balance. It does **not** prove all crop transitions, varying forcing/event histories, dynamic management, rotations, independent SWAP5 accepted flux publication, exact rollback of a prepared external real crop candidate, future ANIMO5 N exchange, portable/version-migration compatibility or production-scalable restart. The JSON format remains an experimental internal-PCSE implementation-dependent image, not an admitted stable schema. No changes have been made to SWAP5 canonical or its accepted WOFOST81 physics.

**Decision:** bounded direct crop continuation gate PASS; CONDITIONAL GO for developing an experimental external daily interface. Production substitution remains NO-GO until exact accepted SWAP5 event/mass coupling, transaction idempotence and rollback, multi-case science, source/codec evolution and performance gates.
