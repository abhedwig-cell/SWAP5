# F-MACRO-TRACER01-D1S — publication initial-state sensitivity result

Date: 2026-10-01

Status: QUALIFIED_SENSITIVITY / DEEP_INITIAL_STATE_NOT_EXPLANATORY / D2_CONDITIONALLY_AUTHORIZED

Canonical SWAP5 authority:

    integration/f-ci-canonical@ebea588070f7a44dbaea78169f2548c745061c48

Qualified run:

    GitHub Actions run 36850783213
    exact head 6aa0ebbf933ea5055c4fbc42e619da809f604cae
    artifact f-macro-tracer01d1s-sensitivity
    artifact id 11155541836
    artifact SHA256 568865eb8fb83f9696f1fcfb5384b571305ad3330d9ae5b418da67f6f6087260

## Purpose

Test whether the unknown deep pre-irrigation theta(z) state can plausibly account
for the observed Spechtacker bromide depth signal without preferential routing.

This is a sensitivity-conditioned publication case, not an exact replay.

## Frozen envelope executed

Five publication-faithful SWAP5 matrix-only members were run with:

    theta upper 20 cm = 0.274
    theta at 1 m = 0.234, 0.254, 0.274, 0.294, 0.314

and a linear transition below 20 cm.

All members used publication forcing and publication hydraulic parameters only.
No echoRD initial state or hydraulics entered the case.

## Numerical result

All five members completed with:

    accepted packets = 720
    solver retries = 0

Maximum absolute global tracer residual:

    1.7763568394002505e-15

Maximum reconstructed bottom-flux residual:

    2.826829048618862e-12 cm/day

Maximum normalized profile L1 change relative to the central member:

    0.0036148499233657322

Thus the matrix-only result is numerically stable across the preregistered
deep-initial-state envelope.

## Depth sensitivity

Across the five members:

    tracer centroid = 0.094342 to 0.095179 m
    fraction below 20 cm = 0.082754 to 0.086151
    fraction below 50 cm = 5.735e-6 to 7.223e-6
    bottom tracer export = 0 to 5.963e-22

The observed Spechtacker Profile 1 tracer centroid from ALT51 is approximately:

    0.176 m

The matrix-only publication-faithful sensitivity family therefore remains much
shallower than the observed conservative-tracer profile.

Changing the unobserved deep initial theta over the deliberately broad stress
envelope shifts the tracer centroid by less than 0.001 m and changes the full
normalized profile by less than 0.004 L1 relative to the central member.

## Interpretation

The missing deep initial theta(z) prevents an exact replay claim, but it does
not plausibly explain the observed depth penetration within this preregistered
envelope.

Therefore the initial-state uncertainty is no longer a blocker to asking the
bounded forward question:

    can the frozen RFM composition account for the additional observed
    conservative-tracer depth while preserving the 95% recovery constraint?

That question must remain sensitivity-conditioned.

## Decision

    EXACT_SPECHTACKER_REPLAY = STILL_NOT_CLAIMED
    INITIAL_STATE_SENSITIVITY_GATE = PASS
    MATRIX_ONLY_NO_DISPERSION_DEPTH_SIGNAL = TOO_SHALLOW
    DEEP_INITIAL_STATE_AS_EXPLANATION = NOT_SUPPORTED_WITHIN_ENVELOPE
    D2_SENSITIVITY_CONDITIONED_FORWARD_COMPARISON = AUTHORIZED
    DISPERSION = NOT_AUTHORIZED
    NEW_RFM_PHYSICS = NOT_AUTHORIZED
