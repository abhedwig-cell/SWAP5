# Fixed irrigation age source and original parameter capture

**Proposed source audit; no new SWAP5 implementation, qualification or admission.**
Baseline is actual canonical04031746e after PR1723/1724. Its complete qualified
metadata tree and actual detached registered owner pass in46.890seconds.
Historical closure remains PARTIAL, whole science NOT_QUALIFIED, fixed RC3 unchanged.

Original fixed irrigation reads IRCONC for SWSOLU>0, including the age option.
Original irrigation task1sets CIRR0; task2sets CIRR to the actual fixed event.
Original calc_AgeTracer task1captures Ageirr=CIRR once; task2uses saved Ageirr
for all subsequent surface input. A nonzero fixed input is syntactically allowed
but may therefore be ignored. Establish this through actual original source,
module storage, input/run and nonmutating diagnostics before labeling a defect.
Rain, drainage and seepage ages are forcibly zero in read_AgeTracer; no historical
nonzero rain-age selector is claimed. Macro activity remains excluded.

The current young-water guard is a qualified explicit policy. Preserve it and
all accepted age/calendar/output helpers literally. Existing physical surface
and soil providers already accept age-valued water and record external age input;
new physical equations are not selected. A future explicit source adapter must
retain water1e-10cm, chemical1e-10mg/cm2 and age8192epsilon*max(1,actual inventory,
actual fluxes), with transactional rollback and complete event/source restart.
Saved Ageirr/Agepre/Agedrain are currently static native parameter witnesses.
Dynamic fixed event age must not corrupt that contract or reuse old native codecs.

Select original O0/O2surface/sprinkler8day IRCONC0/20 pairs with a day5gift.
Compare literal original execution against a nonmutating source-value probe and
an isolated task2refresh counterexample. Retain original profile/output limitations
as diagnostics, independently from the corrected provider qualification. Do not
claim nonzero-age forcing in SWAP5 until source, native, reader, reference, mass,
rollback and affected preservation gates have passed and actual canonical admission
is verified. Other input forms and subsurface sources need their own dependency
reconciliation before selection.
