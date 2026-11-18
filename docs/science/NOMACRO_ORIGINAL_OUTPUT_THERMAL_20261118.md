# Original output with complete snow and thermal history

**Proposed / implementation in progress; not admitted.** Baseline is actual
canonicaldcd880bbc0b6ff62fd2a28c68b080ac0811090ac after PR1729/1730. Its actual
source and metadata merge trees and detached registered owners pass.
Historical closure remains PARTIAL, science NOT_QUALIFIED, fixed RC3 unchanged.

## Reconciled source and ownership

Existing `donor_sources.py` preserves original snow/heat conductivity, capacity,
top/bottom temperatures and complete hydraulic/micro lookup state. Original
snow and bounded frost routes are admitted separately. The original-output
owners deliberately exclude snow/frost. Their receipt start/end snow stock is
zero and three real Integral increments (`isnrai`, `igsnow`, `isubl`) are not
observed. Removing the selector refusal would therefore lose conservation.

The new bounded composition observes actual MOD_snow ssnow at original daily
receipt start/end and the three actual original Integral snow increments. No
snow, heat, hydraulic, frost, uptake or CDE equation changes. The literal output
receipt provider and complete existing physical/native owners are retained.
A separate paired actual process-domain witness precedes the literal calendar
and CDE-private output owners. Water and CDE use separate typed codecs.

## Bounded implementation and qualification contract

Use existing explicit `--original-output`, absent macropores, analytical soils,
SWBR0, SWSNOW1, SWHEA1, SWCALT2 and no detailed weather. Initially qualify dense
daily NP1/PERIOD1 output only, formats0..3, original groups and precision,
hysteresis0/1/2, water and existing supported CDE. Existing bounded frost water
may use its exact accepted free-bottom or drained/event-closure policy; the
original reader's chemical frost/drainage refusal remains authoritative.
Sparse/monthly/explicit/per-step thermal output needs its own trial-clock work.

Validate actual snow accumulation/melt and sublimation observations, water and
chemical1e-10guards, all complete native/user files after active snow/thermal
and year/terminal cold windows, source/native/domain/input refusal and actual
external discard/replay/accept/recovery. Local O0/O2 precede full Windows/Ubuntu
periods. Preserve qualified aquifer, age, output/hysteresis and named routes
using fresh focused executions and unchanged immutable raw references. Add a
source-bound registered owner and actual committed negative source control;
admit only the actual ordered-parent/full-tree canonical merge after its
own detached owner passes. No existing helper or proof is rebound.

Affected invariants:3,4,7,13,21,23,30. Record and persist before compiling.
