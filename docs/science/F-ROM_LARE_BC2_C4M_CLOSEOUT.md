# F-ROM-LARE BC2-C4M closeout

Formal decision: C4M_DIAGNOSTIC_BLOCKED.

The final authority is workflow 35468238818 at head 47a99351a92365a7d927c50961f71fa9df2b686c. Earlier C4M runs are superseded.

Five of six cases reproduce the authoritative C4L cubic metrics and all five reject the parameter-free central interface gradient relative to B9. The remaining 5 cm HOLD case is formally blocked because the recomputed cubic RMS differs from the persisted C4L value by about 1.92e-10 cm/d, above the frozen 1e-10 reproduction gate. The source blobs are bit-identical, so this is treated as numerical reproducibility rather than provenance drift. The gate is not relaxed.

The usable bounded mechanism evidence still points in one direction: the direct central finite-volume slope uses too much of the terminal-to-bulk slope contrast. It is therefore not admitted for propagation.

A new independent diagnostic may test a response-blind face-interpolated slope with the opposite distance weighting, delta_s = d/(B+d)*(b_bulk-a_t). This is a physically derived geometry hypothesis, not a fitted blend, and must be preregistered separately.
