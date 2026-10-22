# Native SWP water bootstrap: admission review

The opt-in solute column previously required a second, manually reconstructed
water grid and hydraulic/initial-state input alongside original SWP chemistry.
The new explicit option reads the SWP grid, layered default MvG parameters and
unsaturated HTB initial pressure heads through original TTUTIL and AFGEN_2.
It feeds the existing production water/solute owner without changing src,
solver policy, mass accounting or restart formats.

Validation: checked GNU13.3 O0/O2;12 native mapping cases,12 exact fresh-process
restarts,60 invalid-input rejections,172 original chemistry observations and86
original application observations. Independent initial inventories and whole
balances pass.152 completed baseline artifacts remain byte-exact. Twenty-one
source/evidence corruption controls reject; source and strict documentation pass.
Initial link/scalar-input failures are retained in the immutable evidence.

PR1362 and PR1363 are canonically integrated at14fbefde, exact qualified
tree7ab180aa. All18 feature and17 repair PR workflows succeed; actual merge
source/evidence and original FSI35 O0/O2 replay pass. No master-row promotion
is claimed. Historical meteorology, crop/default
orchestration, saturated initialization and the other explicit exclusions remain
open. The original predecessor admission guards retain their assertions through the
exact registered source successor.

Baseline:48a59396d7e7745cf99ad4b1003cd84c946e3e3f.
Branch:work/mc-sol01-swp-water-20261021.
Owner:integration/audits/MC_SOL01_DYNAMIC_DECAY_STATUS.json#swp_water_successor.
Contract:docs/science/MC_SOL01_SWP_WATER_CONTRACT.md.
Evidence verifier:python -B integration/audits/verify_swp_water.py --self-test.

The user authorized GitHub publication and PR/integration on continuation.
Current canonical95a3bd57 is reconciled without changing its NUT output sources.
All190 current executed application inputs retain their qualified bytes;18 current
annual runs pass. Original NUT ownership and14 controls pass on the exact frozen
predecessor. Existing research CLI/control defects remain recorded separately.
