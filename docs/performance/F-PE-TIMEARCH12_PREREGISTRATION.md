# F-PE-TIMEARCH12 preregistration — H0-gated automatic controller application

Date: 2026-09-28

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@eb3a5718a5b7b0b24ebe744e595b781882e7f25a`

Parent authority:

- TIMEARCH11 — AUTO_REFERENCE controller interface qualified;
- PREDICT03 — H0 cheap dynamic-top classifier validated research-only;
- EMBEDSTEP02 — conservative split-large-step route physically robust but insufficiently fast.

## Candidate policy

Normal intervals remain under current Reference ownership at or below 0.02 d.

A normalized history proposal may request an outer interval up to 0.08 d using:

`r_last = max_i(|h_i(t_k)-h_i(t_{k-1})| / max(10 cm, |h_i(t_{k-1})|))`

and frozen target:

`R = 0.40`.

For a requested interval > 0.02 d:

### H0 SAFE

Execute one full large interval only when:

1. two accepted history intervals are available;
2. origin-frozen corrected dynamic-top predictor is available;
3. origin-frozen runoff potential is false;
4. `r_last <= 0.10`.

### H0 NOT SAFE / unavailable

Execute the large requested interval as two sequential half intervals.

Thus H0 can only remove conservative splitting. It cannot create a large-step request by itself.

## Fallback

If any candidate large-step full solve fails:

- discard it;
- execute the same outer interval using the two-half fallback;
- if fallback fails, return to legacy retry reduction.

Rejected trials do not update accepted history.

## New validation bank

Use all four hydraulic archetypes with four new state/forcing points not used in PREDICT03:

- DRY5: h0=-220 cm, rain=1.2 cm/day;
- TRANS5: h0=-70 cm, rain=5.5 cm/day;
- WET5: h0=-28 cm, rain=10.5 cm/day;
- POND5: h0=-9 cm, rain=19 cm/day.

Horizon: 0.12 d.

Total: 16 cases.

## Comparator

Current corrected legacy Reference execution with current timestep policy.

## Strict Reference gate

Per case:

- cumulative runoff difference <= 1e-4 cm;
- terminal storage difference <= 1e-4 cm;
- terminal ponding difference <= 1e-4 cm;
- top/mid/bottom head difference <= 1e-3 cm;
- max ledger <= 5e-8 cm;
- no new solver failure/retry pathology.

A candidate can be called an AUTO_REFERENCE algorithm candidate only if >=15/16 pass and every WET/POND case passes.

## Practical P-C1 gate

If strict fails, separately evaluate unchanged P-C1:

- runoff <=0.01 cm absolute when baseline runoff <1 cm, otherwise <=1%;
- storage <=max(0.01 cm,0.5% baseline terminal storage);
- ponding <=0.02 cm;
- top/mid/bottom head <=2 cm;
- max ledger <=5e-8 cm;
- no retry pathology.

## Performance gate

Count all deterministic solver work, including fallback/split work.

Required:

- median work reduction >=15%;
- no regime median regression;
- at least 75% of cases non-inferior.

## Classification

Possible outcomes:

- `AUTO_REFERENCE_ALGORITHM_CANDIDATE_RESEARCH_ONLY` if strict + performance pass;
- `PRACTICAL_COUPLING_ALGORITHM_CANDIDATE_RESEARCH_ONLY` if strict fails but P-C1 + performance pass;
- `CLOSED_H0_APPLICATION_NO_GAIN`;
- `CLOSED_H0_APPLICATION_PHYSICAL_FAIL`.

No production execution binding in TIMEARCH12.
