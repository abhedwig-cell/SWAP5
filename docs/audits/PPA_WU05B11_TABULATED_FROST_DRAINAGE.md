# PPA-WU05B11 tabulated frost drainage composition

## Status and authority

Canonically admitted via PR #1054 at `d975acb21472ddf96c800ef66be327810f8968c0`. This is a bounded
composition of admitted drainage laws with the admitted normal and guarded
low-air frost modifiers. It is not a complete frost migration claim.

Baseline is B10 closeout `febfff8103c4d60324a103d832521bb3f3754a67`, whose
actual production source is `60bc7fdc3430d8d8ae87f4a77219dbb6c44c6ec9`.
The source review and preregistration are versioned under
`integration/audits/PPA_WU05B11_SOURCE_REVIEW.json` and
`integration/audits/PPA_WU05B11_PREREGISTRATION.json`.

The table law remains the F-VQ40 normalized DRAMET1 response documented in
[Drainage-v1 formulations](../science/drainage-formulations.md). Its signed
rates are interpolated at the absolute original input groundwater level,
clamped outside the ordered depth range, and defined at exact knots. The
existing one-point depth-zero padding artifact remains excluded.

## Selected interface and ownership

`frost_tabulated_response_drainage_active` defaults to false. It requires the
existing frost response selector and at least one TABULATED level. Other
levels may use the admitted LINEAR response. Low-air additionally requires
the B10 selector and the existing finite negative physical drain depths with
matching level cardinality.

Validation follows the active level variant. A valid table ignores inactive
LINEAR resistance and control fields. The additive pure parameter validator
delegates the existing table validation without changing its evaluator,
interpolation, derivative, or status semantics. Selected runtime preflight
also rejects the existing unsupported depth-zero singleton before solving.

Each trial starts from the immutable physical input. Existing generation
produces an untouched disposable nodal proposal; the existing frost modifier
produces final node rates. Those rates enter the existing single solver sink
and accepted receipts. Bottom exchange retains its existing separate owner.
Rejected trials publish no physical state. There is no additional committed,
restart, or ledger state.

The finite-depth low-air implication remains explicit: a frost bottom below
the minimum physical drain depth blocks every level. Tiny or zero generated
rates with a surviving deepest drain retain bottom exchange; the small-total
threshold cannot independently override that geometric decision in this
SWDIVD0 scope.

## Verification boundary

The 768-case source matrix compares actual table evaluation with independent
interpolation/clamp formulas and corrected B7 `FrozenBounds` final-node and
bottom-exchange results. It covers table knots, clamps, signed/zero rates,
positive and negative groundwater levels, air-rich and low-air branches,
front equality and partial/all/no level cuts. O0/O2 output is identical.

Actual normal and low-air runtime fixtures check refined trajectories,
single mass ownership, final receipts, retries, application rejection, fresh
replay and empty-registry restart. An additional short actual-runtime matrix
covers signed tables, zero activation, mixed LINEAR/TABULATED methods and
changed original input groundwater level. Additional reference refinements
and fresh incumbent preservation are required before admission. Completed
and pending gates are distinguished in the versioned B11 status record.

Normal local head and temperature budgets are `1e-8 cm` and `1e-7 C`, with
solver head tolerances `1e-10`. Low-air uses the existing qualified B10
debug policy: `3e-11 cm`, `1e-7 C` and solver tolerances `1e-12`, on an owned
consistent nonuniform static/typed grid. Refined horizon limits remain
`1e-6 cm` and `1e-4 C`; hard water-balance closure remains `1e-12 cm`.
The expensive low-air retry behavior establishes no practical performance
claim.

## Exclusions

SWDIVD1 distribution, other generator families, fixed-weir and extended
signed exchange, root/salt/macropore/snow hybrids and new phase-change
physics require separate scope and evidence.

## Completed local qualification

All declared gates pass on production `cd7a56657fa3347ee63595a0f54274b2f1766ba8`. Both actual runtime routes, the72-case additional signed/mixed/GWL matrix, all incumbent frost runtimes, four expanded salt/frost matrices, immutable VQ73/VQ74, literal root cutoff oracle and complete canonical preservation pass. O0/O2 actual outputs are identical. Normal additional16384/32768 refinements and low-air131072 refinement pass; maximum added head error is3.147382e-7cm.

The first low-air fixture compile lacked a test import. The additional O2 activation screen then exposed uninitialized inherited LINEAR control heights in the generated matrix. Both fixture defects were repaired, explicitly initialized controls were persisted, and the complete additional matrix rerun at O0/O2 passed identically. No production change or tolerance relaxation was needed. Immutable partial recovery retains its explicit non-qualification status.

## Canonical admission

The proposed merge `95b978c0356cc64696fd9d66a345c1002d9a1328` and actual merge share the exact qualified tree `55584bf5c23c064be2d3983b19be185d4a8f1a40` and production source. The admission record retains parent/head/evidence identities. The next Hooghoudt/Ernst slice remains source review only. Aggregate frost migration remains open.
