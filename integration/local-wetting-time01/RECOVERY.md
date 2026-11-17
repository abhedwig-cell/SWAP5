# One local irrigation and rain temporal policy

Baseline actual canonicalfd162a1ea22c41e798a431f39957aaff9c173e46.
Previous causal storm proof4febf34c2: refining only212..215 with exact own
211day prehistory reduces1.39949cm GWL gap to about0.001cm. No original
equation, forcing or1e-10 water/solute/scientific criterion may change.

Implement explicit original-adaptive-local-wetting-v1 over original TimeControl:
one memory-free proposal limiter. Retain duration/2048 for active subdaily
irrigation and bound above-ground supplied depth per step to0.02cm using actual
net rain plus gross irrigation. DTMIN remains a floor and DTMAX never increases.
No day/date/fixture threshold or global time cap. Rain is first sampled only
after Meteo3 in TimeControl4, then while within a day; skip stale rain when
proposing the next day. All inputs are existing owned rate/duration/clock fields;
no new saved history or native format. Old policies/defaults remain exact.
Reject active frost/snow/macro domain, foreign/missing numerical metadata and
cross-policy restart. This is bounded supplied-water resolution, not a proven
general error estimator or scientific equivalence claim.

Select actual TimeControl O0/O2 limiter controls; first short6day irrigation and
215day storm prefixes/native211to213/213to215. Check effect against immutable
nominal and refined original431 diagnostic results before full runs. Then
four Windows full1096 O0/O2 water/chemical, seasonal/pulse/storm/terminal exact
native windows, independent balances, instances, rollback/external disk recovery,
literal original431 full comparison, paired prior pulse-policy model cost.
Use30s full-model/20s original caps. Expected model~10s, compile~15s/build;
stop/refuse instead of raising caps if bounded selection is not practical.
Dedicated Ubuntu repeats affected qualification only; reuse valid earlier
controls/results when their actual dependencies match. No broad campaign.
After two unsuccessful repairs reassess; retain all failed/censored outcomes.
Deliver source/build/input/raw identities and scientific/cost limits in a PR.
