# PERF01 historical extension: research failure, 24 October 2026

**The historical configuration is not admitted for the water/flux option.**
The bounded four-cell30cm production option remains admitted and default OFF.
No production source, default, mass gate or tolerance changes in this work.
Baseline is canonical `aba91da43` including PR1413's saturated continuous-MvG/
Picard repair. Positive original chemistry remains rejected before execution.
Historical comparisons explicitly zero CPRE, CDRAIN and CMLTB, retaining the
original120cm12-cell soils, crops, seasonal calendar and detailed rainfall.

## Results

All complete481-day variants close water to below1.9e-14cm/day and solute is
exactly zero. This does **not** establish sufficient daily physical agreement.
The required daily difference limit is0.01mm for runoff, storage, uptake and total
surface evaporation; no limit was relaxed.

| Detailed481-day zero-tracer variant | Native seconds | Max runoff difference, mm | Max storage difference, mm | Disposition |
| --- | ---: | ---: | ---: | --- |
| Incumbent head reference |33.67|0|0|Reference |
| Water/flux with retained proposals |21.41|0.05679|0.06217|FAIL |
| Water/flux plus dry-head safeguard |see JSON|0.01687|0.01687|FAIL |
| Water/flux plus complete incumbent assessment |31.02|0.01687|0.01687|FAIL |

Times are individual observations, partly overlapping other research/build work,
not paired performance estimates. Faster static/seasonal runs also fail daily
accuracy. Initial detailed fallback execution was censored after120seconds;
failed input staging, compile diagnostics and all censored/failed runs are retained.
Actual day240 disk restart of the conservative complete-incumbent variant is
byte-exact for final state, endpoint, restart and all241 continued daily rows.
Restart PASS does not override accuracy FAIL.

The current97-day continuous-MvG/Picard/Boesten subset passes its bounded daily
criteria on8/24cells at1x/4x. The selected eight-cell O0 outputs match O2 byte for
byte, and all four day48 continuations match exactly. Separate soil/pond
allocation remains outside the bounded physical claim.

## Execution-route correction

The earlier published combined Picard cases and the new continuous97-day cases
hit Picard's independent retained-proposal admission guard: each arm performed97
zero-work preflight rejections, followed by the ordinary-policy retry. Those
speed observations prove the changed temporal metric on the fallback route;
they do **not** qualify active retained proposals with Picard. Original raw
capsules remain immutable. Current historical research explicitly admits the
retained policy only in the generated water/flux route and reports zero fallbacks.

Detailed-rain whole-day retry must call the detailed-rain day runner again.
The generated research main fixes that dispatch, preserving original segment
boundaries and staging a whole day before publishing committed state. Production
continues to reject this unqualified combination.

## Remaining runtime

An observational native build prints each real rain segment's counters. Both
instrumented arms reproduce budget/state/endpoint/restart bytes exactly.

|481-day detailed run | Accepted transactions | Temporal rejections | Solver rejections | HeadCalc calls | Linear solves |
| --- | ---: | ---: | ---: | ---: | ---: |
| Incumbent head |41,095|178,295|2,596|662,697|4,677,207|
| Water/flux, active retained proposals |481,102|8,382|202|1,468,778|4,533,649|

Each arm covers3085 clipped day/event segments. The changed metric eliminates
many rejected trials but accepts11.7times as many transactions and calls HeadCalc
2.2times as often, while total linear solves decline only3%. Day246 alone has
33,744 accepted flux transactions. This explains why the large short wet-fixture
speedup does not transfer to the full historical forcing. It is a work-count
explanation, not an additional CPU-time attribution. The earlier measured
97-day split still separately owns solver/controller/I/O attribution; these
counters cannot be presented as timing percentages.

Next research must resolve surface evaporation/runoff error propagation and the
very small accepted intervals during later crop/weather phases. Keep the existing
production boundary until daily accuracy and owning admission gates pass. No
new1e-6 trial, RossFast expansion or highest low-air test was selected.

Machine-readable result and the1337-member verified capsule preserve all source,
build identity, raw physical outputs and failure evidence.
