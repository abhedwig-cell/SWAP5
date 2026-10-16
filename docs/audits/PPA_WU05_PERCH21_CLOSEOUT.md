# PPA-WU05-PERCH21 closeout — perched inner-Richards production route

Date: 2026-10-01

Status: `CLOSED_CANONICALLY_ADMITTED`

## Decision

`CANONICALLY_ADMITTED_PERCHED_INNER_RICHARDS_PRODUCTION_ROUTE`

PERCH21 is closed.

The source-backed Andelst perched authority, source-faithful FrReduQ retry/recovery controller,
numerical-continuation persistence, serialized transaction ownership and active inner-Richards
macropore exchange are admitted on current canonical under the collision-free PERCH namespace.

## Qualification

Production-admission qualification:

- postimage: `708af277cecdcb40432256d55be15139d9e507e7`;
- run: `36906093634` — SUCCESS.

The run passed PERCH20 restart and transaction continuation, PERCH19 active Andelst retry,
A10 rapid-drain preservation and the current RFM preservation surface through A26J.

## Canonical admission

PERCH21 production code was admitted by canonical commit:

`9d174a5a6baed2fe182b4a325f60c894b2cc77b6`.

Qualification/status evidence was subsequently merged canonically through PR #964.

Historical generic perched A11-A18 documentation was not merged wholesale because those generic
identifiers are owned by the later canonical RFM workstream.

## Post-merge preservation

Canonical preservation workflow head:

`8bb835a065248aad06b18a3b563234b20033ba0d`.

Run:

`36907018287` — SUCCESS.

The post-merge run passed all PERCH21 gates and additionally passed the later admitted RFM A26K
hydrostatic initial-condition head gate on the same canonical postimage.

Thus A26K is no longer merely inherited as a disjoint dependency; it is directly preserved by the
PERCH21 post-merge gate.

## Final state

- implemented: yes;
- persisted: yes;
- tested: yes;
- qualified: yes;
- production-admission candidate: yes;
- canonically admitted: yes;
- post-merge preserved: yes;
- closed: yes.

Rejected nonlinear/timestep trials retain no ownership of committed physical or numerical
continuation state. The frozen Status-A denominator is unchanged.

No further PERCH21 work is required unless a later canonical change touches its dependency surface.
