# MIGMAC01 bounded B1 CALCGWL correction preregistration
Date: 2026-10-02
Status: PREREGISTERED_NOT_QUALIFIED
Baseline branch: c6358a7ddb1eb13665cf0b2a28408213e55bd84f
Canonical: 0d44f0195c94a9732c67b5e77f2148912df9bbc8

Repository authority: docs/verification/principles.md; confirmed B1.11 carrier
defect in PPA_WU05_MIGMAC01_REFERENCE_CARRIER_DEFECT.md. Exact B1.11 remains
immutable. Corrected selected source is labelled
B111_PLUS_MIGMAC01_CALCGWL_PATCH_UNQUALIFIED, never silently B1.12.

The correction changes only the start of the perched search: use the negative
node reached by the existing bottom-up ordinary-groundwater scan, rather than
the water-table-containing cell returned by nodlev. For no bottom-connected
groundwater, retain numnod. Whole-profile saturation retains its existing early
return. This excludes all bottom-connected positive nodes without excluding an
unsaturated water-table-containing cell. No hydraulics, air-volume criterion,
boundary, numerical tolerance, forcing or time step changes.

Before using any corrected event, execute the actual source CALCGWL in isolated
regression cases: saturated containing cell; unsaturated containing cell;
fully saturated column; no ordinary groundwater; multiple shallow wet islands
with air-volume merging; no perched zone; and the captured 112-node exact
last-rate state. Assert disjoint ordinary/perched positive ownership and
independently prescribed expected carriers. Run O0 and O2. Preserve baseline
source hash d7649f02bf6cd629cc7eceb1c761a6c38d6f0adf0d0c072c7aaab3af4562f5eb.

Then rerun the fixed MODIFIED_ANDELST_COVERED_TOP case with its sole pre-existing
Z_TP=-2 cm change, unchanged official forcing/dates/tolerances and the existing
first chronological accepted positive-covered-transfer selection. Capture
origin, accepted state, last rate and exact matrix/macropore ownership. A
missing event, failure, non-finite state or mass violation is a negative result;
do not tune inputs or select a later convenient event.

Stable persisted qualification must identify the patch, expanded source and
TTUTIL manifests, compiler selection, compiler flags, test postimage and
case inputs. Local exploratory results alone do not globally admit a corrected
B1 reference or MIGMAC01. Existing source-origin negative evidence remains
immutable. Covering physical-parameter and matrix-area integration gaps remain.
Status-A denominator, A9 top1 and M2 exclusions remain unchanged.
