# MC-MET01 daily traditional PM and CFBS production contract

Status: delegated bounded additive application decision; implementation and
qualification pending. Baseline `bd17f0a9a7c19516e66af8f80e2b7128890b3aee`.
User delegated execution of the PR1215 package on 12 October 2026. Existing
REGIE/PPA/RT own the application seam; independent source/VQ/F-CI gates remain.

One immutable opt-in daily-demand configuration is retained by the existing
file-weather application configuration and opaque joint continuation. Disabled
by default. Mode1 applies historical SWCFBS only to the restricted reference-ET
soil demand. Mode0 computes daily SWETR0/SWDIVIDE0 traditional Penman-Monteith
and the branch-specific CFBS semantics. PMdirect remains unchanged.

The existing guarded file-weather segment authenticates the record, weather
identity, coverage and committed time. It first preserves the incumbent common
forcing validation, then materializes the opt-in daily demands from that same
record and immutable configuration before dynamic-top evaluation. Rain/irrigation
and transaction ownership remain unchanged. This is not a caller-supplied demand
override and does not expand the standalone common-forcing adapter envelope.

First production envelope: root-free BASE or AIR/no-snow default-MVG bottom7,
uniform daily rain mode0; no positive caller canopy/transpiration and no rooted,
interception, detailed-record, Snow, MODFLOW or lifecycle-transition expansion.
Pure source qualification separately covers cover/emergence/SWCF/CFBS/CO2 and
pond semantics; it does not establish physical rooted extraction.

New PM calculations live beside the existing reference-demand process with no
new build dependency or state owner. Existing arithmetic is retained. The
weather adapter exposes a read-only authenticated daily PM view including stored
humidity and wind, never external setters. The opted-in immutable parameter
closure must be matched explicitly on joint restore before soil/crop publication;
wrong/missing configuration fails closed. Existing opt-out restart remains exact.

Source: B1.11 MOD_meteo member SHA256
99fbf7ad4d90f71cc86012e8e1c9970ef4ca40ea879f0f0622a02a0c33be4c9f.
Literal penmon/astro/raero/ETpot provide the independent oracle. In traditional
PM, SWCF1+SWCFBS1 chooses crop PM for es0 before CFBS multiplication. CFBS
must not scale transpiration or pond demand. Preserve historical operation order,
units, clipping, crop-height choice, factor processing and CO2 treatment.

Declare bounded finite physical input ranges before calculation to reject
invalid log/power/exponential domains and overflow without weakening physics.
Unknown selectors, NaN/Inf, incompatible canopy/config and nonrepresentable
results fail closed. No tolerance/reference mutation or silent source repair.

Acceptance: independent source oracle O0/O2 plus branch-discrimination witnesses;
authentic multi-day actual hydrology, mass, failed publication/retry, exactly-once,
midinterval joint restart/config mismatch; incumbent weather/crop/RAINTB and
required Full Richards/F-CI/PPA and affected highest frost gates. Version exact
postimages, failed attempts and relevant closure. Unknown closure means rerun.
Fullcap admission is not inferred from root-free production; retain bounded
receipt and ACTIVE when wider master semantics remain unproved.
