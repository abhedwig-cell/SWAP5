# GC-RZM06C02 native-centimetre resolution bridge preregistration

Date: 2026-09-22  
Machine-readable authority: `337d32821a25aaebf5eddc9d84f5724c94d249e9`  
Production changes: none

## Why this bridge exists

RZM06A2-A6 established a real limitation of the focused F-GC four-node carrier, not of SWAP as a whole. The carrier uses a scaled four-node grid and resolves the upper 0.30 m with only one node. LOW01 separately demonstrates the legacy HeadCalc geometry in native centimetres.

C02 therefore changes only the research fixture geometry. It retains the real HeadCalc serialized-reference solver, the explicit B110 constitutive provider, the fixed-H_c materializer and the existing transaction/retry/mass semantics.

It is deliberately not called Hupsel. The exact Hupsel application remains the preferred full-real-case target, but its raw case bytes and nodal geometry are not repository-native.

## Frozen vertical grid

Native geometry unit: centimetres.

The 300 cm column uses 17 compartments:

- 0-30 cm: six layers of 5 cm;
- 30-100 cm: seven layers of 10 cm;
- 100-300 cm: four layers of 50 cm.

Thus the upper 30 cm is represented by six independent water-content states rather than one.

The exact frozen arrays are in the machine-readable preregistration.

## Initial hydraulic state

The B110 parameter tuple is unchanged from the F-GC44 research fixture.

The initial top pressure head is -75 cm. Pressure head is increased downward using the exact centre-to-centre node distances, producing a hydrostatic profile with constant h+z = -77.5 cm.

For this native-cm research profile only, the lower coupling datum is placed at the physical bottom of the 300 cm column, -3.0 m. The corresponding zero-flux interface hydraulic head is therefore approximately -0.775 m.

## Qualification before science

C02 does not test H2.

It first requires:

- exact 17-node geometry;
- six root-zone nodes in the upper 30 cm;
- read-only committed-node diagnostics;
- exact aggregate reconstruction from the nodes;
- hydrostatic baseline identity;
- finite reference coupling head in the preregistered range;
- a mass-complete, origin-preserving zero-top read-only interval.

It then performs a response-blind admissibility map at fresh baseline origins for both signs of:

`1, 0.1, 0.01, 0.001 cm d^-1`

and durations:

`0.01, 0.001, 0.0001 d`.

Only transaction, retry, temporal, solver and mass diagnostics are retained. Bottom exchange is neither selected on nor persisted.

Only after C02 qualifies and at least one two-sided nonzero forcing point exists may C03 preregister a new H2 construction. The H2 thresholds remain unchanged.
