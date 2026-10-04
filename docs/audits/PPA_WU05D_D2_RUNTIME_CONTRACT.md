# PPA-WU05-D2 runtime composition contract

Implementation checkpoint, not admission. Canonical baseline fae6d8d3.

The existing drought owner supplies the uncompensated sink, potential transpiration,
and drought reduction. For mixed admitted drought and Bartholomeus oxygen it also
supplies its existing potential_root_sink vector through optional root_potential_sink.
This is disposable forcing, not physical continuation or restart state.

Bartholomeus execution optionally publishes the factors it already computed. Existing
calls and OFF behavior remain unchanged. No second oxygen evaluation is introduced.
For each node, dry = uncompensated_sink / potential_sink and wet is the admitted oxygen
factor. The combined loss is potential_sink - uncompensated_sink * wet, apportioned
in proportion to (1-dry) and (1-wet), as in the reconstructed source family. Sequential
loss attribution is incorrect: dry=wet=0.5 gives losses (0.375,0.375), not (0.5,0.25).
Mixed composition without the potential vector fails closed.

Jarvis rescales the final candidate once. Uptake is recomputed from final nodes.
A floating-point overshoot of PTRA is removed by moving the largest sink downward
by representable increments. This preserves the hard bound without relaxing tests.

The existing root-sink provider remains the only water owner. Factors, attribution,
and compensation results are disposable trial scratch. Rejected trials restore the
uncompensated input. No compensation restart payload is introduced.

Affected invariants: 3,4,5,7,13,21,23,29. Required evidence: independent node algebra,
real backend execution, discard/replay/commit/restart, O0/O2, existing oxygen and Feddes
preservation. Salinity, frost, MICRO and Walsum are outside this D2 implementation.
