# B1.11 request policy in the existing crop/Soil-N transaction

Status: proposed bounded successor; not canonically admitted.
Base: canonical 093bff909f38f8bfa3b1284b40a0c3736e864954.
Owner: MC-NUT01, existing crop_soil_state_t. Invariants: one persistent N owner,
accepted-only publication, independent whole-N balance, atomic rollback and restart.

The already-qualified B1.11 demand/fixation component is selectable only by an
explicit optional crop configuration. Absence preserves every existing WOFOST81
request, equation and restart byte. This is a request-policy composition with the
existing WOFOST81 growth, senescence and N-allocation owner, not full B1.11 crop-N
or translocation equivalence. WOFOST81 remains the default and is not rewritten.

The selected request uses pre-growth leaf/stem/root masses and committed organ N,
the existing maximum-leaf-N table at committed DVS, and explicit DVSNLT/NFIXF.
Stem/root maximum fractions use the existing configured concentration ratios.
No growth or storage-organ demand is added. The strict DVS/RELTR gates, literal
root+stem+leaf addition and independent NFIXF and (1-NFIXF) products are retained.
The existing prepared request is replaced completely, including zero translocation;
its WOFOST81 fixation cannot survive as a second input. Only the existing apply
operation books the one fixation input and actual soil supply.

Historical B1.11 suppresses allocation at total demand <=1e-5 kg/ha even while
booking nonzero supplied/fixed N. Active positive demand in that interval is
rejected before soil mutation; it is neither silently clipped nor admitted as a
mass-conserving source profile. Zero and gate-disabled demand remain valid.
Only the explicit vegetative uptake phase below the WOFOST81 translocation onset
is selected: a B1.11 request must not silently disable an active translocation
process. DVS at/after that onset is rejected. Full reproductive translocation,
B1.11 residual-concentration death and root-translocation rules remain open.

Immutable policy fields append a tagged configuration suffix only when selected.
Opaque restart copies the existing configuration and ledgers. Existing native
restart retains and compares the complete vector, rejecting missing, mismatched
or corrupt policy before publishing any owner. No new persistent mass store or
second codec is added. The consumed soil clock rejects duplicate day events.

Required evidence: literal request discrimination, nonzero fixation with zero
WOFOST81 fraction and vice versa, no growth/storage uptake, zero/full NFIXF,
DVS/RELTR boundaries, ample/limited/exhausted soil, whole-N balance, no replay
or rejected-trial leak, actual Richards composition, opaque and fresh-process
native continuation, policy identity negatives, and unchanged default drivers.
Use existing real production closures with measured compile/link/native costs.
Do not rerun RossFast, highest low-air or full F-CI merely for imports/source
pinning. Admission still requires current affected owner proof and preserved
unchanged defaults; no missing proof is relabelled PASS.
