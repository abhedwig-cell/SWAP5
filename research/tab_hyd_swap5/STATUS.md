# TAB-HYD SWAP5-native provider status

Date: 2026-09-20

## Scope

Research-only characterization of a table-backed constitutive provider against the current qualified SWAP5 B1.10 Mualem-van Genuchten provider. No production source is changed and no production admission is claimed.

Research branch: `research/tab-hyd-swap5-provider`.

Branch start authority: `integration/f-ci-canonical@b3dc66cd85bcebe2bfca4d46f9ee92cb06d3137d`.

Latest live canonical checked during this block: `1caa431002d5c128c73cfcfbd31af4cc39ee9f12`. The 41-commit live delta from the branch base contains no changes to `mod_soil_water_solver_contract`, `mod_b110_default_mvg_provider`, the hydraulic science documentation or the Reference Richards source relevant to this characterization.

## Why this branch exists

The older legacy/public-SWAP table audit showed that the table concept and the old input route must be separated from the current SWAP5 architecture:

- old legacy table interpolation can reproduce Hupsel very closely for `SWKIMPL=0`;
- old lookup mechanics are a measurable performance cost;
- current public typed SWAP accepts a table switch without supplying the required table state;
- current SWAP5 canonical admits only the analytical B1.10 provider in the ordinary `SWKIMPL=0` contract.

The present branch therefore asks a cleaner question:

> Can a table-backed provider satisfy the current SWAP5 constitutive-provider contract while preserving the qualified B1.10 constitutive semantics closely enough to be a credible acceleration candidate?

## Provider design under test

The research provider:

- implements the existing `constitutive_hydraulics_provider_t` interface;
- is generated from the current `b110_default_mvg_provider_t`, not from an independent reimplementation;
- uses O(1) arithmetic indexing in a transformed head coordinate;
- uses shape-preserving cubic Hermite interpolation for theta, log(K) and log(C);
- is explicitly bounded to the current ordinary `SWKIMPL=0` value-provider contract and returns zero in the reserved dK/dh output;
- preserves B1.10 branch surfaces instead of smoothing across them.

The branch-surface preservation is necessary. A first smooth-table prototype showed that interpolation error was dominated by the B1.10 numerical branch semantics near saturation, especially the C transition at `h=-0.01 cm` and the exact-Ksat guard. Those are properties of the qualified provider and must be preserved, not averaged away.

## Provider-level qualification

Successful workflow: `TAB-HYD SWAP5-native provider characterization`, run `35494174512`.

For the Hupsel-like Branch-A parameterization, using `h_scale=0.01 cm` and 1024 points over `[-1e7,0] cm`:

- max absolute theta error: `2.5023e-8`;
- max absolute log10(K) error: `3.6470e-5`;
- max absolute log10(C) error: `6.7296e-4`;
- exact Hcrit C-branch comparison: zero log10(C) error at the explicit branch probe;
- typed request validation: PASS.

At 512 points with the same transform:

- max absolute theta error: `2.0149e-7`;
- max absolute log10(K) error: `5.4112e-5`;
- max absolute log10(C) error: `2.6819e-3`.

The largest remaining K error is localized immediately below the exact-Ksat transition. The largest remaining C error is localized just below the Hcrit transition. These are now small residual interpolation errors rather than branch-smearing errors.

A Branch-B retention characterization is also included. Its current 512-point result is less accurate than Branch A and remains under characterization before any general provider-envelope claim is made.

## Reference Richards insertion test

Successful workflow: `TAB-HYD SWAP5 Reference Richards pair`, run `35494390817`.

The table provider and qualified MvG provider were inserted through the same current `constitutive_hydraulics_provider_t` seam into Reference Richards for all 15 hydraulic-state cases from the existing F-SI23 Gate-C2 matrix.

Results:

- all 15 MvG solves converged;
- all 15 table solves converged;
- maximum initial theta representation difference: `2.7217e-8`;
- maximum pressure-head endpoint difference: `2.2804e-6 cm`;
- maximum water-content endpoint difference: `3.0249e-8`;
- maximum top-flux difference: `0`;
- maximum bottom-flux difference: `3.2261e-7`;
- maximum nonlinear-iteration-count difference: `0`;
- both routes met the existing strict mass-residual gate in every case.

This is direct current-SWAP5 evidence that the table-backed representation can pass through the actual typed provider seam and Reference Richards solver without changing solver iteration behavior in this frozen 15-case matrix.

## Provider microbenchmark

Successful workflow: `TAB-HYD SWAP5-native provider microbenchmark`, run `35494237966`.

Repeated alternating O3 benchmark over 34-node, 512-state constitutive evaluations:

- analytical MvG median: `0.877570 s`;
- table provider median: `0.766870 s`;
- median table/MvG ratio: `0.874247`;
- table provider delta: `-12.58%`.

This is a constitutive-provider benchmark, not a whole-model speedup claim. It demonstrates that the SWAP5-native O(1) table representation can make the constitutive evaluation itself faster than the current analytical provider, unlike the older legacy lookup implementation.

## Current disposition

The evidence now supports the following bounded statements:

1. The existing legacy table concept is scientifically viable in the ordinary `SWKIMPL=0` envelope, but its old lookup implementation is not a good acceleration architecture.
2. The current SWAP5 typed production runtime does not presently expose an admitted table-backed provider.
3. A SWAP5-native table provider can satisfy the existing typed constitutive-provider contract.
4. Preserving B1.10 numerical branch semantics explicitly is necessary for high fidelity. Blind smooth interpolation is not sufficient.
5. In the current 15-case Reference Richards matrix, the 512-point candidate reproduces the analytical-provider solve to micro-centimetre-scale head differences with identical nonlinear iteration counts.
6. The native table provider is locally faster in the constitutive microbenchmark by about 12.6%.
7. No whole-model SWAP5 speedup has yet been established.
8. No claim is made for `SWKIMPL=1`, which is outside the current ordinary provider admission.
9. Branch-B and broader parameter/model coverage remain open before the candidate can be called generally valid.

## Next gates

The next useful gates are:

1. close Branch-B fidelity and identify whether its residual error is resolution-only or requires another explicit branch surface;
2. expand provider-level qualification across representative soil hydraulic parameter families;
3. run a current-SWAP5 application/runtime A/B benchmark with the same forcing and physics if and when the provider seam is reachable in that production slice;
4. only after those gates, decide whether a production admission proposal is warranted.

