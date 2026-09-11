# F-TB02 — Hydraulic Constitutive Verification Catalog

## Purpose

F-TB02 is the first incremental catalog buildout under the qualified F-TB01 testbank architecture. It does not reopen F-TB01 and does not change production source, existing tests, reference material, physics, solver policy, runtime semantics or I/O.

Architecture authority:

- `F-TB01@1d039292d5768496c4550a8e1b35a92c6f836504`
- tree `217ad406db38b564a8b03e6c34c26b9123b58c6c`

Current canonical context observed at activation:

- `integration/f-ci-canonical@0aeb0a2ed4096e1f9493d3dabc70962ea5270182`
- tree `c77ac75aea522ac20a60da012595af9166efcff6`
- commit closes F-CI42P post-promotion governance reconciliation.

The current canonical context is not silently substituted for historical case authority. Every catalog entry remains bound to its own exact source, matrix, evidence and governance authority.

## Initial fragment

The first fragment deliberately stays narrow. It registers five semantically distinct hydraulic verification records:

1. TB-L0 analytical Kelvin-sign ratio oracle used by the SWAP-009 PDI vapor-conductivity gate;
2. TB-L1 actual PDI vapor-conductivity execution path versus that analytical oracle;
3. TB-L1 exact non-target invariance for water retention and vapor-disabled conductivity in SWAP-009;
4. TB-L1 SWAP-011 `dK/dh` derivative-consistency evidence as **characterization only**, because the exact final E7 patch provenance was not formally admitted in the pinned authority;
5. TB-L3 current-canonical B1.10 nonlinear/constitutive-provider source surface as **characterization only** until a dedicated current-source scientific requalification binds it.

No case in this fragment is promoted to moving-current preservation merely because its path exists on a later canonical tree.

## Historical SWAP-009 boundary

The pinned SWAP-009 qualification records B1.6 admission. Its direct function-level gate executes hydraulic model 8 at `h=-1e5,-1e6,-1e7 cm`, `T=20 °C`, isolates `Kvap = K_with_vapor - K_without_vapor`, and compares the old/corrected ratio with the independent Kelvin sign ratio. The historical gate tolerance is `1e-9` relative ratio error. It also requires exact zero old/corrected change in `WC(h)` and vapor-disabled `K(h)`.

F-TB02 preserves this as historical source-bound evidence. It does not reinterpret it as a general PDI golden output, as a complete hydraulic-model bank, or as evidence for current SWAP5 production behavior.

## SWAP-011 boundary

The pinned SWAP-011 dossier reports strong E5/E6/E7 evidence for correcting `dK/dh`, including focus on hydraulic models 3, 7, 10 and 12. But its own B1 status is `CANDIDATE, NOT YET ADMITTED` because exact final E7 patch provenance was still missing. F-TB02 therefore records this evidence only at `CHARACTERIZATION` maturity. It is forbidden to use this record as an O5 admitted legacy oracle or as current-preservation authority.

## Explicit remaining TB-L0/L1 gaps

This fragment is not a complete constitutive bank. Still required as dedicated future case packages are at least:

- all supported hydraulic families and parameter domains;
- `theta(h)` exact/property coverage;
- `C(h)` versus independently differentiated `dtheta/dh` with discontinuities explicitly classified;
- `K(h)` limiting, monotonicity and finite-value properties;
- `dK/dh` exact/independent-reference coverage for every supported model, including branch/discontinuity policies;
- inverse `prhead` identities where an inverse exists;
- dry and saturation limits;
- parameter-boundary/adversarial cases;
- explicit current-canonical requalification before any historical hydraulic case becomes moving-current preservation;
- Full Richards integration qualification remains TB-L3 and higher, separate from constitutive correctness.

## Mass and architecture

Pure constitutive cases are `NOT_WATER_BEARING`; they cannot waive mass conservation in solver/integrated cases. Any later water-bearing extension must retain the hard F-TB01 mass contract. The fragment is also consistent with the common soil-water interface: constitutive verification does not couple other modules to HeadCalc internals and does not privilege one future alternative solver implementation.
