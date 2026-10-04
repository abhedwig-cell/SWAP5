# PPA-WU05-D2 runtime composition contract

Canonically admitted by PR #1012, merge `4fd57c8c8ed321baf6a74214a9720adc899e324d`.
Qualification: `integration/audits/PPA_WU05D_D2_QUALIFICATION.json`.
Historical implementation baseline: fae6d8d3.

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

## Accepted root-result publication successor

The negative application oracle exposes an existing accepted-result defect: the
serialized runtime reports the untransformed forcing integral as actual transpiration.
The bounded repair adds optional actual-transpiration result metadata to the existing
trial/transaction/canonical/kernel result route. This is informational publication of
water already owned by the final root-sink provider, not a new ledger or mass receipt.
It does not enter committed physical state, checkpoint or restart payloads.

The model publishes sum(final_sink) * trial_duration. The transaction selects only
its accepted route (accepted two halves or the model-certified outcome). The canonical
runtime sums accepted subinterval amounts and publishes only after the whole interval
completes. Serialized output becomes visible only after successful candidate commit.
Rejected trial amounts and failed intervals cannot be published as actual transpiration.
All existing mass, temporal, commit and sensitivity contracts remain fixed. Default
unavailable metadata preserves model implementations that do not supply the quantity.
This successor touches shared result interfaces explicitly and requires qualification
of full/half selection, model certification, retry, rollback and interval publication.

The standalone/prescribed-qbot application profile admits Jarvis with the existing
Feddes forcing and no Bartholomeus/thermal carrier, on bottom modes 2/7 only. Oxygen
remains optional. The original root-active profile without compensation or oxygen
is not widened. Elasticity, direct retention, evaporation combinations and other
bottom/application profiles remain outside this bounded entry point.
