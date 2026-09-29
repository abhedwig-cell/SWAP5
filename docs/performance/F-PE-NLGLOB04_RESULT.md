# F-PE-NLGLOB04 result — residual-term cancellation and attainable local precision

Date: 2026-09-29

Status:

`NLGLOB04_LOCAL_CANCELLATION_SIGNAL`

Canonical base:

`integration/f-ci-canonical@a409df7572018969f0e73a05696c402edd2363c2`

Qualification authority:

- workflow run: `36539623219`;
- job: `109311749480`;
- conclusion: SUCCESS.

## Coverage

PASS.

- audited failing Newton iterations: `768`;
- primary poor-model near-floor iterations: `333`;
- adequate-model iterations: `433`;
- active-node decomposition coverage: `1.0`;
- exact decomposition fraction: `1.0`;
- process failures: `0`.

The diagnostic term sum reproduces the assembled residual under the frozen decomposition gate for every emitted active-node record used by the analysis.

## Aggregate cancellation signal

At the dominant residual node:

- median primary cancellation ratio: `4.1778e11`;
- median adequate cancellation ratio: `3.3093e5`;
- primary / adequate median ratio: `1.2624e6`;
- primary records with the two largest terms opposite in sign: `1.0`;
- route-mode families with the same poor > adequate direction: `6/6`.

All frozen conditions for:

`NLGLOB04_LOCAL_CANCELLATION_SIGNAL`

pass by large margins.

## Storage-flux hypothesis

The more specific storage-versus-flux classification does not pass.

Primary dominant-node records whose largest opposing pair is storage versus interface/top flux:

`0.2162`

The frozen `NLGLOB04_STORAGE_FLUX_CANCELLATION_SIGNAL` gate required >=0.60.

Therefore the numerical floor is not principally a storage-rate versus hydraulic-flux subtraction phenomenon.

## Dominant term pairs

Largest opposing-pair counts in the 333 primary iterations:

- `U-L`: 256;
- `S-U`: 29;
- `U-S`: 24;
- `T-S`: 19;
- `T-L`: 5.

Thus approximately 77% of the primary subset is dominated by cancellation between the upper and lower interface-flux contributions.

This is the strongest mechanistic attribution in the NLGLOB chain so far.

## Route and mode structure

Every frozen route/mode family independently satisfies the local-cancellation signature.

Median primary cancellation ratios:

- FLUX / KLAG: about `3.34e11`;
- FLUX / TG: about `2.35e11`;
- HEAD / KLAG: about `3.79e11`;
- HEAD / TG: about `4.52e11`;
- RUNOFF / KLAG: about `1.14e12`;
- RUNOFF / TG: about `7.57e11`.

Poor/adequate median cancellation-ratio amplification ranges from about `9.90e5` to `9.84e6`.

This is therefore neither route-specific nor Thomas-Gladwell-specific.

## Relation to NLGLOB03

NLGLOB03 established a mixed late-iteration balance-floor structure and ruled out final total-vector summation.

NLGLOB04 localizes the dominant precision loss one level earlier:

the residual at the limiting node is commonly the tiny difference between much larger opposing interface-flux contributions.

The relevant cancellation is therefore created during local flux-divergence formation, before the final total-balance sum.

## Interpretation boundary

This result does not establish that the physical fluxes are inaccurate.

It establishes that their difference can be poorly resolved in ordinary binary64 arithmetic when two nearly equal interface flux contributions oppose each other late in Newton convergence.

No physical equation, mass term or convergence tolerance may be changed on the basis of this result alone.

## Consequence

Per preregistration:

- do not relax BALTOL02;
- do not introduce a floor-aware convergence acceptance rule yet;
- do not apply a generic state-scaling or trust-region repair;
- do not target storage arithmetic as the primary repair;
- open a separately preregistered experiment on the `U-L` flux-divergence formation itself.

Direct successor:

`F-PE-NLGLOB05 — cancellation-resistant local flux-divergence evaluation`.

The first phase must compare algebraically equivalent evaluation strategies and/or higher-precision diagnostic oracles at the interface-flux difference site while leaving each physical interface flux, boundary condition and accepted-state mass contract unchanged.

A candidate may advance only if it reduces the attainable local residual floor without changing physical flux values beyond numerical roundoff authority.

## Production boundary

Research diagnostics only.

No production `src/**` change.

No tolerance, mass, timestep, K-staging or route/event change.

`LEGACY_NUMERICS` remains production default.
