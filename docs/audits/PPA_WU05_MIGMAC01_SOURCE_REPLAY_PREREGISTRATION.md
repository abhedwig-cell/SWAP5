# MIGMAC01 frozen-origin Reference-Richards replay preregistration
Date: 2026-10-02
Source event evidence: 9eaf64ac572e080f77e8ea03a17b43ce220e19df.
Registered before observing SWAP5 replay output.

Use the exact 112-node, five-domain accepted origin of the first preregistered
MODIFIED_ANDELST_COVERED_TOP event. Retain source heads, water contents, hydraulic
coefficients, root/irrigation/drainage terms, macro continuation, geometry and
rate parameters. Additional read-only CDarcy extraction is permitted without
changing physical source input or event selection.

Boundary replay: prescribe recorded accepted matrix qtop=-1.1316953578911639
and qbot=+0.21131394916821408 cm/day through explicit-flux top and SWBOTB=2.
These are frozen source boundary receipts, NOT rainfall supplied to macropores.
This bounded experiment excludes source dynamic ponding and SWBOTB=3 feedback.
Keep source origin ponding and groundwater as origin values; the replay does
not claim whole-application equivalence. Retain dt=0.002 day. No head, forcing,
dt or tolerance sweep after outputs. Existing solver strict tolerances and
production mass tolerances remain unchanged.

Geometry above top has zero storage and zero exchange; source diameter=0 there
can be represented with positive dipomi solely for unused configuration validity.
Retain source physical geometry everywhere at/below top. Initialize and compare
source geometry and canonical storage; do not repair unexplained differences
by normalizing physical state. Preserve original synthetic failing fixture
as negative evidence.

Other macro exchange processes use frozen source configuration and accepted
continuation but evaluate through existing trial-local runtime machinery.
Any unsupported source parameter/geometry or failed solve must be diagnosed
and persisted, not eliminated to force activation. First replay determines
whether active covered transfer survives the migration's current architecture.
Positive output alone does not qualify transaction replay/restart, preservation
or canonical integration. Frozen Status-A denominator and M2 remain unchanged.
