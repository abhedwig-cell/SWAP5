# Bounded corrected fixed subsurface chemical source

**Qualified work-unit scope; canonical admission has a separate merge receipt.**
The historical no-macro migration remains PARTIAL. Whole scientific equivalence
remains NOT_QUALIFIED, and the named RC2 release scope is unchanged.

The original fixed subsurface irrigation producer leaves `cirr` zero, and original
CDE omits the nodal `qssdi` chemical source and its irrigation ledgers. Actual
concentration0/20 perturbations deliver2.4cm water with no chemical response;
the surface positive control delivers48mg/cm2. Adding CDE alone still delivered
zero because the producer was incomplete. Both failures and their original
executions are retained in the work-unit evidence.

The correction in `reference/swap-4.3.1/patches/NOMACRO-SUBSURFACE-SOLUTE-01`
changes the no-macro chemical fixed producer and CDE consumer explicitly. The
real production evaluator `src/process/mod_subsurface_solute_source.f90` computes
each compartment's `qssdi * cirr * dtsolu` in mg/cm2 and divides by its actual
thickness for the conserved bulk stock. It neither reallocates the water nor
normalizes the original compartment distribution. The same amount enters the
original cumulative and intermediate irrigation ledgers.

The experimental original-input route selects the source-bound correction for
SWSOLU1/SWIRFIX1/SWMACRO0. Existing CIRR remains in the complete irrigation native
state. The evaluator has no persistent state; CDE scratch amounts are freshly
derived each substep. No native format, solver, tolerance or macropore behavior
changes. Scheduled chemical SSDI remains refused.

## Qualification and limits

`integration/f-ci/nomacro-complete01/CHEMICAL_QUALIFICATION.json` owns the bounded
qualification; `CHEMICAL_MERGE_RECEIPT.json` separately records actual canonical
admission. The current successor consumer is
`tests/nomacro_scheduled_subsurface/chemical_verify.py`. Prior S/pulse/R proof and
consumer bodies remain literal; the actual immutable predecessor was executed.

- Windows and Ubuntu: point/interval at donor/kernel O0/O2, eight complete1096day
  trajectories, actual48mg/cm2 input, unchanged1e-10 water and solute guards, and
  24 exact own physical/CSV/native windows including the event and year boundary.
- Both platforms:24 paired original/corrected1096day source controls each.
  Surface and source-absent outputs are exact at matching optimization; corrected
  point/interval mass equals actual water times concentration.
- Windows: file/inline8day physical and CSV equality at both optimizations;
  reversed, outside-domain and nonfinite depths refused by actual original code;
  active discard/replay/adopt/recovery and deliberate chemical mass rejection
  preserve committed state and origin.
- The late-May uncompensated salinity composition completes both1096day
  optimizations, with positive3.4921434323cm salt-induced uptake reduction, exact
  native144to146 and year windows, and active external/refusal controls. Earlier
  zero-net-stress attempts are retained and are not counted as active evidence.
  Paired actual original controls have zero stress without the omitted source
  and3.4919791765cm with the correction. The approximately0.00016426cm difference
  from SWAP5 is recorded; no whole-model equivalence or new stress tolerance is
  asserted. Existing numerical/time-policy differences remain separate from the
  demonstrated source and mass correction.
- Fresh Grassgrowth/Hupsel/SaltFarm and four scheduled-water full trajectories
  retain exact generated sources, physical/CSV rows and selected native payloads.
  Four201day pulse compositions retain active physical/CSV/native prefixes.

The small independent production driver checks units, conservation, A/B/A,
nonmutation and unchanged outputs after invalid/overflow requests at O0/O2.
The current-owner negative controls reject62 evidence corruptions. Selected
small production contracts and the existing historical owner tests remain
separate gates; this does not assert an unexecuted full moving F-CI PASS.

## Reproduction

Use the existing no-macro original provider preparation and run:

```text
python -B tests/modularity/run_modular_tests.py --case subsurface_solute_source --output COMPONENT
python -B tests/nomacro_scheduled_subsurface/chemical_fixed.py --configuration point --reference-work PROVIDER --output POINT
python -B tests/nomacro_scheduled_subsurface/chemical_fixed.py --configuration interval --reference-work PROVIDER --output INTERVAL
python -B tests/nomacro_scheduled_subsurface/chemical_fixed.py --configuration point --salinity --reference-work PROVIDER --output SALINITY
python -B reference/swap-4.3.1/patches/NOMACRO-SUBSURFACE-SOLUTE-01/run.py --reference-work PROVIDER --output ORIGINAL
python -B tests/hupsel51/verify_successor.py
```

The portable source/reference run is GitHub Actions44071407357. Its carrier adds
only the registered dispatch alias; it is excluded from canonical source.
Immutable raw archives include member inventories and forward verification.
