# PPA-WU05-E-SALFRO01 joint salt/root-frost contract

Status: proposed successor, preregistered before shared implementation changes.
Baseline: `b872ddbd930ea08b058575877a03774d313742cc`.

Scientific authority: SWAP 4.3.1 B1.11 `rootextraction.f90`, SHA256
`8b7b2846618a8f82f3ed676c2c489d2d34be8c44b0a0d952f7f22ff09af78cd5`,
lines 423-484 and the existing compensation section. Multiply Feddes drought,
oxygen, matrix Maas-Hoffman salinity and strict subzero root-frost factors.
Attribute node loss by the four weights `(1-alpha_i)/sum(1-alpha)`.
Compensation preserves one final root-water sink and frozen-node zeros.
Jarvis uses configured critical alpha; Walsum uses current node-bottom geometry.
All five stressor selectors follow the source exponent and compensation rules.

The process stage requires an independent source-equation oracle, O0/O2 byte
equality, unit factors, all-frozen/zero-potential cases, malformed and nonfinite
inputs, loss closure, Walsum geometry, and preservation of Jarvis/root-frost
process gates. Existing runtime salt/frost rejection remains authoritative
until the production stage is separately qualified. No process-only evidence
admits combined production execution.

Production stage: selected matrix mobile dissolved salt, empirical root frost,
Jarvis/Walsum, Reference Richards, prescribed zero-flux bottom mode 2,
no drainage, no Bartholomeus, no bottom frost. Use the existing salt state and
thermal state, no new persistent owner or restart field. Joint temporal error
must be the maximum of existing root-frost and base-salt normalized errors.
Both budgets independently constrain acceptance; neither may be bypassed.
Required actual caller/application evidence: accepted root water and TSCF salt
receipts, hard mass closure, discard/rejection isolation, real temporal retry,
independent oracle, frozen/thaw response and fresh-process restart at O0/O2
for Jarvis/Walsum with upwind and selected dispersion. Preserve affected
admitted runtime routes before production admission.

Excluded: osmotic-head salinity, real ice/latent heat/cryoconcentration,
macropore salt, root oxygen at negative temperature, root/bottom/salt hybrids,
Rutter/salt/frost and seasonal field equivalence. Historical qualification is
immutable. Frozen Status A is unchanged. Owned surface: root process and
existing typed production execution; transaction, water/salt mass ownership,
committed restart and solver interfaces are held fixed.

## Reconciled qualification denominator

Canonical B6 normal frost drainage at `1de2b874` is inherited and separately
preserved; this successor still excludes its combination with salt.
The controlling gate set has 23 groups: joint process; four actual joint
Jarvis/Walsum upwind/dispersion groups; original Walsum and Jarvis matrix salt
upwind/dispersion; root-frost process/runtime; Jarvis process; mobile salt;
D2 application; D3 Walsum; rootless frost runtime; B3 bottom-frost runtime;
B4 joint root/bottom runtime; B6 source/runtime; Rutter production; MIGMAC09;
A8 Richards. JSON source manifests must match the exact executed Git source.
Process and fresh restart checks require O0/O2 identity. All groups and docs
checks must pass before production qualification or canonical admission.

The malformed salinity regression revealed unsafe nonfinite comparisons under
floating-point traps. Ordered finite validation rejects these inputs before
range comparisons, preserving the same permitted finite parameter range.
The old root-frost process salt/frost exclusion assertion is superseded only
for complete four-channel attribution; its replacement still rejects an
incomplete loss sum, with independent new positive and negative coverage.
