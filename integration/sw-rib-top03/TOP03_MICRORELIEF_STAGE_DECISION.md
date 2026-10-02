# TOP03 microrelief stage-evolution decision

Date: 2026-10-02  
Status: SIMPLE_MICRORELIEF_STAGE_ROUTE_FALSIFIED__PARTIAL_CONTACT_ONSET_BENEFIT_RETAINED__NO_PRODUCTION_ADMISSION  
Evidence run: GitHub Actions 36980247134  
Source postimage: `7c340134ef95b6a77f5817995fbb870decca7cac`

## Question

Can the uniform-microrelief contact law that repaired the fixed shallow-onset refinement remain coherent as external water stage rises from partial to full wetting?

The test keeps the same dry soil, bottom mode 7, constitutive law and Reference Richards solver. All temporal refinements share identical stage-event boundaries.

## Result

No tested amplitude completes the full six-event trajectory at any refinement.

The flat `D=0` route remains clearly unstable under refinement and fails progressively earlier.

`D=0.02 cm` only has partial contact during the first stage event and is not sufficient.

For the larger amplitudes:

- `D=0.05 cm` survives the partial-contact stages but fails when `H=0.05 cm`, where the uniform geometry reaches full wetting.
- `D=0.10 cm` fails when `H=0.10 cm`, again at full wetting.
- `D=0.25 cm` fails already at `H=0.20 cm`, corresponding to wet fraction 0.8, before full wetting.

Mass residuals of the completed substeps remain at roundoff scale and O0/O2 output is identical. This is therefore not a mass-accounting or optimizer-dependent failure.

## Interpretation

The preceding fixed-stage result remains important: shallow partial contact strongly improves the initial dry-to-wet transition and creates complete contracting refinement sequences.

But **uniform microrelief geometry by itself is not a sufficient surface law**. As the effective areal hydraulic contact becomes large, the same near-saturated numerical difficulty returns.

That narrows the useful physical hypothesis further. The relevant quantity is not only wetted area or representative ponding depth. The effective hydraulic contact between external water and the matrix must itself remain a finite, physically defined transition rather than collapsing automatically to the saturated-face conductance.

A plausible next representation is therefore a finite surface-contact resistance or thin transition-layer law. In reduced form this is a Robin/Cauchy boundary: the wet fraction still comes from surface geometry, but the matrix contact conductance includes a finite resistance in series with the soil face. This would preserve a continuous matrix-to-surface-water transition even at full areal wetting.

## What is not justified

Do not:

- select a production microrelief amplitude from the fixed-stage sweep;
- claim that event alignment alone solved TOP03;
- restore the exact-state temporal gate with an arbitrary finite tolerance;
- treat wet fraction alone as the complete physical surface model.

## Decision

Retain partial-contact microrelief as one component of the preferred surface model, but falsify the simple rule `K_contact = f_wet K_face` as a sufficient partial-to-full production route.

The next bounded prerequisite should test a physically explicit finite contact resistance / transition layer while preserving the already tested geometry and mass ownership.

PR #956 remains draft and unadmitted.

Machine-readable evidence: `integration/sw-rib-top03/TOP03_MICRORELIEF_STAGE_RESULT.json`.
