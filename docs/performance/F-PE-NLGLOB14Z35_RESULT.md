# F-PE-NLGLOB14Z35 result — production-shaped manager physical binding smoke

Date: 2026-09-30

Status:

`QUALIFIED_Z35_MANAGER_PHYSICAL_BINDING_SMOKE`

Qualification authority:

- workflow run: `36769821439`;
- job: `110073065167`;
- workflow conclusion: SUCCESS.

Canonical authority:

`integration/f-ci-canonical@ddd218085afd363d22ce0b632d3ac893c7c9f40b`

Research postimage before result persistence:

`research/f-pe-nlglob14z35-manager-physical-binding-smoke@e984718f13a4ded24b5734b8432a810e2ad59fa0`

## Aggregate result

The focused production-shaped physical-binding smoke classifies:

`QUALIFIED_Z35_MANAGER_PHYSICAL_BINDING_SMOKE`.

## Physical candidate comparison

The smoke uses a 16-node O05-inspired hydrostatic profile with a contiguous saturated lower tail `13:16`, qbot = 0 and one short dry surface-flux interval.

The full reference solve uses 16 nonlinear unknowns.

The reduced solve retains node 13 as the active guard and reconstructs nodes 14:16, giving active dimension 13.

Observed physical comparison:

- max pressure-head difference: `0.0 cm`;
- max theta difference: `0.0`;
- top-flux difference: `0.0 cm/d`;
- nominal ledger difference: `0.0 cm`;
- full nonlinear residual: about `2.0722e-13`;
- reduced nonlinear residual: about `2.0722e-13`.

The frozen physical comparison gates therefore pass exactly.

The deterministic dimension/work ratio for the smoke is:

`13 / 16 = 0.8125`.

## Manager integration

The physically computed reduced candidate is passed through the Z34 Fortran manager seam.

The executable confirms:

- full accepted state remains 16-node;
- active reduced workspace is 13-node;
- reduced physical candidate is rematerialized to a full 16-node candidate;
- eligible reduced route is selected;
- selected reduced candidate remains full-shaped;
- forced reduced failure selects exact full fallback;
- explicit fallback reason is preserved;
- ineligible/full-dimension view selects explicit bypass;
- failed reduced route does not mutate accepted h/theta.

Observed manager result:

`{"full_nodes":16,"active_nodes":13,"reduced_route":true,"fallback_route":true,"bypass_route":true,"rollback_no_leak":true}`.

## Interpretation

Z35 is the first focused executable proof that the already-qualified reduced moving-interface physics can be carried through the production-shaped manager seam without changing physical-state ownership or transaction semantics.

This closes the gap between:

- research-only reduced physics;
- the Z34 typed manager seam;
- a full-shaped candidate suitable for existing transaction/commit authority.

## Qualified claim boundary

Qualified:

- one real eligible reduced physical candidate through the manager seam;
- exact full-shaped candidate materialization;
- physical agreement with full reference for the frozen smoke;
- reduced active dimension;
- explicit fallback and bypass;
- rollback/no-leak behavior;
- typed route diagnostics.

Not yet qualified:

- broader profile/process coverage;
- application-scale error envelope;
- end-to-end wall-clock speedup;
- production default change;
- production admission.

## Consequence

The next workunit should stop doing architecture/smoke work and move to a **small holdout + timing qualification**.

That successor should freeze a compact but heterogeneous set of representative profiles/process states before results and measure:

1. physical output differences;
2. fallback incidence;
3. active-dimension occupancy;
4. deterministic solver work;
5. production-shaped wall-clock timing.

The set should remain intentionally small before any BOFEK-wide campaign.

## Production boundary

Research prototype only.

`LEGACY_NUMERICS` remains production default.
