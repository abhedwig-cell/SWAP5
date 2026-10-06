# MC-LOW01 / SW431-GW-PROJECTION status

WORKSTREAM: SWAP 4.3.1/B1.11 coverage closeout
WORK UNIT: MC-LOW01 / SW431-GW-PROJECTION
BASELINE: work/swap431-master-coverage-20261006 @ 9194901849493db038e6aaf217469ff2c00e4ea6
RECOVERY POINT: work/swap431-gw-projection-20261006 @ 66c012c4960ea12acafdf7623f0f3c284731fe9f
PR: #1085
STATUS: persisted implementation; qualification in progress; not canonically admitted

## Scope

Add a value-only B1.11 CALCGWL-equivalent profile-to-groundwater-level projection without widening the admitted smooth directional projection service or opening legacy bottom mode 1.

## Ownership and invariants

The new projection is an explicit physical-parameter opt-in. It executes only after SW_SOLVE_CONVERGED, writes only tentative solve_result candidate groundwater level, and becomes authoritative only through the existing transaction commit. Rejected trials therefore cannot mutate committed GWL. Existing drainage_qbot_smooth_freatic_projection remains the higher-priority owner when active.

The work preserves architecture invariants 7, 12 and 20. It does not change external groundwater-head ownership, bottom-boundary selector admission, mass accounting, retry policy, or restart format.

## Evidence

Qualified on persisted postimage 45fd78a4dc8c72828a0525bfaeb000970a8071dc: component O0/O2 PASS; runtime dependency-closure compile PASS; existing LOWGWL public mode-1 fail-closed PASS and raw typed geometry blocker reproduced.

The first transaction-oracle attempt on 238a7fb1696649a06449e94a89987c86465462ef did not reach compilation because the new runner replayed a stale historical FMR44R source patch. That harness defect is corrected at recovery point 66c012c; qualification for that postimage is pending.

## Claim ceiling

No canonical admission yet. No claim that bottom mode 1 is migrated. No claim that the historical below-profile 999 sentinel is a physical SWAP5 value. No claim that the smooth directional projection is replaced. No broad groundwater-coupling or MODFLOW semantics are changed.

## Next safe step

Inspect the SWAP431 GW projection qualification run on recovery point 66c012c. If the transaction oracle passes at O0/O2, reconcile affected preservation gates and only then consider admission/reclassification of SW431-GW-PROJECTION.
