# Bounded native FCT refinement and duration

Research successor to PR1419, baseline93f12afe. Preserve its sealed generators,
native caller and evidence. No production implementation or default changes.
Invariants3,5,7,13,21,23,25 apply. The real Full Richards/crop/pond/chemical
composition and existing1670001 restart identity remain authoritative.

Question: how do conservative native profiles change on nested41/82/164cell
meshes and under temporal tolerance refinement, and does the admitted short
pond transition remain conservative/restartable over four constructed days?
These are observations of a coupled nonlinear system, not an analytical accuracy
oracle or a historical-weather/year qualification. Initial grid quadrature is
recorded rather than normalized. Layer boundaries/root depth stay fixed; per-cell
drain extraction scales inversely with subdivision, preserving total extraction.
Aggregate fine cells conservatively to the original41 bins. Report water,
dissolved/sorbed/total chemical stocks separately. Do not assert an accuracy order
unless independently justified by the observed sequence and consistent data.

Select: fresh checked201provider O0/O2 native builds using the unchanged builder;
153 original reader providers per build. Pilot0.4day41cell at O2 before longer
execution. Nested0.4day meshes and tolerances0.001/0.0005/0.00025 at41cells;
four-day41cell runs at Freundlich0.5/1/2,TSCF1,O0/O2, with native fresh-process
split/restart. Retain failures/censoring. Per-process ceiling180s; initially
expected selected native sum<300s from PR1419 costs, build cost UNKNOWN until
measured. Expand only with measured justification. No1e-6 experiments, native
year, RossFast, highest low-air or full F-CI selected. Current research/source
and composed owner validators plus corruption controls precede admission.
