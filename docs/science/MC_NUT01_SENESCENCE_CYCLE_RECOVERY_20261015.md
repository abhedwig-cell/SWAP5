# Delayed daily senescence recovery

MC-NUT01-SENESCENCE-CYCLE, [PR1239](https://github.com/abhedwig-cell/SWAP5/pull/1239).
Baseline canonical `e22a677146ef49d14bd6dd6e72b78f60e340bcab`.
Status: `integration/audits/MC_NUT01_SENESCENCE_CYCLE_STATUS.json`.
Contract: `MC_NUT01_SENESCENCE_CYCLE_CONTRACT_20261015.md`.

The existing crop/soil owner retains only yesterday's unincorporated root/leaf/stem
dry matter, N, organ ages and accepted clock. The exact historical swap.f90 order
consumes that material before today's amendments, then runs crop/reactions and
retains today's actual death for tomorrow. The crop already debits death once.
Whole N includes soil, live crop and pending material; the transfer is internal.
Ordinary non-residue routes reject pending material. Staging preserves it.
All water/soil/crop/pending state commits atomically after every check.

Native S5NC0001 bytes remain unchanged without pending material. S5NC0002 adds
ten real64 values before CRC. Decoding checks bounds, accepted clock, crop loss
ledger and actual original residue incorporation on copies. Existing opaque
restart owns the full private value. No second mineral/organic inventory,
solver/tolerance change or WOFOST81 fixation/formula change is introduced.

Fresh O0/O2 closures3/44/263 exercise actual mapping, leaf ageing and root/stem
death, one-day lag, changed policy, whole N, rollback/retry/replay, zero-death
identity, old-route refusal, actual Richards carrier, all8 organic pools,
biomass/humus, NH4/NO3 and literal source supply. Original material/temperature
routes and their19 decoder negatives run again; pending native profile has30.
An extra discriminating native payload retains total N within the crop loss
ledger but violates actual residue chemistry, and rejects at both optimizations.

All six original environment/crop/reactive/mineral drivers also run again with
the changed ABI. Reuse is limited to source/compiler/hash-bound objects from this
session; fixtures/oracles/drivers and missing codecs compile fresh. Every native
assertion executes, including18/18/10/10 original decoder cases. All four physical
endpoints equal the immutable daily-environment evidence bytewise. An executable
permission interruption is retained: exact completed command/raw prefix and
unchanged build bytes were checked; only permission was restored before resume.
No native PASS was copied from another execution.

Retain the earlier test-profile failures. Leaf ageing crossed the already
excluded juvenile uptake boundary at critical LAI3; the existing exact transfer
gate correctly rejects without publication. The continued trajectory uses LAI1
and retains the original profile as a negative control. Age100 can be chemically
valid under the original humus split; invalid-age tests use100.01. No chemistry
or tolerance was changed to accommodate these tests.

The status binds actual execution commits, input hashes, raw commands/outputs,
compiler flags, all restart bytes and measured costs in its evidence capsule.
The strict successor guard checks the complete delta from baseline. Original65
material/environment controls and22 environment controls execute at the exact
baseline; current controls reject incomplete/stale/raw-corrupt science, missing
fresh provider/driver/native coverage, unbound reuse, altered literal source,
wrong endpoints and lost pending restart. Ordinary owning CLIs delegate only
after the complete current proof passes.

Exactly one stable full local moving OFF is selected for this state/restart
boundary under AGENTS and the four-level execution protocol, expected1780s.
Read status for terminal result; a running run is no PASS. Highest low-air is
NOT_SELECTED_POLICY. Compile/link/native costs are measured separately for
science; per-physics and full-shell split remain UNKNOWN.

Coverage: `integration/audits/MC_NUT01_SENESCENCE_CYCLE_COVERAGE_20261015.json`.
No master capability/count/disposition promotion. Harvest/reset/rotation remains
open under `MC_CROP01_HARVEST_ROTATION_PHASE_DECISION.md`; no storage harvest or
complete canopy lifecycle is claimed. Calendar/default activation, accepted
heat/profile coupling and simultaneous solute companions remain separate.
Pond/source stays open and aquifer stays rejected. Final PR1239 merge and exact
canonical tree/source receipt supply admission authority; premerge records are
frozen deliberately with admission false.

Terminal full local moving preservation: **PASS**, OFF, exit0, 1616.272s; all6363 tracked inputs unchanged. Actual execution `6fd1eb4bf820b985e2c5043f98f51e7af1751fc9`, tree `acfdc2654fd7731d7a4e6c34af5b7929edee4858`, source `8c9ee98d76f03c45c69f7dc20cb293c8cf4e0210`. Raw logs, complete input inventory, Git bundle and138 controls are bound in the admission capsule identified by status. Fresh physical costs122.223s compile/29.246s driver/1.837s link/149.008s native; original two-FOM requalification3.403/29.433/1.423/133.882s with audited provider reuse. Per-physics and full shell split UNKNOWN. Qualification/preservation true and admission false are deliberately frozen premerge; PR1239 merge and exact canonical receipt establish admission.
