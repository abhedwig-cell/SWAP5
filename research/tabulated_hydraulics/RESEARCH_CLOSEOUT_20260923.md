# TAB-HYD research closeout — generated K0 constitutive acceleration

Date: 2026-09-23

Status: **RESEARCH CLOSED FOR K0 REPRESENTATION / PRODUCTION HANDOFF READY**

Canonical authority at closeout:

`integration/f-ci-canonical@b7d9c976e9b474545d54fa79b71ae134c25da156`

Research branch:

`research/tabulated-hydraulics-characterization`

## 1. Original question

Can SWAP replace repeated analytical Mualem–Van Genuchten constitutive
evaluation by a tabulated representation that is scientifically faithful and
actually faster?

The answer now requires a branch/capability distinction.

## 2. Legacy table option

The historical table engine is numerically capable, but the old production
route is not an admission target as-is.

Established:

- smooth interior TSPACK interpolation is accurate;
- public table library contains one rejected non-monotone table
  (`starb4_cm.csv`);
- legacy scalar table lookup carries avoidable overhead;
- current public typed SWAP does not provide a complete operational table-data
  route; newer public development explicitly treats the old table option as
  dormant;
- table endpoint and analytical Ksat-clamp derivative inconsistencies were
  found in research and classified separately.

Therefore the workstream did **not** revive the historical `SWSOPHY=1`
implementation as production architecture.

## 3. Qualified generated representation

The successful research representation is an internally generated equivalent of
the already admitted default MvG constitutive relation:

- 400 pressure-head rows;
- physical/raw pressure head as interpolation coordinate;
- log(K) conductivity ordinate;
- TSPACK preprocessing;
- explicit wet theta/C continuation;
- explicit Ksat plateau;
- constant dry extension;
- bounds-safe interval location;
- immutable preprocessing outside the nonlinear hot loop.

This representation passed the bounded coarse/loam/clay K0 transfer envelope.

## 4. Why legacy K0 appeared runtime-neutral

Legacy scalar `watcon/moiscap/hconduc` call structure hides most of the
available sharing.

The decisive architecture result is the existing SWAP5 vector-valued typed
constitutive provider seam. Evaluating theta, C and K together exposes the table
representation's lower repeated-evaluation cost.

## 5. Controlling K0 acceleration evidence

### Provider-only

Post-reconciliation run `35538295603`:

- 30 Staring parameter rows;
- theta max abs difference about `5.32e-5`;
- C max abs difference about `5.17e-5`;
- log10(K) max abs difference about `3.04e-4`;
- analytical median `0.260065 s`;
- generated table median `0.2106475 s`;
- delta **-19.00%**.

### Reference Richards

Run `35538295593`:

- same nonlinear iteration counts route-by-route;
- same linear solve counts route-by-route;
- mass-residual differences around machine precision;
- bounded profile runtime reductions about **30-41%**.

These percentages characterize the compact solver fixture, not whole SWAP.

### Serialized Reference runtime

Run `35538295619`:

- fidelity failures = 0;
- equal retries and iterations;
- mass preservation;
- provider-consistent initialization;
- hot-loop reductions about **28-31%** in the equilibrium material fixtures.

### Dynamic transaction / temporal certificate

Current-canonical run `35818703618`:

- positive prescribed qbot accepted on analytical and generated-table routes;
- hard mass gate PASS;
- temporal certificate available on both routes;
- Binf absolute difference `3.17e-18 cm`;
- normalized Ch difference `1.27e-7`;
- total in/out identical;
- nearby unsupported bottom mode remains fail closed.

This closes the bounded non-equilibrium transaction/certificate gate.

## 6. Timestep-context contract

TAB-HYD-CTX01 run `35819421154` closes the remaining provider-contract issue.

Recommended production contract:

`context_compatible(step_duration) -> logical`

Properties:

- default implementation fails closed;
- analytical MvG override PASS;
- generated table override PASS;
- deliberate dt mismatch fails closed for both;
- temporal-indicator owner no longer needs concrete constitutive type dispatch;
- hot vector `evaluate(...)` ABI remains unchanged;
- analytical provider benchmark showed no material regression
  (observed `-0.442%`).

Option A, passing dt through every constitutive evaluation, is superseded for
this work unit because it changes the hot ABI without adding a demonstrated
benefit.

## 7. Initialization cost

Run `35538710173`:

- extra generated-provider setup about `5.30 ms` for 30 nodes;
- measured break-even about `8,860` 30-node vector evaluations;
- approximate immutable provider table state about 657 KiB for 30 nodes.

Production ownership must therefore generate/preprocess once per immutable
parameter authority and reuse across trials. Per-trial regeneration is
forbidden by the handoff contract.

## 8. K1 is separate

The corrected/bounded coarse K1 route showed meaningful table speed reductions,
but broader qualification cannot currently use the selected analytical reference
envelope.

The analytical `loam_mid_free` K1 reference failed to complete within 120 s;
a longer route matrix was abandoned during prolonged analytical execution.

Disposition:

**K1_REFERENCE_RUNTIME_BLOCKED / NOT_TABLE_FALSIFIED / NOT_PRODUCTION_SCOPE**

K1 is not a prerequisite for the generated K0 provider.

## 9. Whole-Hupsel final gate

The strongest whole-application authority already exists in canonical M1-C3:

- exact SWAP 4.3.1 distribution authority;
- whole Hupsel typed Task2 route;
- 32,518 accepted physical intervals;
- 34 additional retry attempts;
- exact active-route census;
- exact normalized BAL/BLC identity for the admitted analytical provider.

That is the correct final application gate for the generated provider.

Required distribution SHA-256:

`2b48353db6cdf00246a1e5c0dcaafc2c61858729fad18446a1dc66359ec2a360`.

A new Project/Library search on 2026-09-23 again found no authorized
materializable copy of the exact distribution bytes. Derived audit archives are
not substitutes.

Disposition:

**WHOLE_HUPSEL_FINAL_GATE_BLOCKED_EXTERNAL_EXACT_ASSET_BYTES_UNAVAILABLE**

No alternate public copy, synthetic fixture, reconstructed archive or parser is
authorized as replacement.

## 10. Production handoff

The bounded production handoff is defined in:

`GENERATED_K0_PROVIDER_PRODUCTION_HANDOFF.md`.

The first production capability must remain:

- generated MvG-equivalent provider only;
- K0 / `SWKIMPL=0`;
- typed provider selection;
- analytical MvG default/reference preserved;
- immutable provider/table state;
- generic context compatibility capability;
- fail closed outside the admitted parameter envelope.

Generic user-supplied tables and historical `SWSOPHY=1` compatibility are
separate future capabilities.

## 11. Final research disposition

### Supported

**The generated typed K0 table-provider acceleration hypothesis is supported.**

There is sufficient evidence that the representation is:

- constitutively faithful in the bounded envelope;
- solver-compatible;
- transaction-safe in the qualified fixtures;
- mass-consistent;
- temporal-certificate compatible;
- materially cheaper in the typed provider and Reference-Richards execution
  architecture.

### Not claimed

No global whole-SWAP speedup percentage is claimed.

No MultiSWAP speedup percentage is claimed.

No production K1 claim is made.

No generic table-input admission is made.

### Next legitimate state transition

The next implementation work belongs in a separately owned production work unit
from current canonical, under the preregistered handoff.

Production **admission** remains blocked until the exact whole-Hupsel authority
asset can be executed.
