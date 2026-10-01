# PPA-WU05-A16 result — bounded RFM matrix-share dynamic-top rebinding

Date: 2026-10-01

Status: QUALIFIED_PRODUCTION_ADMISSION_CANDIDATE

Baseline:

    integration/f-ci-canonical@ecfe628daf78988aec3a784f1b91b9d110d95850

Qualified postimage:

    c4783e6e59abb76d5c3b084e947fb3673416ae91

Qualification run:

    36864593396 — SUCCESS

Focused gate output:

    PPA_WU05A16_RFM_MATRIX_SHARE_REBINDING=PASS

## Qualified composition

A16 takes the canonically admitted A15 matrix share and constructs a fresh
B1.10 dynamic-top request in which that matrix share is the only positive
surface source.

Because A15 supply is already post-evaporation, A16 sets all surface
evaporation demands to zero in the rebound request to prevent double counting.

Original precipitation/irrigation/snowmelt/runon terms are likewise replaced by
the single matrix-share source.

## Real B1.10 qualification

The focused gate uses the production B1.10 dynamic-top provider with the
default-MvG BOFEK-style hydraulic fixture.

Base source:

    8 cm/day

is classified as:

    flux-controlled
    unponded
    runoff-free.

Using the A15 matrix share:

    5.961748798503473 cm/day

the rebound B1.10 request remains:

    flux-controlled
    unponded
    runoff-free

and its net potential surface flux equals the matrix share within 1e-12.

## Fail-closed gates

Qualified:

- positive original previous ponding -> REFERENCE_REQUIRED;
- deliberately excessive matrix share -> rebound becomes head-controlled and
  verification returns REFERENCE_REQUIRED;
- no head-controlled or ponded rebound is admitted.

## Negative qualification run

Run 36864496237 failed before compilation of the A16 dependency surface because
the focused runner referenced an incorrect path for
mod_restricted_surface_evaporation.f90.

The runner path was corrected only.

No production source or test semantics changed between that failed run and the
qualified postimage.

## Architecture boundary

A16 still does not mutate the live SWAP/FMR runtime.

It establishes a production-grade composition primitive:

    A15 matrix share
      -> fresh B1.10 matrix boundary request
      -> B1.10 re-evaluation
      -> bounded acceptance or Reference fallback.

Preferential routing and candidate/commit integration remain separate.

## Lifecycle

    implemented -> persisted -> tested -> qualified

Canonical admission is not claimed by this result.
