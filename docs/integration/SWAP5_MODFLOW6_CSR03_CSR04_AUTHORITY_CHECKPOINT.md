# CSR-03/CSR-04 authority reconciliation checkpoint

Date: 2026-09-20

Live canonical checked: `integration/f-ci-canonical@3a815edda7cf5e155272b68ae49d440fd5db9138`.

PR #486 branch is currently diverged from canonical. Its merge base is `09b6d0415fee3c63c71ecd11b215fe0d206e05ae`; it is 37 commits ahead and 46 commits behind the live canonical at this checkpoint.

## Live-delta disposition

The canonical delta from the original semantic-audit preimage `919bbf76370c2136932daa04ad88135e7d1615a8` to the live head contains governance, project-control, ROM and test-bank preservation changes. The compare surface shows no F-GC production/runtime coupling change. The semantic findings therefore remain scientifically unrebutted, but PR #486 is not admission-ready until recomposed/reconciled to current canonical.

Current project-control authority explicitly classifies PR #486 as an F-GC shared-authority candidate whose owner qualification must finish before central-regie reconciliation/admission.

## CSR-03: vertical head-transfer authority

The corrected coupling contract remains:

`H_SWAP,bottom = T_H(H_MF, topology, datum, resistance, ...)`.

The current implementation is the special case `T_H = identity` after datum alignment. Existing evidence establishes the arithmetic/datum conversion and numerical behavior of that special case. It does not establish that a MODFLOW cell/node head is universally the physical hydraulic head at the fixed SWAP lower face.

The 2024 coupling authority also distinguishes MODFLOW head from SWAP diagnostic groundwater level and permits resistance within the SWAP-represented phreatic system. Therefore:

- identity transfer may be admitted only as an explicit application-topology assumption;
- no new resistance law is authorized by the current repository evidence;
- the coupling API must keep MODFLOW regional head, SWAP lower-face trial head and SWAP diagnostic groundwater level as distinct quantities.

Disposition: `CSR03_CONTRACT_RESOLVED_IMPLEMENTATION_METADATA_PENDING`.

This is no longer a reason to invent a transfer law. The bounded implementation target is metadata/contract plumbing that names the selected transfer law, initially `identity_datum_aligned`, without changing numerical physics.

## CSR-04: storage partition

The existing F-GC predictor defines a finite-window SWAP head response `u` and F-GC33 uses `u/DeltaT` as a head-dependent MODFLOW package slope. MODFLOW STO independently contributes groundwater storage.

The available repository authority does not identify a non-overlapping physical volume assignment between:

1. storage embodied in the SWAP finite-window response `u`; and
2. storage represented by MODFLOW STO.

The fact that tests can numerically compose nonzero STO with the SWAP-derived affine response does not prove absence of physical overlap. Conversely, the present evidence also does not prove double counting.

Three conceptual families remain possible, but none is currently authorized as the realistic production rule:

1. **non-overlap by domain**: SWAP response owns column storage above a declared coupling plane; MODFLOW STO owns storage below it;
2. **response-with-overlap correction**: the SWAP response may include storage also represented by MODFLOW, requiring an explicit subtraction/condensation term;
3. **reformulated exchange response**: derive a coupling response that contains only interface-flux sensitivity while MODFLOW STO remains sole owner of groundwater storage.

Choosing among these changes the physical coupled equation and is therefore not a code-cleanup decision.

Disposition: `CSR04_BLOCKED_SCIENTIFIC_STORAGE_PARTITION_AUTHORITY`.

Required authority before implementation:

- explicit vertical control volumes/coupling plane;
- derivation of the coupled water balance and linearized groundwater equation;
- dimensional/sign audit of `u`, `u/DeltaT`, MODFLOW STO and accepted interface flux;
- proof or explicit correction of storage non-overlap;
- a nonzero-storage-change qualification case that tests component and combined balances.

## Consequences

- Do not merge PR #486 in its current diverged state.
- Do not rerun PUB-GC E7.
- Do not admit drainage/root-process widening as a workaround.
- CSR-01/02 remain bounded useful repair candidates.
- CSR-03 may proceed later as explicit topology metadata without new physics.
- CSR-04 remains the scientific blocker for realistic production admission and PUB-GC closeout.
