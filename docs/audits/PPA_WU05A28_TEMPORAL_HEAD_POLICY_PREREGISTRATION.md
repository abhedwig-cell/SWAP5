# Separate head/water temporal policy pilot

Date:2026-10-05. Research only. Baseline177b796b1641f011d1d9ce7095268a077f5a9001.
The strict joint-profile experiment and its1e-5 cm head criterion remain unchanged
historical negatives. This is a new numerical-policy experiment, not its repair
or retrospective acceptance. Physical EXTERNAL_SUPPLY_PARTITION_V1_RESEARCH,
solver balances1e-5, nonlinear head1e-6, all forcing/geometry/coupling and ceilings
remain frozen. Production sources and defaults are not changed.

Observation: sampled whole/half differences near saturation include head1.9158e-5
cm versus matrix water3.1157e-9 cm, zero pond/RFM/GW differences. Strict predictor20
uses1006080 nonlinear iterations and reaches16384 substeps without solver/mass
failure. Test one head-only temporal budget1e-3 cm while keeping each original
water/pond/RFM/GW temporal channel1e-5 cm, transaction/posttrial mass1e-12,
RFM physical tolerance1e-12 and coupling flux1e-15 m/s. Implement a scaled head
channel (1e-5/1e-3)*max_head_error in the existing research norm; do not rescale
the water channels or the tolerance of any independent mass/coupling contract.

Run exact24. Compare the first19 accepted rows with strict control: maximum
groundwater-head difference<=1e-3 cm; per-tile total matrix+pond inventory
difference<=1e-3 cm; cumulative area-weighted groundwater exchange difference
<=1e-3 cm; per-tile flux deviation<=1% with explicit floor1e-9 m/s; cumulative
nonmatrix-output difference<=1e-3 cm. These are new policy-comparison gates,
not edits to A28's separate2% practical envelope. Report absolute differences,
relative/floored flux differences, nonlinear work, retries and wall-time limitations.
Do not infer accuracy beyond the strict19-window overlap. Even complete24 needs
the original nonzero RFM storage/head-excursion/explicit receiver gates before
A28 or production qualification. A failed pilot ends this new policy experiment;
do not enlarge its budget, resource ceiling or external acceptance gates.
