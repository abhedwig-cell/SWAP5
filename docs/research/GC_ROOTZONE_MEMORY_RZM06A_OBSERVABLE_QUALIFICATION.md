# GC-RZM06A observable qualification and geometry correction

Date: 2026-09-22  
Evidence: workflow 35720901013, job 106723301728  
Decision: OBSERVABLE_EXTRACTION_QUALIFIED; ROOTZONE_BINDING_REQUIRES_CORRECTION

The corrected CI wiring executed the new observable test after the complete
F-GC44 real-SWAP/MODFLOW baseline. Both passed.

Observed committed state:
- profile water = 1.0430631535459627 cm
- reported upper-30-cm water = 1.0430631535459627 cm
- distribution moment = -1.5024449665297503 cm
- internal diagnostic groundwater_level = -2.0 cm

The equality of root and complete profile water is not physically plausible
for the four-node fixture whose grid is z=[-0.25,-0.75,-1.50,-2.50] and
dz=[0.50,0.50,1.00,1.00] in the stub geometry. The fixture-binding document
had implicitly treated these coordinates as centimetres. They are numerically
metre-scale geometry in this research carrier, while hydraulic pressure heads
and native exchange diagnostics use centimetre conventions elsewhere.

Therefore the extraction mechanism is qualified, but the root-zone observable
definition is not. The previous 30.0 numeric depth threshold is withdrawn
before any H1-H4 probe is run. This is a preregistration repair based solely on
geometry metadata and the pre-probe observable sanity check, not on E_c.

RZM06A must next define the root interval from explicit geometry units or use a
dimensionless/geometrically declared fixture interval. No scientific memory
claim is admitted from this run.
