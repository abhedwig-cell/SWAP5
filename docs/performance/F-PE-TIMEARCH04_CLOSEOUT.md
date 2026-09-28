# F-PE-TIMEARCH04 closeout — hard-event scheduler characterization

Date: 2026-09-28

Final status:

`QUALIFIED_EVENT_SCHEDULER_SEPARATION_TARGET`

## Main findings

### Bound mutation versus exact event clipping

Removing permanent output-induced numerical-bound mutation while retaining exact output event boundaries is mostly not a performance gain by itself:

- median scheduler-only/current step ratio = 1.00;
- only 1/20 grid points changed by >=10%.

The current duplication is architecturally undesirable, but generally not the dominant step-count cost.

### Output as physical hard stop

The counterfactual output-decoupled shadow shows large theoretical headroom when output cadence is fine:

- material reduction in 14/20 grid points;
- median step ratio about 0.431;
- fine-output median ratio about 0.224.

This is an upper bound only. Output semantics must be qualified separately before physical step endpoints may be decoupled from reporting times.

### Proposal-memory interaction

TIMEARCH04A confirms that event clipping can contaminate numerical-controller history.

Preserving preferred dt across event clamps can materially reduce fragmentation in some scenarios, but the simple frozen rule was not uniformly non-inferior and therefore did not qualify.

### Exact Hupsel context

The exact Hupsel workload has:

- 32518 timestep records across 1096 days, about 29.67 steps/day;
- NPRINTDAY=1;
- SWMETDETAIL=0;
- SWRAIN=0;
- SWRUNON=0;
- SWMACRO=0;
- DTMAX=0.04 d.

For this workload, fine-grained output/meteo/rain/runon/macropore event controls are inactive.

A DTMAX of 0.04 d alone implies at least 25 numerical intervals per full day.

Thus Hupsel's roughly 30 steps/day cannot primarily be explained by dense scheduler events. Fixed numerical-step policy remains the more important target there.

## Architecture decision

Keep scheduler extraction as part of the redesign, but do not treat it as the main general performance lever.

The stronger next target is retry and numerical-policy ownership:

- distinguish accepted-step proposal from failed-trial retry;
- reconcile legacy internal retry with outer transaction/temporal retry;
- preserve exact hard-event boundaries independently.

## Required successor

`F-PE-TIMEARCH05 — retry ownership reconciliation`.

TIMEARCH05 should characterize whether legacy internal retry and SWAP5 transaction retry duplicate work or serve distinct nested scopes, and define a single explicit ownership hierarchy before production migration.

## Production boundary

No production `src/**` changes.

