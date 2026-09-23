# TAB-HYD KSATEXM candidate A result

Date: 2026-09-23

Status: **FALSIFIED — preregistered conductivity limit exceeded**

Branch: `research/tabulated-hydraulics-ksatexm-characterization`

Candidate authority:
- preregistration: `research/tabulated_hydraulics/KSATEXM_GENERATED_PROVIDER_PREREGISTRATION.md`;
- candidate implementation: generated raw-head400 state sampled from the admitted F-SI39 analytical provider, with one unsplit TSPACK ln(K) spline;
- controlling lower-layer workflow: run `35854220809`.

## Exact lower-layer authority

The test uses the exact F-SI39 Hupsel lower-layer B1.11 parameters, including:

- KSATFIT = 22.76176 cm/d;
- KSATEXM = 227.6176 cm/d;
- relsat threshold = 0.9981816467911503;
- K at threshold = 15.814441314772257 cm/d.

The historical ReadSWAP authority fixes the transition pressure head at `hthr=-2 cm` and derives the latter two quantities from the default MvG curve. The same derivation reproduces the exact F-SI39 lower-layer oracle.

## Preregistered result

The frozen candidate passes theta/C but fails K:

- theta max abs error = `2.0753513608404162e-6` (limit `1e-4`);
- capacity max abs error = `6.3570482923912552e-6` (limit `1e-4`);
- log10(K) max abs error = `3.9320897050766801e-2` (limit `5e-4`) — **FAIL**.

Maximum K error occurs at:

- h = `-1.9386526359522058 cm`;
- analytical F-SI39 K = `25.604962690374933 cm/d`;
- generated unsplit-spline K = `23.388547427925893 cm/d`.

This point lies immediately on the wet side of the admitted `h=-2 cm` KSATEXM branch transition.

## Interpretation

The failure is structural, not a runtime or bounds-check failure.

A single smooth ln(K) spline across the F-SI39 transition smears a genuine derivative discontinuity between:

1. the default MvG conductivity branch below the relsat threshold; and
2. the admitted linear-in-relative-saturation KSATEXM branch above it.

Increasing confidence in the same unsplit representation is therefore not justified. Candidate A is closed as falsified and its tolerance must not be relaxed.

## Next research candidate

A new candidate may preserve the same 400-row/raw-head/TSPACK representation while treating the admitted KSATEXM threshold as an explicit interpolation-segment boundary.

That candidate must be separately preregistered before implementation. It may not claim continuity of the K derivative across the threshold and remains K0-only.
