# Proposed bounded Frost/CDE/drainage composition

Status: source assessment and proposed verification contract. No new process,
configuration or corrected-reference authority is admitted by this document.
Implementation follows actual PR1774 canonical admission and reconciliation.

The existing `FROST-GEOMETRY-01` manifest explicitly excludes `SWDIVD1` and
a new fully frozen-front interpretation. Its qualification must remain intact.
The original drainage reader correctly rejects `SWDIVD0` with `SWSOLU>0`.
That invalid combination remains refused. Active macropores remain excluded.

The original production seam to assess is
`MOD_frost::FrozenCond(tsoil,tetop)` followed by
`MOD_frost::FrozenBounds()`. The latter reads the actual module
state, computes partial-frost hydraulic reductions and, for `SWDIVD1`, calls
the original `divdra(ksatcp,ztop)` with `ztop=min(gwl,zfrostbot)`.
The original CDE procedure then consumes the resulting nodal drainage sinks.
No copied drainage, conductivity, front or chemical transport equation may
replace these interfaces in the scientific component driver.

The first small driver must compile the complete actual production module
and link a measured original object closure. It supplies explicit original
grid/material, temperature and Frost-limit inputs, original hydraulic state,
drain-level geometry and flow state, and selected actual drainage controls.
It observes the complete Frost validity status and reduction arrays, lower
boundary flow, level drainage, nodal drainage and their actual consistency.
The chemical seam must bind those actual nodal sinks to the original CDE
state/receipt path. Independently reconstructed water and chemical budgets
retain the existing limits. Both O0/O2 compile, link and native costs and all
original failed or refused cases must be retained.

The driver must distinguish unchanged component implementation, a new valid
input configuration and a newly composed process seam. Existing component
evidence may be reused only with complete relevant source, object, input and
state dependency proof. The PR1774 positive CDE cell-mass component and the
existing exact interception component may be reused unchanged where their
actual procedure and input domain remain valid. Any further numerical or
reference correction requires its own real production component evidence.

Before opening public guards, enumerate the actual original valid explicit
and implicit, free and drained, water and CDE configurations. Original reader
prohibitions and established numerical failures remain separate. No new
Jacobian, front interpretation, mass compensation, epsilon storage or relaxed
convergence criterion is selected. Broader histories or calendars are composed
only after complete persistent fields and actual original procedure ownership
are established.

Any required native carry must own the complete relevant original state,
bind actual selectors and version the private payload. Foreign domains,
truncated/trailing payloads, nonfinite values and nonquiescent state must be
refused before accepting a transaction. Rejected trials preserve committed
physical state. Qualification then targets the changed coupled surface with
strict conservation, exact cold physical/native/output continuation and
prepare/discard/replay/accept/recovered-next-day checks. Unchanged full model
periods are inherited through exact dependency evidence rather than replayed.

Root `integration/f-ci/nomacro-complete01/STATUS.json` remains the recovery
authority. `GAP_MATRIX.json` owns coverage classification. Whole historical
scope remains `PARTIAL / NOT_QUALIFIED`; global family/gap counts remain
`UNKNOWN` and production/RC3 authority remains unchanged.
