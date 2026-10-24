# Competing constant sinks: research decision boundary

Baseline: 2de14588d192197d547d5287384e0317ad7514b2.
This experiment calls the unchanged production finite-donor interface. It
does not activate a daily crop/organic/top-boundary allocation policy.
No committed model state, persistence interface or production source changes.

Question: do concentration, depletion time and total nitrogen balance uniquely
determine the separate crop and prescribed top-boundary receipts?

Before depletion both constant requests are delivered. After depletion the
continuing positive source can be divided proportionally to requested rates,
with top-boundary priority, or with crop priority. Test all three partitions
against the same actual production trajectory and an independent DOP853 zero
event. Include empty/nonempty donors, positive/zero continuing source and
increasing/constant/decreasing water capacity. These synthetic forcing levels
are discriminating inputs, not an agronomic calibration or recommended rates.

Expected compile/native/validation cost under30 seconds. Execute O0/O2 with
bounds and floating-point checks. Require nonnegative bounded individual
receipts, identical totals, whole-N balance below1e-12 kg/m2 and independent
trajectory errors below2e-12. Keep source hashes, commands and raw output.
Full FCI, RossFast and highest low-air are not selected: no production changes.

Result:108 cases per optimization pass. In72 cases the crop receipts differ
between policies despite the same concentration trajectory and nitrogen total.
Maximum independent ODE error2.723e-14; maximum balance residual1.978e-16 kg/m2.
The scalar donor balance therefore cannot select the allocation policy.

At zero initial concentration, continuing input0.001 kg/m2/day, top request
0.01 and crop request0.03, proportional allocation gives crop0.00075,
top-first gives crop0 and crop-first gives crop0.001 kg/m2 over the day.
All consume exactly0.001 kg/m2. Zero stock means depletion time zero.

Proposed next contract: equal-priority constant sinks share continuing source
in proportion to their requested rates after the zero event. This is an
explicit additional scientific assumption, not a recovered historical identity.
Before production activation it needs separate top/crop receipts, demand/supply
selection checks, NH4-first/NO3 coupling and actual crop/restart/rejection proof.
Organic immobilisation also requires its own organic-pool accounting contract;
it is not qualified by this mineral-donor experiment. Full NUT remains open.
