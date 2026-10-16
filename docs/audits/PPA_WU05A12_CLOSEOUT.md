# PPA-WU05-A12 closeout — canonical RFM hydraulic-view and sorptivity binding

Date: 2026-10-01

Status: CLOSED_CANONICAL_ADMITTED

Decision:

    CANONICALLY_ADMITTED_RFM_HYDRAULIC_VIEW_SORPTIVITY_BINDING

## Canonical evidence

- baseline: `03708d387f452e82044cffbff681da8252d3e717`
- qualified postimage: `facfca66e0656e622c2677a0392aa44d9bedb29d`
- focused qualification run: `36860909511` — SUCCESS
- admission PR: #932
- canonical merge: `aea20f61381f0c750fc90f2eb5201b8a40efcd73`

The earlier run `36860761059` failed only because the synthetic test provider
used an invalid Fortran test-harness declaration. The production modules had
already compiled in that run. The test-only provider was moved into a module,
after which the exact repaired postimage passed.

## Admitted capability

Canonical production source can now compose:

    process hydraulic view
      -> constitutive point K_surface
      -> transformed-integral S_surface
      -> A11 unponded activation service.

The caller remains the explicit owner of:

    sigma_B
    source rate
    event age.

## Preserved boundaries

A12 does not:

- change A8/A9/A10 top-input ownership;
- introduce hidden event-age state;
- default sigma_B;
- route preferential water;
- introduce f_MB, p or chi_wall;
- modify committed/candidate physical state;
- alter restart payload;
- add a ponded RFM branch.

Positive ponding remains fail-closed through A11.

## Post-merge preservation

The qualified dependency surface is byte-identical at the canonical merge:

    sorptivity source:
      47c7e7a5a1dce51e07a02e6457590c130cba2044
    hydraulic binding:
      85dda0d7c34b0d1bb8c383c9c3175704fc91f6fe
    focused test:
      db2dc585b44e820a818b175cc1a9562bcc4b4401
    runner:
      8350a936a11b075f5d6ecbc3f9984ef5288b08f2

Therefore the focused qualification is preserved by immutable dependency
identity without an additional CI replay.

## Lifecycle

    implemented
      -> persisted
      -> tested
      -> qualified
      -> canonically admitted
      -> closed

## Next safe step

Before actual source partition ownership can change, A13 must reconcile two
remaining owners:

1. how a committed FMR physical state is observed as the process hydraulic view;
2. how source event age is defined, reset and carried across accepted/rejected
   intervals.

The first already has an existing canonical observation seam. The second is a
physical-history semantic and must not be invented implicitly in a runtime
adapter.
