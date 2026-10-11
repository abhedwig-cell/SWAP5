# Finding — SWAP-002

## Defect

In B0 `SWAP/tillage.f90:set_iTill`, the interval test is logically impossible:

```fortran
if (t1900 >= Date_tillage(i-1) .AND. t1900 < Date_tillage(i-1)) iTill = i-1
```

The same `Date_tillage(i-1)` is used as both lower and upper bound. Consequently the condition can never be true.

## Why the index matters

Elsewhere in the tillage module, `iTill` denotes the next tillage event still to be executed. At an event date SWAP executes `Date_tillage(iTill)`, applies the event and only then increments `iTill`.

Therefore a run starting:

- before the first event must use `iTill=1`;
- exactly at event `i` must use `iTill=i`;
- between events `i-1` and `i` must use `iTill=i`;
- after the final event must use `iTill=Ntill+1`.

When the start is after a historical event, `Change_Tillage_Info(iTill-1)` loads the most recent previous tillage/consolidation parameters so the subsequent consolidation path uses the correct historical parameter set.

## Classification

This is a control-flow/state-initialization implementation bug, not model development. The central audit register records SWAP-002 as `FIX_TESTED`, very-high certainty, high severity, with the possible impact that tillage events are skipped or historical tillage state is initialized incorrectly for runs that start between events.

## Scope boundary

The correction changes only `set_iTill`. It does **not** include:

- SWAP-003 (`PCLAY=0` with tillage N-model 2);
- SWAP-004 (tillage type-index allocation/validation);
- tillage constitutive formulations;
- solver policy;
- time-step policy;
- any mass-balance tolerance.
