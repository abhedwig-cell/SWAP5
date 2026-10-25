# Native project hydraulic bootstrap

HIST-INTEGRATION01, baseline `3f184a488bce19bfcabf9c349cbff0d836b8cfeb`.
The explicit `--native-hydraulics` option connects the admitted hydrostatic and
KSATEXM importer to the existing native project caller. The prepared external
BBC/Cauchy owner supplies the initial bottom mode. SWINCO2 GWLI supplies initial
pressure heads, pond depth and actual initial groundwater metadata. The source
importer and all physical process, solver and restart procedures are unchanged.
The default SWINCO1 route is retained byte-exact at its physical outputs.

The qualified project composition is a constructed twelve-node/two-layer soil,
three simple crop periods, original detailed rainfall/DRA/BBC input, Boesten
evaporation, implicit Cauchy3, Picard continuous conductivity and implicit upwind
solute transport, at the already accepted explicit .01 temporal tolerance.
The whole481-day calculation and independent day365 restart are required at O0/O2.
Hard water/solute budgets remain1e-10. Below/equal KSATEXM values select the
unchanged source no-op branch; they are not enhanced-conductivity qualification.
The unmodified original112-node input remains component-qualified separately.

Active KSATEXM above KSATFIT combined with Picard rejects at the unchanged
runtime admission guard (water101, zero attempted steps). Both initial failed
O0/O2 trials are retained. This combination is explicitly excluded here, even
though active KSATEXM is admitted in its separate column route. Fully saturated
file initialization, full original macro/heat/crop composition, SWBOTB1 and loose
historical restart remain excluded. No cross-product or full Andelst claim.

```bash
FC=gfortran python tools/solute/build_project.py --optimization O2 --output /tmp/swap5-project
python tools/solute/run_project.py project.swp --bundle /tmp/swap5-project --output /tmp/swap5-project-result --native-hydraulics --temporal-tolerance .01 --solute-transport implicit_upwind --water-conductivity picard_continuous --surface-exfiltration historical_zero
```

The selection changes application initialization/caller bindings only. Reuse
accepted unchanged column/heat/NUT/macropore scientific evidence, and validate
its original raw assertions and source identity. Recompile the project caller;
do not repeat unchanged broad solver, highest low-air or RossFast qualification.
Completed below/equal invocations from the initial failed active qualification
are reused with source/executable/manifest/artifact identity checks. The original
failed events and original qualification script are kept, without rewriting them
as successful active runs. Source/raw checks, corruption controls, FSI35 source
boundary and actual canonical merge/postimage checks are separate admission gates.
