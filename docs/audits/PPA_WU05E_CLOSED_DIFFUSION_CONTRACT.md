# PPA-WU05-E closed mobile diffusion slice

Status: proposed process contract, not runtime or canonical admission.
Parent source: `abff5c95fe4bd072f9e24c5497d6f4b2f069364a`.

## Source and envelope

The byte-verified B1.11 `solute.f90` has SHA-256
`2fc8592001cdcd2de95a252d8b9099416c94e4d2654c335908858a735f80e7a2`.
Lines 273 and 320-335 form molecular diffusivity as
`DDIF * theta_face**2.33 / theta_sat_left**2` and constrain the explicit
solute timestep. Lines 363-371 add dispersive transfer between adjacent
nodes. Its positive-upward convention becomes positive-downward transfer
`theta_face * D_face * (C_left-C_right) / distance` in SWAP5.

This slice isolates that molecular term with stationary positive liquid
storage, no advection, no roots, no drainage, no external salt exchange,
no sorption, no decomposition and no macropores. Face water content and
positive node-center distance are explicit caller inputs. The saturation
input is the source left-layer saturation for each face. No implicit grid
interpolation or harmonic interface averaging is invented here.

## Ownership and numerical policy

Node mass remains authoritative. A process call reads matching mass and
water storage and returns a new candidate plus diagnostic closure and step
count. It owns no commit, restart or root-water sink. The candidate remains
empty on any failure.

Compute each face conductance G in cm/day and storage V=theta*dz in cm.
The explicit update is conservative on each face. The monotonicity bound
is `dt <= min(V_i / sum(G_adjacent_i))`. It makes each new concentration a
convex combination of old neighboring concentrations, preventing negative
mass without clipping. A caller supplies a separate positive maximum
numerical timestep and positive substep limit. Choose equal substeps no
larger than either bound; reject exhaustion before computing a partial
candidate. There is no legacy minimum-step override that could exceed the
bound. This is a deliberate numerical-policy difference, not byte-exact
legacy replay.

## Required process evidence

Use a two-node analytical exponential relaxation oracle with unequal liquid
capacities. Require convergence under timestep refinement, exact steady
uniform concentration, conservative heterogeneous multi-node evolution,
nonnegative concentration within its initial extrema, deterministic O0/O2,
unchanged committed input, and atomic failure for malformed dimensions,
nonfinite/negative parameters, inconsistent concentration and substep limit.
The zero-diffusion case must preserve the state exactly.

Passing these tests establishes only this closed diffusion process. Mechanical
dispersion, advection/dispersive joint stability, changing water storage,
surface/aquifer ownership and live runtime integration remain separate gates.

## Local process qualification result

The published source at `bd4f52751b2f1384410ac790ae92b165911d7948`
passes the required O0/O2 gate with runtime checking and invalid/zero/overflow
floating-point traps. The analytical errors at maximum steps 0.1, 0.05 and
0.025 day are 0.00855264, 0.00420001 and 0.00208153 mg/cm3. This is the
expected first-order convergence toward the exact two-node solution.
The source molecular coefficient and flux sign also pass a one-step direct
equation oracle. Heterogeneous conservation/extrema, steady identities,
replay and atomic malformed/exhaustion rejection pass.

The existing independent mobile-salt, salinity-response and water-face
reconstruction O0/O2 gates remain successful. Exact source/dependency hashes
and result lines are persisted in
`integration/audits/PPA_WU05E_CLOSED_DIFFUSION_PROCESS_GATE.json`. This local
process qualification does not extend the earlier live matrix lifecycle
qualification: the new process is not called by FMR. Mechanical dispersion
and jointly stable advection/dispersion under changing water storage are the
next process gate, followed by typed boundary and runtime qualification.
