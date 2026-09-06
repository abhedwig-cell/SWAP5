# SWAP-013 finding

## Classification

```text
component   PDI input
category    input validation / implementation bug
status      FIX_TESTED
certainty   very high
severity    high
```

## B0 behavior

For PDI models 8–11, B0 uses:

```fortran
call rdfdor ('h0',-5.0d7,-1.0d5,h0,maho,numlay); h0(1:numlay) = -h0(1:numlay)
call rdfdor ('ha',-1.0d5,0.0d0,ha,maho,numlay);  ha(1:numlay) = -ha(1:numlay)
```

Thus an input `HA=0` becomes `ha=0`, and an input with `abs(HA)=abs(H0)` is also accepted by the individual scalar ranges.

The PDI constitutive implementation subsequently uses `log10(HA)` and a logarithmic scale denominator based on `log10(HA)-log10(H0)`. Consequently:

```text
HA = 0      -> log10(0) is undefined
HA = H0     -> logarithmic denominator is zero
HA > H0     -> violates the intended ordered PDI dry-range construction
```

The scalar input ranges alone cannot enforce the relational constraint.

## Intended rule

The audited implementation and documented PDI construction require, after conversion to magnitudes:

```text
0 < HA < H0
```

for every PDI layer.

## Minimal repair

Add a relational guard immediately after the existing H0/HA reads and sign conversion, restricted to models 8–11. No constitutive function is modified.

This is an implementation/domain-validation correction, not model development.
