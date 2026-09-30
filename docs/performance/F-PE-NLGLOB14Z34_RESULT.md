# F-PE-NLGLOB14Z34 result — production-shaped moving-interface manager prototype seam

Date: 2026-09-30

Status:

`QUALIFIED_Z34_MANAGER_SEAM_READY`

Qualification authority:

- workflow run: `36768767332`;
- seam-smoke job: `110069502514`;
- workflow conclusion: SUCCESS.

Canonical authority:

`integration/f-ci-canonical@ddd218085afd363d22ce0b632d3ac893c7c9f40b`

Research postimage before result persistence:

`research/f-pe-nlglob14z34-manager-prototype-seam@a5b7cd83ea2bcb43fd76521c03d6512fee2067f4`

## Aggregate result

The production-shaped prototype seam classifies:

`QUALIFIED_Z34_MANAGER_SEAM_READY`.

The existing typed solver and transaction architecture can support the adaptive manager without creating a second physical-state owner or a parallel solver stack.

## Architecture answers

### Q1 — typed seam

PASS.

The existing solver contract already separates:

- parameter set;
- base physical state;
- candidate result;
- workspace;
- diagnostics.

A thin manager can derive a reduced request from the full accepted state while leaving the accepted-state object full-column and immutable.

### Q2 — variable workspace

PASS.

The smoke uses the production `reference_richards_workspace_t` with:

- full node count: 16;
- reduced active node count: 13;
- reduced workspace generation: 1.

No fixed-16 fallback occurs inside the reduced workspace path.

### Q3 — manager object

A thin orchestrator is sufficient.

The new `mod_moving_interface_manager` owns only:

- active-view metadata;
- reduced-request construction;
- full-candidate materialization;
- explicit reduced/full-fallback result selection;
- typed manager diagnostics.

It does not own committed h/theta state.

### Q4 — diagnostics

PASS.

The manager diagnostics expose:

- full node count;
- active node count;
- tail start;
- interface face;
- reduced workspace generation;
- reduced attempted/accepted flags;
- fallback used flag;
- explicit fallback reason;
- selected route.

These are numerical/operational diagnostics, not physical state.

### Q5 — smoke

PASS.

The focused smoke proves:

- full accepted state remains 16-node;
- reduced request and workspace use 13 nodes;
- a reduced candidate is materialized back to a full 16-node candidate;
- selected reduced route returns a full-shaped candidate;
- forced reduced failure selects exact full fallback;
- fallback reason is explicit;
- failed reduced route does not modify the accepted origin;
- ineligible full-dimension view bypasses the reduced route explicitly.

Observed smoke result:

`{"full_nodes":16,"active_nodes":13,"workspace_generation":1,"reduced_route":true,"fallback_route":true,"bypass_route":true,"rollback_no_leak":true}`.

## Production-default boundary

No production numerical default is changed.

`LEGACY_NUMERICS` remains the production default.

The manager seam is research/non-default only.

## Scientific / architectural interpretation

Z34 removes an important implementation uncertainty.

The qualified moving-interface semantics do not require:

- a new transaction system;
- a second committed state;
- a new linear solver;
- a parallel reference-solver stack.

The existing architecture can host the manager as a thin orchestration layer around the typed solver request/result/workspace contracts.

The key seam is explicit:

1. full accepted state is authority;
2. derive reduced view/request;
3. solve in reduced workspace;
4. reconstruct a full candidate;
5. either select reduced candidate or exact full fallback;
6. commit remains outside the manager under existing transaction authority.

## Qualified claim boundary

Qualified:

- manager seam architecture;
- reduced request construction;
- reduced workspace dimension;
- full candidate materialization;
- explicit fallback;
- typed diagnostics;
- rollback/no-leak smoke;
- no production-default change.

Not yet qualified:

- production Fortran reduced Richards physics integrated behind this seam;
- broad process/profile coverage;
- application error envelope;
- end-to-end wall-clock speedup;
- production admission.

## Consequence

The next workunit should bind the already-qualified reduced moving-interface physics behind this seam on a small production-shaped executable fixture.

That successor should not reopen architecture design.

It should test the real manager route with:

- one eligible reduced case;
- one ineligible/bypass case;
- one forced fallback case;
- exact transaction/rollback behavior;
- active-dimension diagnostics;
- reference physical comparison;
- focused timing/work diagnostics.

Only after that focused executable integration passes should broader holdouts be opened.

## Production boundary

Research prototype only.

`LEGACY_NUMERICS` remains production default.
