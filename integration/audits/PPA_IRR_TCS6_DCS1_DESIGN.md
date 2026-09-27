# TCS6 with supplied-deficit DCS1

Branch-local process extension; not runtime or canonical qualification.
Baseline `b4ff0bf3c`. Owning counter/publication contract remains
`PPA_IRR_TCS6_OWNER_DESIGN.md`.

Release `SWAP/irrigation.f90` lines 519-531 select the weekly event using cdef;
lines 567-576 compute DCS1 depth from the same cdef, correction table and strict
rainfall threshold. The release member was reread from the supplied nested ZIP.
TCSFIX, solute overirrigation and alternate delivery remain excluded.

Extend the existing pure weekly composition to accept DCS1 as well as DCS2.
For DCS1, copy the request and bind its deficit from the explicit weekly deficit
argument so timing and amount cannot use inconsistent deficits. Reuse the
existing depth calculation, limits, event splitting and pending-event handling.
No state owner, publication, tolerance or default policy changes. Failed/split
proposals retain the original counter. Qualification first covers independent
amount arithmetic; profile derivation and daily runtime admission remain separate.
