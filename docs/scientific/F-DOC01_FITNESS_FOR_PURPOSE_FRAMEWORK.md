# F-DOC01 fitness-for-purpose framework

Fitness for purpose is a first-class object, not a concluding sentence in a solver report.

## Application-class record

Each `SW5-FFP-*` object contains:

- intended purpose and decision/use context;
- target outputs and required interpretation;
- spatial and temporal scales/support;
- necessary physical processes and active/inactive options;
- required accuracy or decision-relevant error budget, with independent authority where possible;
- applicable parameter/forcing domain;
- validation support and its coverage;
- sensitivity/uncertainty evidence;
- numerical policy constraints;
- known limitations and failure modes;
- unsupported/nonclaimed uses;
- qualified release/evidence authorities;
- review/update trigger.

## No universal fitness inference

A numerically correct Richards solve is not automatically fit for field-scale crop prediction, regional recharge estimation or groundwater-head management. Each application class needs the evidence relevant to its outputs and decision scale.

The groundwater head-accuracy work is the canonical warning example: absence of an independently justified application-level head requirement prevents converting a numerical head discrepancy into a general fitness verdict. Accuracy targets belong to application-class evidence, not solver convenience.

## Coupled applications

For direct SWAP-MODFLOW use, fitness records distinguish head consistency, interface flux conservation, coupling-window behaviour, groundwater application accuracy and any deep-vadose transfer. Satisfying `q_SWAP = -q_MF` is a hard conservation/interface property but is not by itself a complete application validation.
