# MC-IRR01 accepted root/material DCS1 successor

Status: source-bound scientific candidate tested at O0/O2; canonical admission
is separate and recorded in `integration/audits/MC_IRR01_STATUS.json`,
`root_material_dcs1_20261016`.

Baseline: `7f5441c5caff025e6eb95ed6044e5a851d47363a`.
Existing owner: `integration/control/MC_IRR01_APPLICATION_COMPOSITION_20261011.json`,
`shared_interface_decision_20261016`; bounded PR1251/1252 foundations.

## Scientific contract

The authenticated B1.11 `SWAP/irrigation.f90` SHA256
`65830c1e030be8030995547729d9298e6352778f132e5195af2962baa38a3bf1`
is retained in `integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64`.
Lines310/312 define `phfieldcapacity` in [-500,0] cm with default -100 cm;
lines354/355 use `(hlim3l+hlim3h)/2` and `hlim4`. Lines458..468 sum
material-derived threshold and actual water over the accepted rooted support,
including the fractional last cell `(ztop+rd)/dz`.

Use the already admitted constitutive-provider water-content interface and
current typed per-node material. No copied MvG formula in production, no invented
constant threshold arrays, no alternative root or water owner. Historical
layer-to-node parsing is not qualified by this typed material binding.

First application scope is default-MvG one-column authentic managed weather,
persistent actual SWRD2 depth, existing TCS7/8 and one/three-node SSDI.
The disposable root/material view is constructed only at a new selected day
after emergence, from the committed crop depth and the application's immutable
geometry/material. Actual theta comes from the existing committed soil snapshot.
The existing DCS1 policy owns adjustment, full authenticated daily gross rain
deduction, zero clipping and depth limit; allocation follows that stage.
The inherited literal TASK4 contract does not scale SSDI `qssdi`. Only a
positive configured rate scales event duration by availability; a zero-rate
SSDI event retains the source's one-day duration and unscaled subsurface rate.
Do not silently substitute the surface-irrigation scaling rule.
An in-flight event retains its frozen rate/end/allocation. There is no
recalculation from growing roots, changing soil or allocation expiry.

## State and architecture

Invariants3/5/7/13/22/23/27 remain binding. The helper creates scratch views only.
The existing bootstrap publishes irrigation and physical/crop receipts after
accepted segments; failure may retain only the already accepted common prefix.
No new persistent owner or restart schema. The existing opaque joint bundle
already retains full immutable configuration and accepted soil/crop/event state,
including the new field-capacity scalar. Native weather disk continuation stays
outside this contract. No change to solver policy or mass tolerances.

## Selected verification and claim ceiling

1. Existing modular runner, explicit `--case irrigation_material`: real provider,
   heterogeneous material, evolving depth/partial cell, analytic unsaturated
   witness, negative deficits, invalid/nonfinite inputs and A/B/A. Expected5s;
   measured closure/build/link/native costs must be retained.
2. Existing managed-weather runner extended with actual rooted DCS1 drivers:
   TCS7/8, one/three SSDI nodes, current/lagged schedules, authentic rain,
   accepted-depth variation, physical hard mass, common-prefix/retry and opaque
   continuation. Retain original weather/DCS2 outputs and affected owners.
   Expected650s for a single cold O0/O2 build; record actual split. No repeat of
   unchanged qualified solver tests solely because the input values changed.
3. Exact current postimages, inverse complete incumbent bodies, source-bound
   native evidence and discriminating rejection controls before admission.

Full F-CI, highest low-air and RossFast are NOT_SELECTED_IMPACT. This is not a
PASS for those runners. No TCS2/3/4/6, bottom7/SALTEXCESS, HYD/POWER composition,
arbitrary long-window accuracy, complete irrigation selector envelope or master
capability promotion. Remain branch-only until all selected gates complete.

## Completed candidate evidence

The real material leaf completed at O0/O2 in1.6204/2.6504 seconds, six compiler
requests each. The single final cold physical build completed26 native programs
in606.207 seconds against245 ordered providers per optimization. Aggregate
compile/link/native costs are521.610/3.003/74.646 seconds. Full original weather
and DCS2 native records are byte-identical; current/lagged crop schedules and
opaque joint continuation assertions remain active.

The new physical witnesses are positive capped TCS7 one-node delivery and
wet/rain zero-gift TCS8 three-node delivery. They do not establish an exhaustive
uncapped DCS1, positive three-node or wider parameter envelope. Heterogeneous
material, fractional root cells and evolving depth are separately discriminated
through the real small production contract. No full historical capability is
promoted from this bounded composition evidence.

The first failed gift oracle and an early interrupted second build are retained
with their original statuses. The corrected independent oracle includes sensor
permission and literal zero-rate SSDI availability. No production formula,
physical mass tolerance or historical failure was altered to obtain a PASS.
