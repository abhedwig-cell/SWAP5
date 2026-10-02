# TOP03 microrelief surface-contact decision

Date: 2026-10-02  
Status: SUPPORTED_BOUNDED_RESEARCH_DIRECTION__NO_PRODUCTION_ADMISSION  
Evidence run: GitHub Actions 36979646830  
Source postimage: `7759895c0976856af2933e95e76a24b3989db7ca`  
Canonical inspected: `641a8ba7fad5b67f0ebff7c78dd065270ed46329`

## Question

Does replacing the perfectly flat, full-area external-head contact by a physically interpretable subgrid microrelief/contact law improve the actual TOP03 inundation refinement behavior without changing the soil, lower boundary or solver law?

The tested model uses a uniform unresolved surface elevation over `[0,D]`. At external stage `H=0.02 cm`, the wet fraction is `min(1,H/D)`. The wet-area Darcy contact is area-averaged through `K_contact = f_wet K_face`; local surface storage follows the same microrelief geometry. `D=0` is the exact current flat-surface limit.

No production source or transaction policy was changed.

## Controls

The `D=0` research provider reproduces the existing external-head provider exactly within the control tolerance for all tested windows/refinements, including completion/failure status and nonlinear iteration count.

O0 and O2 numerical outputs are exactly identical.

All complete paths retain the hard soil-mass, surface-closure and whole-control-volume ledger gates. The largest absolute complete-path ledger residual is approximately `1.31e-13 cm`.

## Result

### Flat and effectively full-area contact

`D=0` retains the known failure pattern.

`D=0.02 cm` changes the wet-area mean head from 0.02 to 0.01 cm and local surface storage from 0.02 to 0.01 cm, but because `H/D=1`, the wet fraction remains 1.0. It also retains the same qualitative failure pattern: only 10 of 20 tested paths complete.

This is important mechanism evidence. Merely lowering the representative surface head/storage does not resolve the problem while the entire surface remains in hydraulic contact.

### Partial hydraulic contact

For the three amplitudes with partial contact:

| D (cm) | wet fraction at H=0.02 | local surface storage (cm) | complete paths |
| ---: | ---: | ---: | ---: |
| 0.05 | 0.40 | 0.0040 | 20 / 20 |
| 0.10 | 0.20 | 0.0020 | 20 / 20 |
| 0.25 | 0.08 | 0.0008 | 20 / 20 |

All four windows, 0.25, 0.125, 0.0625 and 0.03125 day, complete at 1, 2, 4, 8 and 16 substeps for each of these amplitudes.

Each amplitude also satisfies the preregistered contraction criterion for every tested window: there exists a sequence of adjacent refinement pairs over which the pressure/water-state discrepancy, integrated top-transfer discrepancy and integrated bottom-transfer discrepancy all decrease together.

Examples:

- `D=0.05 cm, 0.25 d`: from 2-vs-4 to 4-vs-8, head error drops from 9.156 to 0.0505 cm, top-transfer difference from 0.2387 to 0.1424 cm, and bottom-transfer difference from 0.2309 to 0.1425 cm.
- `D=0.10 cm, 0.25 d`: the same sequence gives 8.886 to 0.1056 cm head error, 0.1847 to 0.1071 cm top difference, and 0.1759 to 0.1071 cm bottom difference.
- `D=0.25 cm, 0.25 d`: 8.797 to 0.3725 cm, 0.1181 to 0.06587 cm, and 0.1064 to 0.06534 cm respectively.

The finest tested 8-vs-16 differences continue to decrease for these cases, although the absolute throughput differences remain too large in some windows to declare a production accuracy budget.

## Interpretation

The microrelief hypothesis is supported as a research direction.

The evidence specifically supports **partial areal hydraulic contact** as the relevant mechanism. It does not support the weaker claim that simply reducing the external surface head or local ponding storage is enough.

This makes the previous TOP03 temporal blocker materially different. The old flat-surface fixture did not provide a trustworthy refinement oracle. Under physically smoothed partial contact, the same soil/lower-boundary problem does provide complete, contracting refinement sequences.

That is enough to reopen the possibility of an evidence-backed finite temporal acceptance contract, but only after the surface geometry itself is defined and qualified.

## What is not established

This experiment does not establish:

- that a uniform microrelief distribution is the correct field-scale geometry;
- that `D=0.05`, `0.10` or `0.25 cm` should be production defaults;
- that the tested stage `H=0.02 cm` covers higher-stage or fully inundated operation;
- that a specific temporal tolerance is now qualified;
- that Ribasim/SWAP surface-storage ownership is fully resolved;
- production admission or canonical merge.

The tested amplitudes are mechanism probes, not calibrated roughness parameters.

## Decision

Retain the microrelief/partial-contact formulation as the preferred TOP03 prerequisite direction.

Do not productionize a fixed D from this sweep. The next bounded step is to turn surface geometry into an explicit parameterized contract, then test stage evolution through partial to full wetting and derive a temporal budget from complete refinement evidence across that envelope.

PR #956 remains draft.

Machine-readable evidence: `integration/sw-rib-top03/TOP03_MICRORELIEF_SURFACE_RESULT.json`.
