# B1.12 partial leaf return in the existing crop/Soil-N owner

Status: bounded production contract. Qualification and actual canonical admission
are recorded in `integration/audits/MC_NUT_SOL_STATUS.json`,
`b112_retained_stock_20261016`; this contract alone is not admission evidence.
Baseline:5d2518abd2b285b13f9b5f7d2177918589fd7abc, including admitted B1.12,
classic annual1264 and independent signed multilevel drainage1109.

The explicit profile requires the admitted B1.11 reproductive process and
classical SW_WOFOST=1 harvest. It changes the existing residue disposition, not
the N request/supply equations or the existing default/full-return profile.
Daily root DM/N all returns; leaf fraction f returns; stem remains above ground.
Nonreturned leaf/stem material is physical stock, not an immediate export.

## One state hierarchy

Use the existing actual biomass owner for retained dead leaf/stem DM, alongside
its distinct cumulative gross mortality diagnostics. Use its existing nested N
owner for retained leaf/stem N and an explicit profile identity. No separate crop,
N ledger, soil inventory, clock, management calendar or commit owner is added.
Gross N loss stays the existing organ-loss diagnostic and must not be counted as
physical retained material. Retained N is a subset of that gross loss and is
added once to whole physical N. Root mortality is not a retained pool.

Both actual biomass and N clone/validation must include the new physical fields.
Their bounds are finite, nonnegative and N<=matching DM. Nonprofile owners cannot
carry retained material. Existing default physical behavior and native bytes
remain unchanged. New-profile continuation must also preserve the current gross
mortality diagnostics; legacy default payloads are not silently reinterpreted.

## Day, harvest and continuation

Daily staging first consumes yesterday's existing pending material, runs the
actual soil/crop day, then partitions new deaths into existing pending and
retained stock. The partition closes DM/N exactly. Threshold-dropping and orphan
N remain rejection conditions. A failed trial cannot modify the accepted state.

Harvest fractions apply to living plus retained leaf/stem DM/N. Already-soiled
root/death material is not returned again. Existing pending material and harvest
pending are consumed once. Physical retained values clear at harvest; gross N
loss already contains their senescent N, so harvest must not debit that N again.
Whole N and organic material include retained stock; new-profile whole organic
material also includes living biomass so harvest/export does not create mass.

Use the existing owner pack/unpack and same native adapter. Explicit new payload
versions distinguish the selected profile from old tags1..8, including empty,
pending, harvest and thermal phases. Old profiles keep their exact payloads.
Wrong/missing profile, invalid material, stale clock, altered configuration,
truncated/corrupted payload and trailing bytes must reject before publication.
Native fresh-process and opaque continuation must agree with uninterrupted state,
including retained and gross mortality fields. No new kernel or water codec.

## Frozen qualification conditions

1. Small real production split/state drivers O0/O2, with f0/.25/1, leaf/stem death,
   nonnegative/orphan/NaN/threshold controls, clone and explicit profile identity.
2. Existing actual soil/crop/pending drivers: repeated daily deaths, partial and
   full harvest fractions, original B1.12 reference, retained + soil + export DM/N,
   and rejection/retry/replay at both pending and harvest boundaries.
3. Existing actual Richards joint application, delayed incorporation, opaque and
   native fresh-process continuation with nonzero retained leaf/stem stocks.
4. Actual current default/1253/1260 and annual source-state/codec preservation,
   especially unchanged old endpoint/restart bytes. Inherit unaffected solver and
   drainage qualification by exact dependency, not unrelated reruns.
5. Source-bound scientific/admission guards and docs pass against the exact
   candidate and merge. Whole-capability counts change only if their complete
   existing denominator closes; this profile alone does not claim that.

Full moving FCI, RossFast and highest-low-air are NOT_SELECTED_IMPACT. The selected
joint compile/native gate may cost several minutes because it closes the actual
shared water/soil/crop/restart boundary; that is the justified integration gate,
not routine process feedback. Retain measured compile/link/native costs and raw
failed results. Aquifer remains excluded.


## Executed-evidence boundary, 17 October 2026

The current successor requires unique checked O0/O2 compilation and link records
for every exercised production provider and driver, actual native commands with
raw output, every named configuration/decoder rejection, and the joint-provider
digest for thermal reuse. Missing native runs, duplicated providers, changed
optimization/IEEE flags or unexecuted rejection labels fail closed. The separate
independent guard review qualifies the validator only, never production physics.
The current annual source and old codec are executed and checked, rather than
accepted from summary booleans. The current TCS6 shared native boundary is checked
with the source-bound provider closure, including later canonical dependencies.

The new profile remains explicit. Standard WOFOST81 growth, the bounded B1.11
vegetative/reproductive N options and corrected B1.12 residue semantics retain
their distinct scientific authorities. Complete historical selector/parameter
activation and the full historical NUT capability envelopes remain outside this
bounded admission. No whole mastercoverage promotion follows from this profile.
