# SWAP5–MODFLOW6 fixed-interface groundwater coupling closeout

Status: **canonical admitted and closed for the bounded profile described here**. The qualified candidate `0244570849e799d35a88abed36dc655e029d7c36` entered canonical historically through merge commit `148bca0dbe65d75a64694e5d481b2073419df009`; PR #582 is retained only as historical merge provenance and is not admission authority. The final admission commit is `b70173f315ab1b174001aeb7e67e56edfef95b0d` with canonical parent `79e84c1d2378c86b1d4e0e79b818cce9ffdf1d6e`. That exact admitted postimage passed the unchanged composed closeout gate in workflow run `35819763656`, job `107048912789`. Final admission provenance is recorded in `integration/f-gc/F-GC_FIXED_INTERFACE_CANONICAL_ADMISSION.json`.

## Scope

This note closes the fixed-interface groundwater-coupling research line into one bounded production architecture. It does not widen the admitted physics. The exchanged hydraulic state is the hydraulic head at the fixed lower coupling plane of the SWAP profile. It is not, by definition, the SWAP phreatic groundwater elevation.

The production profile covered here is one or more SWAP columns coupled to MODFLOW6 cells through the existing application-plan and prepared-solve API route, with active SWAP drainage response and root extraction excluded by the production bootstrap.

## Authoritative interface contract

Let H_c be hydraulic head at the fixed coupling plane.

The public SWAP interface flux q_swap is positive when water leaves SWAP through its bottom interface. Native SWAP q_bot is positive into the SWAP soil profile, therefore q_swap = -q_bot after unit conversion.

The MODFLOW API source inserted by this coupling is positive into the groundwater cell. Call that q_src. The accepted physical transfer requires q_src = q_swap. In the generic outward-from-groundwater convention this same transfer is q_gw,out = -q_swap.

The production external residual is R(H_c) = q_swap(H_c) - q_src(H_c). Acceptance requires the configured cellwise residual gate, not equality of internal Newton or MODFLOW trajectories.

## Response contract

The historical predictor response carries u, q_u and u/dt. Research PB01 established that the exact outward physical response tangent has the opposite orientation from the historical native-qbot partial slope. The analytical/live-MODFLOW discriminator showed that treating the positive historical slope as the physical outward tangent can be unstable.

Production now separates the two roles:

1. The predictor response may provide the first numerical affine term for a window.
2. Every accepted real-SWAP corrector requests the accepted-trajectory derivative with respect to prescribed bottom-interface head.
3. The participant converts that derivative to the public outward convention.
4. After a nonconverged corrector, the MODFLOW affine term is relinearized with the measured corrector value and the physical corrector tangent.
5. The old reanchor helper remains a distinct historical operation; it is not silently redefined.

For a corrector point (H*, q*) with physical slope dq*/dH:

HCOF = A * 86400 * dq*/dH

RHS = HCOF * H* - A * 86400 * q*

so the API term evaluates to A * 86400 * q* at H*.

Neither u nor u/dt is water storage.

## State, memory and transaction ownership

SWAP committed physical state is authoritative only after SWAP commit. Corrector trials are derived from a captured committed origin and do not mutate committed state.

A production application plan now retains the expected SWAP origin revision for every tile. Application-context binding and origin capture fail closed if the current committed SWAP revision differs. A response therefore cannot be reused across the wrong committed SWAP origin.

Within one prepared MODFLOW solve, accepted MODFLOW XOLD remains fixed. Rejected/probe SWAP trials and abandoned prepublication preparations have zero accepted-state and zero interface-mass authority.

Publication order is:

1. all SWAP, ledger and MODFLOW preflights;
2. finalize the MODFLOW timestep exactly once;
3. commit SWAP exactly once;
4. commit the interface ledger exactly once.

A failure after the irreversible MODFLOW publication point is a hard publication invariant failure, not a rollback retry.

## Storage role

For this admitted production profile, native MODFLOW STO has the explicit application role HEAD_STATE_CAPACITANCE.

It is numerical/state memory for the groundwater head equation in this coupling application. It is not admitted here as a second independent physical water reservoir to be added to SWAP storage.

Consequences:

- SWAP physical storage remains SWAP-owned.
- MODFLOW STO is not added to SWAP storage in a combined physical water balance for this profile.
- u and u/dt remain response quantities, not stored water.
- PHYSICAL_INDEPENDENT_STORAGE and MIXED_EFFECTIVE_STORAGE remain outside this admission and require separate domain authority.

This disposition uses the existing CSR04/MAP11 evidence without repeating the Sy × window matrix. CSR04 Phase B executed all 36 preregistered real-FMR/live-MODFLOW windows. It showed a coherent low-Sy limiting trajectory and separated native MODFLOW head memory from accepted SWAP column memory. Its bounded conclusion supports `HEAD_STATE_CAPACITANCE` when no independently evidenced regional storage volume is declared; it does not authorize treating native STO as an additional physical reservoir.

This role classification does not calibrate or universally admit a particular native `Sy` or `Ss` value. CSR04 showed that finite native STO changes the accepted head/exchange trajectory. A real application must therefore provide independent configuration authority for the chosen head-state capacitance magnitude, or use a separately qualified limiting formulation. The closeout fixture value qualifies coupling mechanics, not field-scale groundwater-storage calibration.

The machine-readable authority is `integration/f-gc/F-GC_FIXED_INTERFACE_COUPLING_CONTRACT.json`.

## Drainage ownership

The admitted fixed-interface production profile declares GW_DRAINAGE_OWNER_NONE.

No physical drainage route is represented inside this profile. Active SWAP drainage response is already rejected by the production bootstrap. A topology that declares unresolved drainage ownership or a SWAP/MODFLOW/surface-water drainage owner is not admitted by this closeout profile.

The interface ledger is accounting only. It is never a physical drainage owner.

Future admission of drainage must assign each physical route to exactly one of SWAP, MODFLOW or the surface-water model and demonstrate that the same route is not represented elsewhere. The separate ownership contract is `docs/integration/SWAP5_MODFLOW6_FIXED_INTERFACE_DRAINAGE_OWNERSHIP.md`.

## Endpoint and numerical qualification

G21 exact internal-path equivalence is permanently falsified and is not an acceptance criterion.

G23 tested the previously qualified analytical envelope by external physical endpoint and transaction criteria. Nineteen of 21 preregistered arms passed the frozen flux-residual gate and transaction handoff. The two failures ended extremely close to the independent reference heads but stalled at the residual floor. G24 then tested the tolerance hypothesis without changing the frozen G23 result.

The production repair does not attempt to recreate the old internal trajectory. It removes the proven response-semantics mixing by carrying the real-SWAP physical tangent into response relinearization.

Canonical postimage closeout evidence includes:

The composed closeout qualification on 2026-09-22 reported an independent endpoint head error of `3.30e-14 m`, an independent physical residual of `-7.08e-16 m/s`, a production external residual of `-6.09e-23 m/s`, and a native MODFLOW component-balance residual of `-3.65e-14 m3/day`. The accepted interface transfer was `-1.0206812345e-12 m`. The full real end-to-end fixture replayed identically in a fresh process, and the F-GC24 split-process restart signature remained identical at `-O0` and `-O2`.

- real FMR correctors with an explicit negative outward response tangent;
- live MODFLOW6 6.8.0 prepared-solve coupling;
- the closeout variant of F-GC44 uses exactly one real SWAP column and one MODFLOW cell, and demonstrates accepted endpoint residual closure, physical corrector-tangent relinearization, native MODFLOW model-budget closure, rejected-trial zero authority, interface identity and exactly-once publication;
- that same one-column/one-cell fixture derives an independent groundwater q(H) relation from fresh constant-flux MODFLOW6 solves and combines it with real-SWAP accepted-origin trials to locate a physical endpoint without using the production HCOF/relinearization path;
- F-GC49D production ABI convergence over mixed N:1 and 1:1 topology;
- explicit HEAD_STATE_CAPACITANCE and no-drainage application authority;
- stale SWAP response-origin rejection;
- F-GC24 committed-only split-process restart authority;
- fresh-process replay in the composed closeout gate.

## Restart and replay boundary

The existing F-GC24 contract is retained as restart authority: only committed SWAP state, committed groundwater continuation, committed ledger state and accepted origin provenance cross the restart boundary. Checkpoints, trial candidates, prepared handles, Newton state, Jacobians and worker scratch do not.

The closeout gate additionally repeats the real-SWAP/live-MODFLOW end-to-end fixture in a fresh process and requires identical reported accepted endpoint/transfer signatures.

This does not claim a new native MODFLOW6 checkpoint format or mid-Newton restart capability.

## Frozen analytical regression bank

The DSW/NH/PB/G analytical programme is frozen as a regression/oracle bank at the recorded research head. It remains research evidence, not production authority. No new dummy feature is required for this closeout.

The freeze record is integration/f-gc/F-GC_FIXED_INTERFACE_ANALYTICAL_TESTBANK_FREEZE.json.

## Explicit nonclaims

This closeout does not claim:

- exact internal Newton/MODFLOW trajectory equivalence;
- active coupled drainage;
- coupled root extraction;
- MODFLOW STO as independently additive physical groundwater storage;
- mixed-effective or overlapping physical storage ownership;
- universal or field-calibrated authority for the numerical magnitude of MODFLOW `Sy`/`Ss` used as head-state capacitance;
- a new native MODFLOW restart/checkpoint mechanism;
- mid-iteration restart;
- heterogeneous field-scale N:1 transferability beyond the qualified production topology mechanics;
- a finite-resistance q-link architecture;
- equality of fixed-interface head and phreatic water-table elevation.

Within those bounds, the same accepted transfer has one physical sign convention, one response interpretation, one committed-state origin, one ledger meaning and one production publication path.
