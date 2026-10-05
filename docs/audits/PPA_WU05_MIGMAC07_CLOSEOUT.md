# PPA-WU05-MIGMAC07 within-compartment rapid-drain closeout

Date: 2026-10-05. Status: LOCAL_QUALIFICATION_COMPLETE_PENDING_CANONICAL_ADMISSION.
Canonical base: 8125ba01b5bfd7377c721caa1105d68e24e77183.

The A10 compartment-boundary restriction is replaced with source-faithful
within-compartment capacity reconstruction. The unchanged B1.11 VOLUNDR already
subtracts the fraction above the level from the intersected compartment. It
assumes uniform macropore volume density in that compartment; SWAP5 now exposes
the same assumption explicitly as overlap fraction times current cell capacity.

The shared process helper is used by configuration validation and the actual
standard-rate adapter. Current geometry, active-domain cutoff and main-domain
partition remain the inputs. Levels outside the full column, noncontiguous grids,
invalid dimensions, negative capacities and nonfinite inputs fail closed.
A drain below the current active domain has zero below-drain capacity. Existing
1e-10 cm boundary snapping and full-cell sum order are preserved. One rapid-drain
receipt remains the external water owner; no subcell state or restart field exists.

Independent heterogeneous-grid values and the exact unchanged source function
agree at O0/O2. On a 10/20/30 cm grid with capacities 0.1/0.4/0.9 cm, a drain at
-35 cm leaves 0.75 cm below the drain; 1.4 cm storage permits at most 0.65 cm
outflow. The distribution closes to the single external receipt. Boundary values,
active cutoff, A/B/A and invalid-input cases also have executable tests.

Source authority: reconstructed B1.11 macrorate.f90 SHA256
537a84861fb256be67298064177b3e578305c1d036fe7376471d5bd3f7d4dcc7.
`tools/verification/migmac07_volundr_oracle.py` verifies the hash and assembles the
entire unchanged VOLUNDR function with fixed independent grid/volume inputs.
This is source compartment-model parity, not continuous-field exactness.

An initial infrastructure failure is retained: source-oracle compilation wrote
MOD_grid/MOD_arrays module files in the repository root, shadowing the actual test
stub modules and causing immediate A8/shared runtime compilation failure. Oracle
compilation now uses its own temporary working directory and module destination;
only its two generated root outputs were removed. No production tolerance or
physics repair was made for this failure. All seven controlling final gates exit zero against the isolated postimage.
Actual partial-level A10 reject/replay/restart and mixed-law Reference wetting,
two-domain rapid drainage, supplied/derived KD identity, smaller retry, A/B/A
and accepted restart pass at O0/O2. Original shared MIGMAC02/03/04/05/06 runtime
cases, A8/A10 and covering/perched preservation also pass. Independent pure
constitutive/fit/KD evidence is inherited only for its unchanged dependencies.

Scope is one explicit drain level in serialized Reference Richards. Multiple
levels, new surface owners, covering-layer reference preparation and whole-model
equivalence remain outside the admission. Frozen Status A remains unchanged and
broad migration is incomplete. Qualification authority:
`integration/audits/PPA_WU05_MIGMAC07_QUALIFICATION.json`.

## Source denominator correction

The reconstructed macropore initialization explicitly loops `do ir = 1, 1`
with its comment "Currently only one level". macrorate calls RAPIDDRAIN from
its domain loop; RAPIDDRAIN returns immediately for every domain except `id == 1`
and selects the one drain type via `NumLevRapDra`.
Therefore simultaneous multiple rapid-drain levels are future functionality,
not an implemented 4.3.1/B1.11 rapid-drain capability missing from SWAP5.
Earlier open-scope lists must not count this as a source migration blocker.
This correction does not concern ordinary multilevel matrix drainage, which has
a separate process and ownership contract.
