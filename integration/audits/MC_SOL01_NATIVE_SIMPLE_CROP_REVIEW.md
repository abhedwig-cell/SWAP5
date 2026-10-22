# Native simple-crop preparation review

Owner: MC-SOL01, existing dynamic decay record, daily ETref child,
`simple_crop_preparation_successor`. Exact baseline f95b95d1. No whole-model claim.

The missing original fixed-crop phenology is a pure production proposal with
explicit parameters, input state, forcing, candidate and status. The original
whole `fixed.f90` module, native reader and interpolation helpers are compiled
as an independent oracle; no copied replacement phenology supplies the oracle.
Data-only legacy context modules select the bounded branch. Original air means
advance biological phenology at day end; they are not soil thermal boundaries.

Results:52 native processes; eight O0/O2 schedules,64 days,576 exactly identical
values, eight fresh-process repeats and22 rejected native inputs. Direct state
checks cover both development branches, an anthesis-crossing day, invalid and
nonfinite state/forcing, A/B/A proposal repeat, nonmutation, tiny positive thermal
denominators and cumulative-state limits. Existing modular feedback compiles one
production provider and its driver in0.26/0.31 observed seconds for O0/O2, with
three compiler requests each. This is a local observation, not a speed claim.
Native preparation compiles seven application/production providers plus153
immutable original TTUTIL providers; the latter closure is justified by original
input grammar, not physical state. Compile and execution timings remain separate.

The first compile failed because a local integer shadowed the INDEX intrinsic.
The first native fixture used a scalar date instead of the original calendar table;
the next observation exposed an uninitialized fixed-count read. These failed
results are retained. The final reader checks every crop column's count before
reading it. All computations finish before CSV creation. Nothing is published by
invalid preparations. Original malformed-input diagnostics are not counted PASS.

No incumbent production file, application, forcing, solver, state or restart
layout changes. The predecessor's complete raw validator executes against every
current compiled/test input byte, including existing NUT project evidence.
Its source/verify/control entrypoints gain exact additive handoffs; every original
assertion body is preserved byte for byte. New scientific changes are enumerated
and pinned independently. No blanket physical rerun is selected for an uncalled
new module or valid potential values. This is not new coupled crop qualification.
Full F-CI: NOT_SELECTED_IMPACT. Highest low-air: NOT_SELECTED_POLICY.

Next dependency-ordered work: native root-density/stress import and explicit
prepared-demand handoff to accepted Reference hydraulic/root/solute ownership,
with hard balances, rejection/rollback and exact independent-process restart.
Do not replace that obligation with prescribed arbitrary constant sinks.
