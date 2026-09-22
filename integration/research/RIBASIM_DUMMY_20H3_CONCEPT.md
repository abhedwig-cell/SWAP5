# RIBASIM-DUMMY-20H3: allocation low-storage-factor mechanism

> Status: PREREGISTERED after DUMMY-20H2.

DUMMY-20H2 proved that the ~8 m3/day infiltration is present in the exact
`basin.vertical_flux.infiltration` pointer before the first update and is
physically realized, yet allocation remains 32/0 m3/day.

The v2026.1.1 allocation formulation represents Basin negative vertical forcing
as:

```text
implicit_negative_forcing_volume * low_storage_factor
```

where the low-storage factor is an allocation decision variable bounded between
0 and 1.

DUMMY-20H3 observes that LP state directly in exact release source.

The preregistered mechanism is:

```text
injected ~8 m3/day infiltration
    |
    v
allocation receives ~8 m3 negative forcing
    |
    +-- low_storage_factor free --> alpha ~ 0 --> root allocation stays 32
    |
    +-- alpha fixed to 1 --------> root allocation drops to ~24.0000853
```

The fixed-alpha case is a diagnostic counterfactual only. It is not a proposed
production setting.
