# Complete97-day project timing

Measured at canonical771dada4 with a fresh checked GNU13.3 O2 native194
project build. Three alternating head/flux pairs per rain factor use the same
sealed original SWP,CRP andMET fixture. Both arms retain accepted-step proposals
and use temporal tolerance0.001; the admitted flux option changes the accuracy
metric. Compilation is excluded from the following wall times.

| Rain | Head native,s | Flux native,s | Head complete,s | Flux complete,s |
| --- | ---: | ---: | ---: | ---: |
|1x|0.59166|0.02486|0.74550|0.15414|
|4x|0.68921|0.01755|0.80710|0.15669|

The complete command includes Python startup, input readers and preparation,
bundle/source validation, native execution and atomic output publication.
Independent preparation medians are0.031–0.032s. Complete speed ratios are4.84x
and5.15x; native ratios are23.8x and39.3x. Independent medians are not an exact
additive timing breakdown. Native execution now accounts for roughly16%/11%
of complete flux-option time; the remaining route is the next performance target.

All twelve complete executions finish97days. Each budget,state andendpoint file
is byte-identical to its directly executed native counterpart. Repeated physical
outputs are exact within each arm. Every daily water residual is below1e-10cm;
head/flux differences retain the declared daily runoff and storage0.01mm limits
and actual transpiration1e-8mm limit. Raw inputs, physical outputs and process
streams are preserved in the evidence archive; the JSON records every timed
command, source hash and physical digest.

This measures the existing bounded option; defaults and production sources are
unchanged. These are host-specific observations of a changed accuracy metric.
The study does not supply a new accuracy-matched4.3.1 comparison.
