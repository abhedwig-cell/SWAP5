# F-PE-ELASTIC10D — BHR-GT calibration corpus preregistration

Date: 2026-09-29

Status: PREREGISTERED_BEFORE_CALIBRATION_OBJECTS

Parent:
`F-PE-ELASTIC10C_TARGET_EXTRACTION_RESULT.md`.

## Frozen population authority

The Phase-B frozen query returned 692 unique sorted BRO IDs.

Stable ID-list authority:

- count: 692;
- serialization: one sorted BRO ID per line with final newline;
- SHA-256:
  `606a4785a5bea70e443a8729bfd132b9ddebe1ea799e78585ed3ba2f54f54667`.

Every later corpus run must repeat the same frozen query and reproduce this
count and ID-list SHA before fetching any new object.

If the ID population changes, fail closed and record population drift.

## Exploratory objects excluded

The three already opened pilot objects are excluded from both calibration and
holdout selection:

- BHR000000339285
- BHR000000339288
- BHR000000351603

## Deterministic split

For every remaining frozen BRO ID compute:

`SHA256("F-PE-ELASTIC10D|" + broId)`

and sort ascending by that hexadecimal hash.

The first 18 objects are the dynamic/mechanical holdout.

The next 36 objects are the calibration/characterization corpus.

No object may be moved between sets after outcomes are inspected.

## Frozen holdout — DO NOT FETCH

1. BHR000000424612
2. BHR000000462723
3. BHR000000462718
4. BHR000000380954
5. BHR000000458789
6. BHR000000380408
7. BHR000000365007
8. BHR000000377189
9. BHR000000377071
10. BHR000000369337
11. BHR000000361974
12. BHR000000380390
13. BHR000000374009
14. BHR000000360500
15. BHR000000377179
16. BHR000000470651
17. BHR000000381747
18. BHR000000369340

Holdout-list SHA-256:

`bfbb1fdefaef57ea3e6a0d2e077fa8efee5b17f101a92da04f0f75603b94e5df`.

No raw XML for these 18 objects may be fetched before a candidate physical
relationship/model and all thresholds are frozen.

## Frozen calibration corpus

1. BHR000000450418
2. BHR000000451425
3. BHR000000369339
4. BHR000000354227
5. BHR000000373650
6. BHR000000367080
7. BHR000000354099
8. BHR000000455524
9. BHR000000377348
10. BHR000000362519
11. BHR000000359907
12. BHR000000469187
13. BHR000000365772
14. BHR000000462578
15. BHR000000431999
16. BHR000000448182
17. BHR000000351990
18. BHR000000353614
19. BHR000000380405
20. BHR000000374026
21. BHR000000360510
22. BHR000000467482
23. BHR000000380370
24. BHR000000380387
25. BHR000000469885
26. BHR000000377198
27. BHR000000374640
28. BHR000000376817
29. BHR000000424423
30. BHR000000367072
31. BHR000000469045
32. BHR000000374977
33. BHR000000455514
34. BHR000000458816
35. BHR000000377048
36. BHR000000362495

Calibration-list SHA-256:

`7b42fee42b2b05e2f788e13317b90d574b1039cf240e57fb3f2c35fe994dd45e`.

## Calibration extraction

For the 36 calibration objects only:

1. fetch public BHR-GT object XML;
2. record raw service-response hash;
3. compute semantic `BHR_GT_O` subtree hash excluding dynamic dispatch envelope;
4. extract settlement unload/reload targets using the exact F-PE-ELASTIC10C
   DataRecord semantics and sign gates;
5. preserve object/interval/determination provenance.

## Descriptor inventory

For every investigated interval that yields a valid mechanical target, record
source-bound values when present:

- begin/end depth;
- sample quality;
- determination method/procedure;
- stress start/end and branch type;
- volumetric mass density;
- solids volumetric mass density;
- water content;
- organic matter content;
- geotechnical soil name;
- special material;
- organic-matter class;
- sand-median class.

Do not derive:
- dry bulk density;
- porosity;
- void ratio;
- texture fractions;
- effective in-situ stress;

until their exact source/derivation semantics are separately preregistered.

## Required characterization

Report without fitting:

- fetched/completed object count;
- settlement determination count;
- valid unload target count;
- valid reload target count;
- target min/median/max separately for unload and reload;
- target distribution by test method;
- descriptor coverage by target and by object;
- depth distribution;
- stress-range distribution;
- number of objects with multiple valid targets.

## Prohibited model selection

F-PE-ELASTIC10D may not:

- fit a PTF;
- select a regression form;
- open holdout objects;
- tune against SWAP solver behaviour;
- choose a universal default.

Its sole purpose is to establish a source-bound Dutch calibration corpus and
the descriptor/target coverage needed to preregister the next physical model.

## Next gate

Only after F-PE-ELASTIC10D is recorded may F-PE-ELASTIC10E freeze candidate
physical predictor models and validation criteria.

The 18 holdout objects remain closed until that freeze.
