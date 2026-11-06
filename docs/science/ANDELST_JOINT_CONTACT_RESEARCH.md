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

Full V2 execution and its exact own restart must be judged from terminal results
in the recovery record. Component PASS alone does not admit that model or close
original Andelst481, energy equivalence or historical scientific qualification.
