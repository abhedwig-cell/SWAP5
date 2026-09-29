# F-PE-NLGLOB13C result — near-saturation accepted-state overshoot scaling

Date: 2026-09-29

Status:

`BLOCKED_NLGLOB13C_SCALING_COVERAGE`

Canonical base:

`integration/f-ci-canonical@ef08f11b5576bec92d66c445e0c577e680215487`

Qualification authority:

- workflow run: `36556318878`;
- job: `109366213738`;
- conclusion: SUCCESS.

## Frozen question

Does accepted-state retention overshoot contract systematically from the failing h/2 interval to the corresponding h/4 retry from the same restored pre-half state?

## Observed scaling signal

All 7 target trajectories produce finite positive h/2 and h/4 overshoots.

All 7 have:

`Q = O_(h/4) / O_(h/2) < 1`.

Observed aggregate signal:

- contracting pairs: 7/7;
- median Q: `0.46248`;
- median apparent exponent p: `1.11253`;
- maximum h/4 normalized overshoot: about `8.71e-5`.

This is a strong apparent contraction signal.

## Coverage blocker

The preregistered same-pre-state identity gate does not pass for all seven pairs.

- 5/7 pairs pass the frozen roundoff-level pre-state fingerprint;
- 2/7 fail it;
- both failures occur at nominal dt `3.125e-5 d`, one HEAD and one RUNOFF.

Because the same-pre-state requirement was a hard coverage gate, the scaling result cannot be classified as qualified contraction.

Frozen classification:

`BLOCKED_NLGLOB13C_SCALING_COVERAGE`.

## Interpretation boundary

Do not reinterpret the observed median contraction as qualified evidence yet.

The blocker must first be attributed:

- either the h/4 retry is not actually restored to the exact failing-half pre-state, which would reveal a transaction/subdivision defect;
- or the diagnostic fingerprint is too sensitive or incomplete even though the restored physical state is equivalent within representational authority.

Those are materially different outcomes.

## Consequence

Open a bounded successor:

`F-PE-NLGLOB13C1 — failing-half pre-state identity reconciliation`.

It must not change any temporal solver behavior.

It should compare the actual nodewise accepted pre-state used for the h/2 failure and h/4 retry, including moisture, head and ponding, and quantify physical storage difference.

Only if state identity is established may the NLGLOB13C scaling evidence be re-evaluated under its original frozen contraction gates.

## Production boundary

Research diagnostics only.

No production `src/**` change.

No numerical or physical acceptance authority changed.

`LEGACY_NUMERICS` remains production default.
