# Tabulated hydraulics characterization

This directory is an evidence-only research harness. It does not change SWAP5 production physics or claim admission of tabulated hydraulics.

## Correction of the first probe

The first near-saturation probe on this branch was incomplete: it reproduced the explicit assignment `ientrytab(lay,1)=0` but omitted the immediately following descending fill of empty lookup bins. That made the initial out-of-bounds result artificial. That probe is superseded and must not be cited as a defect in the real initialized table route.

The current harness reproduces the complete lookup-table preprocessing sequence before calling the actual `EvalTabulatedFunction` from the pinned public SWAP implementation at commit `c22bd832ddf3e53e330a552f5e31e74f183362d1`.

It constructs a monotone Mualem-van Genuchten table, applies the current log transforms, lookup-bin construction and backward fill, runs the actual TSPACK preprocessing, and evaluates theta(h), K(h), C(h), and dK/dh on a dense pressure-head grid down to the near-saturation range. The workflow uses `-fcheck=all` so indexing and other runtime violations fail the characterization.

This is a characterization of the current public table numerics, not yet proof that the SWAP5 production application can select this route. SWAP5 canonical currently admits only the analytical `SWSOPHY=0` provider.
