# PPA-WU05B: B1.11 frost source reconstruction

Date: 2026-10-05  
Baseline: `integration/f-ci-canonical@9605fbb1622d96f4691117f66264f13b6dd3a47b`  
Work branch: `work/ppa-wu05b-frost-migration`

## Source authority recovered

The supplied `SWAP_4.3.1(6).zip` was checked as a B0 source archive. Its nested
`SWAP.ZIP` hash is `1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151`.
The repository's `tools/vq/b1_11_reconstruct.py` reconstructed the corrected
B1.11 tree and reported `qualified_reconstruction: true`, 63 members, and the
expected member-manifest hash
`24ce2768b3804ca1744457e8a7adcf101e37a4c1390049df23179e09816957e2`.
The relevant frost and temperature files match their B1.11 manifest entries
byte for byte. Selected source members and their hashes are preserved in
`reference/swap-4.3.1/b1_11_frost_source/manifest.json`.

| B1.11 source | SHA-256 | Role in frost chain |
| --- | --- | --- |
| `SWAP/frozencond.f90` | `edd16b08ff238ee41d264d1c4870726f1232fb1143c1340f2dc21f94a3b909cf` | `FrozenCond`, `FrozenBounds`, thresholds and frost-effect arrays |
| `SWAP/temperature.f90` | `92c39d296f41a60cfe3b66f8d1886ea938a53b4e0ea49e7ae1a23dd9680bd338` | sensible soil-temperature state and DeVries heat properties |
| `SWAP/MOD_MvG_functions.f90` | `6b65637866476581b283eb3d61c3aa0dfe4b51f84223f6eea571ac25ecac1104` | exact K and dK/dh frost scaling; B1.11 includes SWAP-011 |
| `SWAP/rootextraction.f90` | `8b7b2846618a8f82f3ed676c2c489d2d34be8c44b0a0d952f7f22ff09af78cd5` | binary frost root-stress factor and stress attribution/compensation |
| `SWAP/readswap.f90` | `e2ddee83afde65d5c10af561c8271c2cd6f23065d431160bf1467d5ebd18768c` | option selectors, input ranges and combination guards |
| `SWAP/swap.f90` | `39d1cbd93dbd0f99505e92ef94ac0d23bddb496529c280397d2d7c2b7eb9b58a` | call order and daily/step execution |

The full selected-member hash list is the machine-readable authority. The
remaining copied members in that directory are call-chain context, not a claim
that every one is itself a frost equation owner.

## Reconstructed execution chain

### Selectors and configuration

`SWFROST` is a 0/1 switch. With `SWFROST=1`, `readswap.f90` reads `TFROSTSTA`
and `TFROSTEND`, each independently bounded to `[-10, 5]` °C. B1.11 does not
check that `TFROSTSTA > TFROSTEND`; equality makes the linear frost-factor
denominator zero when a temperature lies between the two comparisons, while
reversed thresholds do not describe the documented warm-to-cold interval.
`SWFROST=1` requires `SWHEA /= 0`, and `SWFROST=1` with `SWMACRO=1` is rejected.

### Temperature and timing

`MOD_SoilTemperature` owns `TSOIL` and `TETOP`. The numerical route updates the
temperature profile from sensible heat capacity and conductivity using the
DeVries formulation; its heat capacity contains solid, water and air sensible
terms. It has no ice-water partition, fusion enthalpy, latent-heat term, or
freezing/thawing energy ledger. The analytic temperature route also supplies a
temperature profile, not phase state.

At initialization, SWAP initializes water, then temperature. In dynamic
execution, `swap.f90` computes snow at day start where enabled, calls
`FrozenCond(tsoil,tetop)`, calculates root extraction, prepares boundaries,
and runs drainage/soil water. `SoilTemperature(2)` updates the sensible profile
after the soil-water interval. Frost therefore reads the temperature profile
available at the start of that hydraulic attempt. There is no joint thermal-
hydraulic nonlinear iteration in this legacy chain.

### Frost hydraulic result

`FrozenCond` recomputes `rfcp(node)` for every node on every call:

```text
T >= TFROSTSTA: rfcp = 1
T <= TFROSTEND: rfcp = 0
otherwise:      rfcp = (T - TFROSTEND)/(TFROSTSTA - TFROSTEND)
```

The only explicit modification of the constitutive K relation is in
`MOD_MvG_functions.f90`:

```text
Kfrost = K * rfcp + 1.0e-10 cm/day * (1 - rfcp)
dKfrost/dh = (dK/dh) * rfcp
```

The `1e-10 cm/day` floor is an explicit legacy regularizer. Since `rfcp` is a
temperature-derived constant during one hydraulic evaluation, the derivative
formula is internally consistent with that affine-in-K relation. The same
factor is passed through `headcalc`, `soilwater`, top-boundary and bottom-boundary
conductivity calls. It does not alter `theta(h)`, `C(h)`, saturation, or stored
water. B1.11 has no frozen-water variable or separate frost mass flux.

`FrozenCond` also recomputes `zfrosttop`, `zfrostbot` and `nodfrostbot` by
linear interpolation against `TFROSTEND`. `FrozenBounds` uses those values to
modify drainage and bottom-boundary fluxes under additional air-volume and
drainage conditions. This is a separate boundary algorithm from constitutive
K scaling; it is not represented by the factor alone.

### Root uptake

`rootextraction.f90` applies `alpfrs=0` where `TSOIL < 0 °C`, otherwise 1.
Traditional uptake multiplies the node sink by drought, wetness, salinity and
frost factors and attributes the reduction. The compensated route has
`SW_STRESSOR=5` for frost and uses `min(alpfrs/ALPHACRIT,1)` in its legacy
compensation calculation. The microscopic `rootextraction_micro` route fails
closed for `SWFROST=1`; B1.11 does not support their composition. This stress
factor is distinct from `rfcp`: the hydraulic modifier uses configurable
thresholds and a linear interval, while root stress is a binary 0 °C cutoff.

## State, restart, mass and energy

`rfcp`, `nodfrostbot`, `zfrosttop` and `zfrostbot` are module `SAVE` fields but
are overwritten from the current temperature and configuration whenever
`FrozenCond` runs. They are recomputable results, not independent continuation
state. The thresholds are configuration. `TSOIL` is the actual persistent
physical continuation profile; a SWAP5 frost option must reuse the already
admitted sensible-temperature state and its existing restart payload, without
adding frost state solely to cache `rfcp` or frost depth.

Frost K scaling creates no water storage or flux. `FrozenBounds` changes actual
external hydraulic boundary/drainage fluxes, so its migration must account those
fluxes through existing owners exactly once. No latent heat exists in B1.11, so
there is no legacy phase-change energy balance to migrate. A future latent-heat
model would be new physics with a separate energy and water-mass contract.

## Physical and numerical assessment

1. **No thermodynamic phase state.** The label “frost” describes a temperature-
   dependent hydraulic modifier plus a separate root stress. It does not
   describe water freezing or thawing. Claiming ice content, unfrozen-water
   curves or latent heat as migrated 4.3.1 behavior would be false.
2. **Threshold validation defect.** Independent input ranges permit equality or
   reverse order. SWAP5 will require a finite, strictly ordered interval
   `TFROSTSTA > TFROSTEND` and reject invalid configuration before a trial.
3. **Frost-depth interpolation can divide by zero.** `FrozenCond` divides by
   adjacent temperature differences without guarding equal temperatures. The
   singular cases are possible when both bracketing nodes satisfy the threshold
   predicate with equal temperature. The interpolated depth is not consistently
   clamped to the bracketing segment. This algorithm is not accepted by direct
   source parity; any replacement needs a bounded, independent crossing oracle.
4. **Hydraulic regularizer is not ice physics.** The `1e-10 cm/day` residual K
   floor keeps a nonzero conductance at `rfcp=0`; it can permit tiny flow through
   a nominally fully reduced node. Preserve it only as an explicitly named
   legacy compatibility constant in the first bounded route. Do not call it
   frozen-water conductivity.
5. **Split meanings.** Root stress uses a hard 0 °C discontinuity and ignores
   `TFROSTSTA/END`; it can turn off uptake while hydraulic K is unreduced (for
   thresholds below 0 °C) or leave uptake enabled while K is partly reduced.
   That inconsistency is legacy semantics, not a single coherent phase rule.
   Keep it as a separately qualified root modifier and do not silently derive
   it from `rfcp`.
6. **Boundary complexity.** `FrozenBounds` has separate heuristics and flux
   redistribution. It must not be folded into a constitutive K decorator or
   mutate the drainage/bottom-boundary owner. Migrate it only with an explicit
   typed boundary result and independent mass accounting; until then that
   portion is held, not implied by the K slice.

## SWAP5 design boundary

The implemented candidate is a stateless, typed temperature-to-hydraulic-K
modifier. It reads the committed sensible-temperature profile, produces a
trial-local `rfcp` vector, and modifies K and dK/dh through the existing
constitutive-provider seam. It leaves water content, capacity, water mass and
the temperature owner unchanged. Frost admission currently requires the
reference Richards route, active sensible temperature, prescribed bottom mode
2 with exactly zero bottom flux, no root sink, no snow, no macropores, no
drainage-response owner, and no sensible boundary carriers or trajectory
direction. Nonzero prescribed drainage and bottom flux fail closed before the
Richards solve. These restrictions make the unimplemented `FrozenBounds`
changes inapplicable to the admitted candidate route. They do not establish
equivalence for general legacy `SWFROST=1` runs.

The current local runtime oracle covers a strongly frozen profile in that
bounded route and its mass ledger, verifies fail-closed handling for a
nonzero prescribed bottom flux, and runs existing zero-frost Richards and
sensible-temperature preservation oracles. It does not yet force a rejected
frost trial through retry, or serialize/reconstruct a frost-enabled backend
state. Existing sensible-temperature tests establish the reusable temperature
state/restart contract, but they do not alone qualify frost restart behavior.

This candidate remains unqualified and not production-admitted until its
rejected-trial/retry and restart oracles pass, plus the broader independent
temperature-state matrix is persisted. `FrozenBounds` and frost root stress
remain separate slices; the latter is considered only after the hydraulic
frost view is independently qualified, then is composed with the admitted
Feddes/Jarvis/Walsum sink chain. Snow plus frost remains held because current
sensible temperature and snow admissions do not authorize their combined
thermal semantics.

## Work status

The exact-source blocker is resolved. Authority reconstruction and source-level
physical review are complete. A bounded K/dKdh candidate is implemented and
locally tested at O0/O2, but it is not qualified or admitted. Next: prove
rejected-trial retry, frost-enabled restart reconstruction and full independent
state-point coverage; then decide whether to admit this bounded envelope or
expand the boundary owner before doing so.
