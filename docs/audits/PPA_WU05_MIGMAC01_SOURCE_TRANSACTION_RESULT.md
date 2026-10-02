# PPA-WU05-MIGMAC01 source-backed transaction result

Date: 2026-10-02
Status: QUALIFIED_SOURCE_TRANSACTION_WITH_G7_ATTRIBUTION_OPEN
Qualified postimage: 16c66c41c8bbc009cd0efa76c79502532af85f66
Preservation run: https://github.com/abhedwig-cell/SWAP5/actions/runs/36989583419
Owning branch: research/ppa-wu05-migmac01-covering-layer

## What changed

The corrected B1.11 IcTopMp > 1 source replay now carries the source matrix-area
fraction explicitly through the typed Richards request and serialized FMR
configuration. Covering-layer minimum polygon diameter and covering Ksat are
immutable FMR physical configuration fields and are propagated to the inner
macropore provider.

The Reference provider route also now migrates the B1.11 short-step macropore
iteration policy for source-backed matrix-area configurations without enabling
legacy module-global SWMACRO ownership.

The serialized Reference admission gate now permits macropores together with
root extraction. The backend already had the required ownership split:
root uptake is removed from the generic source/sink carrier and bound through
the root-sink provider. The stale mutual exclusion prevented the frozen source
event from entering the transaction path.

## Frozen source result

The exact corrected source origin is unchanged.

Direct active runtime:
- Reference Richards converges;
- top_node = 3;
- accepted covering-node head remains positive;
- covered internal matrix-to-macropore transfer =
  9.3532308817326723e-7 cm;
- matrix covered sink is negative;
- macro storage increases;
- internal and macro receipts pass the existing 1e-9 cm diagnostic gates;
- accepted input macrostate remains immutable before commit.

Serialized source transaction:
- completed = TRUE;
- transaction mass residual = 1.0020738579197275e-16 cm;
- solver rejections = 0;
- temporal rejections = 0;
- mass rejections = 0;
- discard/replay identity = PASS;
- commit publication = PASS;
- persistence/restart identity = PASS.

The source transaction is checked at both O0 and O2.

## Preservation on the exact postimage

The combined persisted workflow on 16c66c41c8bbc009cd0efa76c79502532af85f66
passes:

- corrected source transaction O0/O2;
- A9 surface-connected top input;
- A10 rapid drainage;
- PERCH20 transaction continuation;
- PERCH20 restart lifecycle.

The older synthetic active MIGMAC01 fixture still reports zero covered transfer
and a dry covering-node solution. It is retained as a diagnostic fixture rather
than counted as source-backed evidence. The new source-backed fixture is the
authority for MIGMAC01 qualification. No historical negative evidence is
rewritten.

## G6 disposition

G6 is resolved for the source-backed route. Stable constitutive water-content
increments reduce the limiting compartment residual below the native gate.
The remaining pre-repair head failure was not a floating-point ULP floor.
It was removed by migrating the historical B1.11 short-step macropore iteration
policy, without changing tolerances, forcing or dt.

## G7 remains open

The persisted last-rate comparison still gives:

- source last-rate OTHER = -0.93712357615042141 cm/day;
- SWAP5 re-evaluation OTHER = -0.93906608545092640 cm/day;
- absolute difference in the OTHER sum about 1.9425e-3 cm/day;
- maximum node difference about 9.1393e-4 cm/day.

This discrepancy is no longer a convergence blocker: the source-backed active
transaction converges, closes mass and replays exactly. It is nevertheless not
yet attributed tightly enough to call the migration fully production-admitted.

The leading hypothesis remains state/carrier timing: the persisted B1.11
last-rate vector is a last nonlinear-iteration receipt, whereas the current
SWAP5 diagnostic reconstructs the rate from persisted matrix heads plus the
accepted-origin macropore carrier. A source last-rate macropore-state/carrier
capture is required to distinguish this from a remaining operator mismatch.

No tolerance relaxation, fixture tuning, head tuning or physics change is
authorized for G7.

## Governance

Implemented: TRUE
Persisted: TRUE
Source-backed direct qualification: TRUE
Source-backed transaction qualification: TRUE
A9/A10/PERCH20 preservation: TRUE
G7 exact last-rate attribution: FALSE
Production admission candidate: FALSE
Canonical admission: FALSE
Closeout: FALSE
