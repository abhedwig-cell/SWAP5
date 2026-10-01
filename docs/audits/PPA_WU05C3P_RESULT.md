# PPA-WU05-C3P production composition result

Date: 2026-10-01

Status: `QUALIFIED_PRODUCTION_COMPOSITION_BOUNDARY`

## Gate

Persisted workflow:
- `PPA WU05 C3P oxygen composition`
- run `36919068192`
- merge SHA `9198448df2d2a88398cc3085e736b3be44cd913d`
- result: PASS

Observed:

```text
PPA_WU05C3P_ROOT_OXYGEN_COMPOSITION=PASS
```

The gate compiles the current soil-water contract and hydraulic view, current root-water-uptake
process, and the oxygen composition adapter together, then executes the focused composition test.

## Qualified ownership

- existing root-water-uptake process owns the base sink;
- oxygen owns no water mass;
- oxygen factor is bounded [0,1] and shape-checked;
- only rooted nodes are modified;
- total actual uptake is recomputed from the composed sink;
- invalid oxygen factors fail without producing a composed physical result.

Existing ABI warnings in the broad soil-water contract are explicitly excluded from this focused
gate's `-Werror` policy via `-Wno-unused-dummy-argument`; this does not weaken warnings for the
new oxygen composition code.

## Decision

The root-sink composition boundary required by C3Q is qualified for production wiring.

This does not yet admit the Bartholomeus option into canonical runtime selection. Remaining admission
work is end-to-end option wiring plus preservation gates proving that oxygen-off behavior is unchanged
and oxygen-on behavior reaches the qualified kernel/composition route.
