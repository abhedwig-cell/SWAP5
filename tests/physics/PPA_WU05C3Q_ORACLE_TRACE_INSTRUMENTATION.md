# C3Q corrected-SWAP-4.3.1 oracle trace instrumentation

This file specifies the minimal diagnostic-only instrumentation to apply to the pinned corrected
SWAP 4.3.1 B1.11 source when producing C3Q oracle vectors.

It is NOT a production patch and MUST NOT alter any physical or numerical branch.

## Record location

Emit one CSV row at the end of each physical `OxygenStress(node,...)` evaluation after
`resp_factor` and `rwu_factor` are final.

## Header

```text
call_index,node,matric_potential_pa,theta,gas_filled_porosity,soil_temp_k,max_resp_factor,waterfilm_thickness_m,d_soil,r_microbial_z0,ctopnode,c_macro,c_min_micro,resp_factor,rwu_factor
```

## Required values

All values must be the actual variables already used by the corrected 4.3.1 evaluation.
Do not recompute diagnostics through a second formula path.

## Determinism

- call_index starts at 1 for each process run;
- full precision scientific notation;
- no wall-clock timestamps;
- no addresses or compiler-specific metadata;
- trace output must not be consumed by the model.

## A/B/A

Run corrected 4.3.1 A, pure-kernel B on the captured A inputs, then corrected 4.3.1 A replay.
A and A replay trace files must be byte-identical before B differences are interpreted.

## Guard cases

The saturated/gas-filled-porosity shortcut may not populate all internal fields in legacy code.
Such rows must carry an explicit route tag in the extraction implementation rather than fabricated
values. C3Q comparison for that route is on the defined output subset.

## No hidden tolerance

Capture raw doubles. Difference/tolerance analysis happens after capture.


## Implemented transformation

`tools/vq/c3q_instrument_oxygen.py` implements the diagnostic transformation.

Gates:
- exact corrected B1.5p1 oxygenstress SHA required;
- declaration anchor must occur exactly once;
- final-response anchor must occur exactly once;
- trace blocks are explicitly delimited;
- stripping those trace blocks must restore the original B1.5p1 bytes exactly.

The trace now includes `ctopnode` because exact-source reconciliation established the ordered
vertical propagation `C_top(node+1)=C_macro(node)`.
