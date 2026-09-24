# F-PDI-VT continuation and handoff strategy

Date: 2026-09-24

## Decision

F-PDI-VT is scientifically complete once the already-qualified VT06B result is accepted together with the final bilateral-finiteness hardening rerun.

No further exploratory PDI vapor-temperature experiments belong in this workstream.

The remaining production-admission work is historical source-governance work and therefore moves to the corrected-reference B1/VQ line.

F-AHL remains closed.

## Scientific conclusion carried forward

The PDI vapor-conductivity implementation mixes Celsius input with an absolute-temperature saturated-vapor-density equation.

The authority-consistent correction is limited to one local absolute temperature:

`TK = Temp + 273.15d0`

used consistently in `MgRT`, `Da` and `Rho_sv`.

The Celsius interface remains unchanged.

SWAP-009 signed unsaturated pressure-head semantics remain unchanged.

Existing evidence establishes:

- theory/documentation/code defect reconciliation;
- independent formula qualification over negative and positive Celsius temperatures;
- actual-source Fortran qualification;
- SWAP-009 signed-head preservation;
- full-model Vapor-on activation;
- NoVap non-regression;
- finite full-model behaviour with a physical temperature path;
- water-balance-controlled normal completion;
- representative moderately colder full-model activation;
- negative evidence at 5 C where the vapor correction is below observable BFO resolution in the short qualification case.

## Workstream boundary

Do not continue F-PDI-VT by:

- tuning more temperature cases merely to accumulate evidence;
- modifying PDI physics beyond the qualified temperature conversion;
- changing SWAP-009;
- reopening F-AHL;
- reconstructing historical source manually from a non-identical upstream host;
- weakening the byte-identity requirement.

## Next workstream: B1/VQ production admission

The next owner should be the corrected-reference B1/VQ line.

Its task is narrow:

1. obtain or materialize the exact canonical SWAP 4.3.1 B0 source archive, or an already replay-verified byte-exact B1.11 source tree;
2. verify the controlling historical identities before modification;
3. reconstruct B1.11 through the existing deterministic chain only;
4. apply the already-qualified F-PDI-VT minimal patch to exact B1.11;
5. derive and persist:
   - exact repaired `WC_K_models_04_11.f90` postimage SHA-256;
   - exact repaired 63-member source-manifest SHA-256;
   - updated source byte count;
   - ordered patch identity;
6. rerun the relevant function, SWAP-009, NoVap, Vapor-on, cold-case, mass-balance and normal-completion gates on the admitted historical candidate;
7. if all gates pass, publish the next immutable corrected-reference snapshot and admit the repair.

Until step 1 is possible, production admission remains fail-closed.

## Authority identities to carry into B1/VQ

- canonical B0 target `WC_K_models_04_11.f90`:
  `1f956cae894e83e208630e234c9b2017c945b2c522daf8277e89541f598ae4fd`
- after SWAP-009 / B1.6:
  `f728e832645ab8273e41d0d285910240565148671989de24882740e7244f15b7`
- B1.7 through B1.10:
  `7ca607b2bbf97e166a32ab8a529fc7f32af9949afb1e6eb518ddbf84e6f0169e`
- B1.11 after SWAP-011:
  `d6038f1c2e0f4d061738bb2a176398cd89b7da59310394a2c4049fd0b4214126`
- B1.11 source manifest:
  `24ce2768b3804ca1744457e8a7adcf101e37a4c1390049df23179e09816957e2`

The legacy-capable upstream host used for full-model qualification is explicitly not historical byte authority.

## Trigger for AHL requalification

Only after the PDI temperature correction is formally admitted into the authoritative corrected-reference source should a new work unit be opened:

`F-AHL-PDI-VAPOR-REQUAL`

That work unit must remain small.

It should:

- use the corrected authoritative PDI hydraulics;
- qualify only the previously excluded or blocked PDI Vapor-on envelope;
- preserve the existing F-AHL NoVap and non-PDI conclusions unless the admitted source delta demonstrably affects them;
- not repeat the complete F-AHL research program.

## Recommended project sequence

Current recommended sequence:

`F-PDI-VT scientific close -> B1/VQ historical production admission -> F-AHL-PDI-VAPOR-REQUAL -> normal canonical admission/governance`

If the exact historical bytes are not currently accessible, place the B1/VQ item in a blocked state and continue other independent SWAP5 workstreams. Do not keep F-PDI-VT active merely because the historical archive is unavailable.
