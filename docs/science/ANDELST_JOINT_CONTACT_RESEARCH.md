# Andelst joint contact research

## Scope and authority

This is an explicitly corrected research model, not historical SWAP 4.3.1
equivalence or a production-default contact law. The original sharp model still
has its recorded 1.958-day barrier. Original Andelst481 and an exact own
year-boundary restart remain open. Grassgrowth and Hupsel admissions are separate.

The implementation starts at canonical `b4107989d5f31e4f051dfbbf5b98bd182e152d64`.
The later `6bcacb0af5890db0d54fa9b24a7f322f36de76c2` delta contains pond-thermal
evidence and documentation, with no changed Richards or macropore implementation.
The [versioned recovery record](https://github.com/abhedwig-cell/SWAP5/blob/codex/andelst-joint-entry-20261106/integration/dataqual15/JOINT_ENTRY_RECOVERY_20261106.json)
owns exact source identities, execution costs, failures and the next safe action.

## Implemented numerical seam

`mod_reference_bordered_solver` solves the complete tridiagonal plus low-rank
soil matrix with additional equality constraints through a pivoted Schur system.
Both matrix and constraint blocks are checked against their original coefficients.
Invalid shapes, nonfinite inputs, missing paired storage factors and singular
systems refuse publication; failure outputs remain zero. This module owns no
physical state, contact law or I/O. Ordinary production callers are unchanged.

The research builders render private, source-pinned overrides of the existing
physical operators and Reference corrector. They retain the original water,
temporal, nonlinear, rollback and restart gates. All heads and active exchange
fractions are solved together. The same signed domain exchange feeds matrix
residuals, macro stocks, vertical reconstruction and sorption history. There are
no repeated outer scalar corrections, source smoothing or tolerance changes.

`ANDELST_SHARP_ENTRY_GRAPH_V1` completes the discontinuous Darcy-entry graph at
the original entry plane with a bounded exchange fraction. Entry width stays
zero. Any positive Darcy occurrence terminates the sorption event. It does not
interpolate persistent clocks.

`ANDELST_JOINT_ENTRY_PERCHED_ACTION_GRAPH_V2` additionally locates a perched top
cell from the actual column, without fixed cell numbers or time windows. Its
constraint is `w*h(i)+(1-w)*h(i+1)=0`, with
`w=1-dz(i)/(2*disnod(i+1))`. Both pressure columns enter the complete Jacobian.
A perched fraction multiplies sorptivity action, not elapsed time: for accepted
clock `tau`, `a=lambda*dt/(sqrt(tau+dt)+sqrt(tau))`, the candidate clock is
`tau+a*(2*sqrt(tau)+a)`. The corresponding sorption reference uses the same
action. A zero fraction ends the event. History updates never alter water stocks.
The fraction is worker scratch, reconstructed during a solve; no stream schema
or stored restart bytes are changed or rebound.

## Completed bounded evidence

Real GNU O0/O2 component drivers exercise 112 heads, shared storage rank two,
two constraints, ordinary rank zero and refusal cases. Private physical operator
and real history-update drivers exercise entry and perched endpoints, partial
action, unchanged water stocks and nonfinite/mixed-smoothing refusal. Reproduce
with `python tests/dataqual15/run_joint_entry_contracts.py --joint-contact
--compiler <gfortran> --output <new-directory>`.

V1 from original initialization crosses the original entry barrier but is censored
at source time 2.779999999999589. O0, O2 and strict own day-two continuation have
399 exactly equal common day-three progress rows. The largest completed daily
water residual is `9.452341605008484e-14 cm`. These are censored prefixes, not
481-day or year-restart qualifications. Day-one physical payload agrees exactly
with the unchanged original path.

A read-only V1 observer then stops at `dt=7.629394449537585e-9 day`, nonlinear
residual `0.008517296128841556 cm/day`, at the perched 24/25 plane. One-sided
exchange differs by `0.06472638454752665 cm/day`. This explains selection of the
joint perched extension; it is not a proof that no other full-column historical
solution exists. The diagnostic seed stays immutable, publishes no restart, and
does not qualify a cross-executable own restart. Earlier censored observers and
the rejected mixed-module diagnostic build remain in the evidence archive.

V2 original-initialization runs complete three days at O0 and four at O2 before
300-second censoring. The common 1,529 progress rows are exact. A strict own O0
day-three continuation repeats 326 overlapping rows before its 120-second limit;
a strict own O2 day-four continuation repeats all 383 overlapping original-run
rows exactly and completes through day43. The largest completed daily water
residual is `1.1061381684936018e-12 cm`. The latter run fails after314.145 seconds,
rather than timing out, at attempted endpoint43.340000000000416; the last accepted
endpoint is43.33800000000041. The accepted-flux-trace materializer refuses
publication. A read-only instrumented native run confirms Rutter preparation
succeeds; the earlier generic Rutter-clock diagnostic is not the cause. The
trace failure is resolved by the separately admitted positive-stock packing
correction described in [positive macropore storage](MACROPORE_POSITIVE_STORAGE.md). The sealed raw old result incorrectly
labels the attempted endpoint as completed; its `cost.csv` marks that row false.
The execution reporter now distinguishes attempted and completed endpoints.

These results establish bounded corrected-model progress and exact overlapping
own continuations. They do not complete corrected481, a year-boundary restart,
original Andelst481, energy equivalence or historical scientific qualification.
The research model remains explicitly selected by a separate source-bound build;
ordinary production source callers and physical contact laws are unchanged.

## Admission and current-profile coupling successor

The bounded solver and private V1/V2 research sources are canonical through PR1591,
actual merge `db42f99e2de9cae43dfe04bbf291e8e214edd6f7`, with parents
`0c85785b65653155718e17ecc5d5590cc2de52c6` and
`0aba566443bf7a7ab013f33e4c44051076edc1b5`. Focused Linux border/contact O0/O2
contracts and strict documentation pass. This admits a numerical library and
explicit research recipe, without activating the private contact model in production.
PR1593 subsequently admits the positive-pocket correction. V2 then completes
65 original-input days before a separate temporal rejection at65.17499999999755.

At this transition the old full/half head discrepancy approaches
`0.08219235171827655 cm`, above the unchanged0.01cm gate, even at a
`1.4210854715202004e-14 day` assessment width. The current Richards heads and
lagged groundwater-dependent process views disagree across a desaturating pocket.
Private V3 recomputes the existing CALCGWL projection from the current candidate
and adds its complete crossing-head Jacobian columns. The actual native replay
still fails, now with `0.03402854927105636 cm` at node86. A frozen-drainage
intervention isolates the remaining lag; it is diagnostic evidence only and is
explicitly rejected as a physical successor.

Private `ANDELST_JOINT_CURRENT_GROUNDWATER_DRAINAGE_GRAPH_V4` evaluates the real
DRAMET3 response and signed DIVDRA partition from that same current profile inside
every nonlinear residual. A synchronous worker-local callback returns candidate
rates without changing bound drainage during Newton. The identical functional
rate is recomputed before final transport, mass and accepted-trace publication.
Its lifetime ends with the advance; it adds no committed field or restart schema.
The complete current-groundwater Jacobian columns retain the shared-storage factors.
No temporal, nonlinear, water, rollback or restart limit changes.

The actual read-only65 source replay passes unchanged backend certificates:
eight attempts, zero solver refusals, four temporal refusals and four accepted
internal substeps in2.9275 seconds. Its origin remains immutable and it publishes
no restart. O0/O2 current-view physical interfaces and scoped callback/refusal
contracts pass; the callback driver alone does not qualify DRAMET3 science.
A fresh original-input O0 day completes with maximum water residual
`9.546109427027369e-14 cm`. Per-Newton file logging is now opt-in via
`SWAP5_JOINT_CONTACT_DIAGNOSTICS=1`; unchanged day-one physical payload and all
budget/progress/cost/diagnostic rows prove the logging-only change at O0.
The separate quiet O2 full481 request is pending its terminal result and own
continuations; the read-only probe establishes neither of those claims.
Authority: `integration/dataqual15/TRANSITION65_RECOVERY_20261106.json`.
