# PPA-WU05-C3P production composition result

Date: 2026-10-01

Status: `QUALIFIED_COMPOSITION / END_TO_END_ADMISSION_PENDING`

C3Q qualified the pure Bartholomeus physical response. C3P tests the production ownership seam:
oxygen is a root-sink modifier, not a water-flux owner.

Persisted workflow:
- `PPA WU05 C3P oxygen composition`
- run `36919068192`
- job `110560257874`
- result: PASS

Observed gate:

```text
PPA_WU05C3P_ROOT_OXYGEN_COMPOSITION=PASS
```

The gate compiles the current soil-water contract, process hydraulic view, existing macro/Feddes
root-water-uptake process and the oxygen composition adapter together.

Qualified behavior:
- existing drought/root sink is evaluated first;
- oxygen factor is applied only to rooted nodes;
- non-rooted sink entries are preserved;
- final actual uptake is recomputed from the modified sink;
- oxygen factors outside [0,1] fail closed;
- the oxygen component does not book water independently.

The earlier C3P CI failure was a harness dependency-order defect: the soil-water solver contract was
not compiled before `mod_process_hydraulic_view`. The harness now compiles and links the full
dependency set. A pre-existing unused-dummy warning in the broad solver contract is scoped out of
this narrow gate; warning policy for the new oxygen code remains strict.

Decision:

`C3P = PASS / PRODUCTION COMPOSITION QUALIFIED`

Remaining before canonical admission:
1. wire the qualified Bartholomeus factor provider into the actual production root-uptake execution
   selection for the admitted analytical-MvG option;
2. prove non-oxygen route preservation;
3. execute full oxygen end-to-end regression;
4. persist admission/closeout and merge only after those gates pass.
