# F-PE-BOFEK-PRACTICAL03 preregistration — hydraulic-archetype + regime validation

Date: 2026-09-28

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@1113eb11966f3e5a5ced5c6e14f243d6de79a3b5`

Parents:

- PRACTICAL01: no global P-C1 policy;
- PRACTICAL02: regime-only candidate failed 3/16 new validation cases, all on runoff accuracy.

## Purpose

Test one final research-only policy that combines regime information with the already-defined repository-backed hydraulic archetypes.

This is not a BOFEK-ID production policy. The repository still lacks an authoritative BOFEK catalogue.

## Frozen candidate policy

### B12 conservative fallback

For B12 in every regime:

- Reference DTMAX;
- initial dt = 0.5 * DTMAX.

Reason: B12 showed sensitivity in both transition and ponding validation.

### O14 ponding fallback

For O14 in POND:

- Reference DTMAX;
- initial dt = 0.5 * DTMAX.

For O14 outside POND, use the regime rule below.

### Default regime rule for B01, O05 and non-POND O14

- DRY / TRANSITION:
  - DTMAX = 4 * Reference DTMAX;
  - geometric initial dt.
- WET:
  - Reference DTMAX;
  - initial dt = 0.5 * DTMAX.
- POND:
  - Reference DTMAX;
  - initial dt = DTMAX.

All other numerical controls remain Reference.

No head-tolerance relaxation is included.

## New validation bank

Use four new forcing/state points, distinct from PRACTICAL01 and PRACTICAL02:

- DRY3:
  - h0 = -250 cm;
  - rain = 1.0 cm/day.
- TRANS3:
  - h0 = -60 cm;
  - rain = 5.0 cm/day.
- WET3:
  - h0 = -25 cm;
  - rain = 11.0 cm/day.
- POND3:
  - h0 = -8 cm;
  - rain = 20.0 cm/day.

Use all four hydraulic archetypes B01, B12, O05, O14.

Horizon remains 0.12 d.

Total validation cases: 16.

## Accuracy gates

Reuse P-C1 unchanged:

- runoff <= 0.01 cm absolute when baseline runoff <1 cm, otherwise <=1%;
- terminal storage <= max(0.01 cm, 0.5% baseline terminal storage);
- terminal ponding <=0.02 cm;
- top/mid/bottom head <=2.0 cm;
- max ledger <=5e-8 cm;
- no solver failure;
- rejected attempts <= max(2x baseline, 25% candidate attempts).

## Performance and validation gate

Candidate validates only if:

1. at least 15/16 cases pass P-C1;
2. all WET3 and POND3 cases pass;
3. every hydraulic archetype passes at least 3/4 regimes;
4. median deterministic work reduction across passing cases >=20%;
5. no regime has negative median work reduction;
6. no retry pathology occurs.

If validated, execute five paired process-level timing repetitions per case.

Timing is supporting only. A production qualification is not allowed from startup-dominated millisecond timings.

## Stop rule

This is the final adaptive-policy refinement in this line.

If PRACTICAL03 fails, close practical BOFEK policy optimization as:

`CLOSED_NO_PRACTICAL_POLICY_GAIN`

If it passes, close as:

`PRACTICAL_MODE_CANDIDATE_RESEARCH_ONLY`

No further material-specific rescue policy is permitted in this workunit.

