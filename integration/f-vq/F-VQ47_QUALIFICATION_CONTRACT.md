# F-VQ47 qualification contract

F-VQ47 independently requalifies exactly one production blob:

- owner closeout: `70a66a768e64760ecfd43702535a848b6d834d61`
- production path: `src/process/mod_drainage_spatial_distribution.f90`
- required Git blob: `1f538174b7451aaa7a3c50d6078b7c1fc3ad8f5a`

The qualification branch starts from canonical `42b11df9b863afe9bfe2c24a6556293c04bbe555`. Candidate source is extracted only from the pinned owner closeout. F-VQ47 may not change `src/`, `reference/`, runtime, solver or kernel production code.

## Scientific oracle independence

The oracle in `fvq47/legacy_divdra_oracle.py` is reconstructed directly from frozen SWAP 4.3.1 `SWAP/divdra.f90`. Authoring tests or expected vectors from F-PM08B/F-PM08BR are prohibited as oracle input. F-VQ45 is used only as blocking-review provenance and is not assumed scientifically correct.

The frozen `Lev2Comp` comparison `lev > -zbotcp(icplev)+1.d-10` is reproduced literally. The offset is neither smoothed nor exposed as a tolerance setting. Actual profile-bottom rejection is tested separately as a deliberate modern fail-closed boundary.

## Predeclared verification matrix

Before candidate execution the verifier fixes seed `470043` and the following stable-domain quotas: 800 dmax-truncated multi-compartment cases, 400 full-profile multi-compartment cases and 600 single-compartment cases. Four additional deterministic physics probes target anisotropy, partial saturation, transmissivity weighting and the smallest binary64 positive value above the legacy active threshold.

Boundary testing uses four independent internal compartment bottoms, each at offsets 0, 0.5e-10, 1.0e-10 and 2.0e-10 cm below the boundary. Two profile-bottom fail-closed probes and two restricted positive-transfer threshold probes are separate from the equivalence domain.

O0 and O2 builds must produce identical parsed numeric and structural results.

## Floating-point and mass exit rule

Integer/status/compartment selections must agree exactly. Floating results are accepted only inside a fixed IEEE-754 binary64 forward-roundoff envelope `gamma(k)=k*u/(1-k*u)`, with `u=2^-53` and operation counts fixed in the verifier before execution. There is no configurable scientific or mass-balance tolerance.

The raw legacy-equivalent partition sum is characterized separately. The candidate scalar transfer is authoritative and the modern final-node correction may close only binary64 roundoff. Any unexplained scientific mismatch, non-roundoff mass defect, scope drift, candidate-blob mismatch, O0/O2 mismatch, or production/reference delta fails closed.

## Decision

Only a completely green independent gate permits:

`QUALIFIED_REMEDIATED_RESTRICTED_DIVDRA_SPATIAL_DISTRIBUTION_AND_LEV2COMP_BOUNDARY_SEAM_EQUIVALENCE`

This workunit does not admit the candidate into runtime or canonical integration.
