# F-ROM-LARE BC2-C6O root-uptake source and feedback contract

## Decision

C6O separates two claims that must not be mixed:

1. **response to a prescribed root sink** can be represented exactly and conservatively on a coarse Layer-ROM partition;
2. **prediction of stress-dependent root uptake** requires within-layer hydraulic information that layer storage alone does not generally contain.

No hydrological response is generated in C6O.

## Current SWAP5 root-uptake semantics

For fine rooted compartment (n),

[
S_{p,n}=Delta f_n T_p,
]

where (T_p) is potential transpiration and (Delta f_n) is the increment in cumulative root fraction.

The admitted drought-only Feddes reduction is

[
alpha(h)=
egin{cases}
0, & h<h_4,\\
dfrac{h_4-h}{h_4-h_3}, & h_4\le h\le h_3,\\
1, & h>h_3 .
end{cases}
]

Thus

[
S_{a,n}=Delta f_n T_palpha(h_n).
]

The current runtime evaluates this process from the **committed hydraulic pressure-head profile**. The resulting sink vector is then carried as a prescribed root sink during the Richards trial.

Existing PPA-ROOT-HYD01 and HYD02 authority is important here: for the concrete prescribed root provider, the same sink vector carried through the generic source/sink route gives equivalent physical and accepted-trajectory behavior. Dynamic Feddes derivatives remain explicitly outside that authority.

## Prescribed sink: exact coarse projection

For retained Layer-ROM layer (I),

[
Q_{mathrm{root},I}
=
sum_{n\in I}S_{a,n}.
]

The exact layer balance is therefore

[
dot S_I
=
q_{I-1/2}-q_{I+1/2}-Q_{mathrm{root},I}.
]

No approximation is needed if the root-sink vector is already known. This is ordinary conservative source aggregation.

So a prescribed-sink replay can answer whether the coarse hydraulic model responds properly to known extraction.

It cannot test ET prediction.

## Predicted Feddes feedback

For an emerged crop with (Delta F_I>0),

[
Q_{mathrm{root},I}
=
T_p
sum_{n\in I}
Delta f_nalpha(h_n).
]

The required coarse stress quantity is therefore the **root-weighted mean of the nonlinear local stress function**.

Layer storage

[
S_I=int_I	heta,dz
]

does not uniquely determine it.

Two fine profiles can have exactly the same total water in a coarse layer while distributing that water differently over rooted locations. One profile can keep most root weight above (h_3), while another puts appreciable root weight between (h_4) and (h_3), or below (h_4).

Those states have equal coarse storage but different actual transpiration.

## Exact information required by the frozen drought-only law

The piecewise-linear Feddes form makes the missing information explicit.

Inside a coarse layer define:

[
F_{mathrm{wet}}
=
sum_{h_n>h_3}Delta f_n,
]

[
F_{mathrm{trans}}
=
sum_{h_4\le h_n\le h_3}Delta f_n,
]

and

[
H_{mathrm{trans}}
=
sum_{h_4\le h_n\le h_3}Delta f_n h_n.
]

Then exactly,

[
rac{Q_{mathrm{root},I}}{T_p}
=
F_{mathrm{wet}}
+
rac{h_4F_{mathrm{trans}}-H_{mathrm{trans}}}
     {h_4-h_3}.
]

This gives a useful state-sufficiency result without inventing a new model.

If the whole rooted part of a layer is unstressed, no additional hydraulic information is required. The same is true if it is completely wilted.

If the whole layer is in the transition branch, the root-weighted mean pressure head is sufficient.

If multiple branches coexist, branch occupancy plus a transition-head moment are required for exact uptake.

## Why the existing first moment is not automatically enough

The C5Y first water-content moment is geometrically weighted. Root uptake instead uses the prescribed root-fraction distribution and pressure-head stress thresholds.

Therefore (S_i,M_i) may be useful, but their exact sufficiency for root uptake does not follow from conservation and has not been established.

C6O does not select another dynamic state.

## Next authority

C6P may test state sufficiency without a time trajectory.

It should construct fine hydraulic profiles that have exactly the same retained Layer-ROM storage state but differ in admissible within-layer structure, then compare exact Feddes uptake.

This directly measures the ambiguity created by coarse state projection before any free-running ET or drought experiment is attempted.
