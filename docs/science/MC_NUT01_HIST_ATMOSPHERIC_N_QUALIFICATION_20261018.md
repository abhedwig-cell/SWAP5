# Historical atmospheric nitrogen qualification

Work unit: MC-NUT01-HIST-COMPLETE. Production implementation checkpoint:
`eb535816b1ae484b0587de18de6099bab8a53566`, based on canonical
`8bf52bf23277d193039ea5162e7100b6889bc7c0`. Admission is tracked in
[PR1314](https://github.com/abhedwig-cell/SWAP5/pull/1314) and the
[work-unit record](https://github.com/abhedwig-cell/SWAP5/blob/integration/f-ci-canonical/integration/mc-nut01/MC-NUT01-HIST-COMPLETE_STATUS.json).
This is a bounded successor; it does not close the full historical migration.

## Implementation and independent references

The native historical reader binds `cNH4N_top` and `cNO3N_top` through the existing
activation and immutable mineral parameters. The existing analytical transport,
reactive chemistry, crop hierarchy, accepted Richards trace and native restart
adapter retain ownership. The explicitly selected atmospheric route admits
configured solute only with positive infiltration. Negative evaporation exports
no dissolved N. The separate clean-only route rejects nonzero configured top N
before a water trial. No solver or acceptance criterion changes.

Default-zero concentrations preserve old parameter vectors exactly. Nonzero
values append marker `-81004` and two concentrations. The existing complete
parameter-vector comparison rejects missing or wrong concentrations before
publishing a fresh-process restart, even with otherwise matching parameter IDs.
No dynamic pool, restart schema or parallel transport owner is added.

Original `Wofost_SoilWaterN` is compiled directly in O0/O2 mineral tests for
infiltration with sorption, infiltration plus outflow, evaporation and restart.
The original organic reaction and transport routines independently check active
chemistry with top input and subsequent evaporation. These are original-source
comparisons, separate from endpoint/restart comparisons of the new model.

`run_boundary_source_witness.py` compiles the original archived TTUTIL library.
It executes management_soil lines192..197 unchanged (B0), then with exactly one
corrected destination (B1): `cNO3N_seep` is assigned to `cNO3N_seep`, instead of
incorrectly overwriting `cNO3N_lat`. Both optimizations confirm the B0 defect and
independent B1 top/lateral/bottom concentrations. The unread B0 destination is
initialized solely to expose the assignment error; no claim is made about its
undefined value in a complete original execution. This is a reader witness, not
a full original-model multiyear simulation.

## Actual production scenario

The fresh production closure executes both optimizations with checked arrays,
FPE traps and Reference Richards. The new profile spans730 continuous days from
1900-12-30. It has an active crop, daily water/N uptake and biomass/N distribution,
two harvests with retained residues, chemical fallow and amendments, a successor
at day365 and two calendar-year boundaries. Two source materials and six events
include coincident applications and organic amendments during fallow.

Top NH4/NO3 concentrations are0.0005/0.0015kg N/m3; groundwater concentrations
are0.001/0.002kg N/m3. Seasonal daily temperature, radiation and daylength forcing
and controlled groundwater exchange replace sustained drying. This is a
controlled contract scenario, not a calibrated site or independent field validation.
The previously admitted zero-top/high-groundwater profile remains a separate
case; its original endpoint, the source124-day endpoint and default endpoint
remain byte identical at both optimizations.

Fresh processes resume at days1,120,121,365,366,500 for each optimization and
produce byte-identical full endpoints. Every atmospheric resume also rejects
both absent and wrong top concentration identity atomically. At days120 and366,
clean-only admission and stale-environment rejection preserve the complete
serialized state; accepted retry then continues to the same endpoint.

The atmospheric endpoint SHA256 is
`d3f6ab63c1c6e20dccc22821b8cf86a464063b2638fa8fca619142970244fddd`.
Cumulative whole-system nitrogen in kg/m2 is initial0.66569153059254693,
input0.013678071059048533, output0.0077548447218841101 and
final0.67161475692971284. Residual is-1.5178830414797062e-15kg/m2.
Total internal crop uptake is0.0068629020535616418kg/m2; maximum daily N residual
is1.6548815150939063e-15kg/m2 and maximum accepted water-step residual is
4.986462631695332e-15cm. The hard existing balance gates are unchanged.

## Independent accepted-carrier audit

An observational driver reuses source- and artifact-bound production objects,
runs both730-day profiles anew at O0/O2, and must reproduce their exact main
endpoints. The additional observations do not feed the production equations.

Water balance in cm: initial10.377346899380083, signed top input0.00006194825028434364,
bottom input28.164960854763596, lateral input0, outflow0.4650182252684006,
root extraction27.699930239845116, final10.377421237280426. Residual is
1.7763568394002505e-14cm. Water content spans0.3313437794793025..0.4039759894671573;
pressure head spans-91.01662183697339..-22.17468522605584cm. The signed near-zero
top integral does not erase the separately integrated positive infiltration N.

Atmospheric N input is4.650389582411417e-5kg/m2; groundwater input is
8.449488256429077e-4kg/m2; lateral input is0. Their sum equals the chemical
external-input receipt. Gross amendment N is0.009642000000000001kg/m2,
volatilization0.0004965, other soil external loss0.002261604274708762,
fixation0.0027446183375815173, harvest export0.004996740447175348 and
successor initial crop N0.00039999999999995595kg/m2. Internal crop uptake
is excluded from whole-system external loss exactly once.

The730-day run accepts14025 substeps, has60584 temporal rejection/retries and
zero solver rejection. Minimum accepted step is3.814697265625e-6day; maximum
normalized temporal indicator is0.9999596991660622. These counts expose the
existing temporal cost; no criterion or substep cap is relaxed.

## Limits

The [boundary contract](MC_NUT01_HIST_TOP_N_CONTRACT_20261018.md) distinguishes
accepted fixed-flux infiltration from the original gross atmospheric carrier.
Simultaneous rain/evaporation within one day, surface storage, ponding and runoff
solute semantics are outside this qualification. General TTUTIL extensions,
fractional timestamps, experimental humus and extended diagnostic output remain
unqualified. The original imposed-bottom-flux-0.1 drying stress remains failed;
it is neither repaired nor relabelled. RossFast receives no extension.

Only the scoped atmospheric capability may be admitted. Full HIST completion and
mastercoverage promotion remain false. Immutable previous evidence is retained;
changed owners require fresh native qualification, while genuinely unchanged
classic source/codec and modern-export surfaces retain their bound evidence.

## Qualification and preservation receipt

The required integrated runs on the implementation checkpoint are SUCCESS:
focused native39154014408, historical activation39154015051 and actual B112
production39154014477. Documentation39154014214 and local strict MkDocs pass.
The final evidence/guard receipt changes no production provider from that tested
source tree. Fresh local retained-joint, thermal-phase and all54 TCS6 native
executions pass; original native/thermal/TCS6 payload bytes are preserved.

The owning guard checks current source inputs, actual checked compile/link/native
inventories, raw streams, all transition/rollback payloads and independent old
byte references. Twelve corruption controls reject missing atmospheric input,
missing native execution, incorrect source correction, leaked clean-only state,
changed providers and the existing retained/thermal/TCS6 corruptions.

All31 automatically triggered workflows were monitored to terminal. The unrelated
publication source-freeze gates reject production changes by construction; stale
DRAMET3 build lists and the TIMEINT16 marker remain separate failures. Automatic
F-CI modular feedback used the old pre-extension source-bound guard and failed
on the changed mineral provider. Its replacement requires the fresh selected
physical/retained evidence and exact current owning chain; no prior PASS is
rebased by merely replacing source hashes. Full numerical F-CI is not selected.
Relevant raw failure context and run conclusions are archived with the evidence.

The physical capsule is `MC_NUT01_HIST_ATMOSPHERIC_N_20261018.tar.xz.b64`, decoded
SHA256 `75465b9278c352042c6985ebb22ca79456149e35bedbf15adea1c0aa7c0bc5e2`.
The retained/audit capsule is `MC_NUT01_HIST_ATMOSPHERIC_RETAINED_20261018.tar.xz.b64`,
decoded SHA256 `4fd9710417e888128c41816f007b7f70359d89cfed279fad42c658cb718dc83a`.
Both contain complete member manifests. Previous capsules remain immutable.
