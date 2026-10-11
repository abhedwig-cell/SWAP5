# PPA-WU05-A26J preregistration — IC endpoint storage geometry

Date: 2026-10-01
Status: PREREGISTERED

## Purpose

Provide the minimum structural geometry needed by A26I to derive a hydrostatic macropore-side head from endpoint areic storage.

## Structural contract

For endpoint i, caller-owned immutable geometry supplies:

    macropore_area_fraction(i) = a_i, 0 < a_i <= 1
    endpoint_contact_thickness_cm(i) = L_i

RFM endpoint state stores areic water depth W_i [cm water per cm2 bulk horizontal area].

For a vertical stored-water column:

    H_i = W_i / a_i

Admitted bounded geometry requires:

    0 <= H_i <= L_i

The water-level elevation in the endpoint contact segment is then derived hydrostatically from the endpoint geometry. No residual fitting or universal default a_i is permitted.

## Falsification

Reject if:
- a_i is absent or nonpositive;
- W_i/a_i exceeds the represented contact thickness;
- mapping is nonmonotone in W_i;
- storage reconstructed as a_i*H_i does not reproduce W_i within floating precision.

This workunit does not choose a_i from observations and does not yet alter backend dispatch.
