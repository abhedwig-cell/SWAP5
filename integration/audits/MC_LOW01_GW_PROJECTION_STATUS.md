# MC-LOW01 / SW431-GW-PROJECTION status

WORKSTREAM: SWAP 4.3.1/B1.11 coverage closeout
WORK UNIT: MC-LOW01 / SW431-GW-PROJECTION
BASELINE: work/swap431-master-coverage-20261006 @ 9194901849493db038e6aaf217469ff2c00e4ea6
RECOVERY POINT: work/swap431-gw-projection-20261006 @ c3eb15b370c1e8cb6ccd5beae8af6dfffb3b398a
PR: #1085
STATUS: persisted implementation; qualified on workstream postimage; pending master-coverage admission

## Scope

Add a value-only B1.11 CALCGWL-equivalent profile-to-groundwater-level projection without widening the admitted smooth directional projection service or opening legacy bottom mode 1.

## Ownership and invariants

The new projection is an explicit physical-parameter opt-in. It executes only after SW_SOLVE_CONVERGED, writes only tentative solve_result candidate groundwater level, and becomes authoritative only through the existing transaction commit. Rejected trials therefore cannot mutate committed GWL. Existing drainage_qbot_smooth_freatic_projection remains the higher-priority owner when active.

The work preserves architecture invariants 7, 12 and 20. It does not change external groundwater-head ownership, bottom-boundary selector admission, mass accounting, retry policy, or restart format.

## Evidence

Qualified on persisted postimage 45fd78a4dc8c72828a0525bfaeb000970a8071dc: component O0/O2 PASS; runtime dependency-closure compile PASS; existing LOWGWL public mode-1 fail-closed PASS and raw typed geometry blocker reproduced.

The final bounded qualification on postimage c3eb15b370c1e8cb6ccd5beae8af6dfffb3b398a is GitHub Actions run 37578999251: literal component O0/O2 PASS; LOWGWL dependency/negative-feasibility O0/O2 PASS; transactional runtime commit O0/O2 PASS. The transaction oracle verifies that a valid below-profile typed absence is non-blocking and preserves the prior typed GWL without introducing the legacy 999 sentinel.

## Claim ceiling

No canonical admission yet. No claim that bottom mode 1 is migrated. No claim that the historical below-profile 999 sentinel is a physical SWAP5 value. No claim that the smooth directional projection is replaced. No broad groundwater-coupling or MODFLOW semantics are changed.

## Next safe step

Admit this qualified slice into the master-coverage branch, reclassify SW431-GW-PROJECTION from ACTIVE_MIGRATION, and continue MC-LOW01 with dependent SW431-LOW3-EXPLICIT. No additional GitHub Actions run is required for documentation-only ledger reconciliation if the qualified production dependency surface remains unchanged.
