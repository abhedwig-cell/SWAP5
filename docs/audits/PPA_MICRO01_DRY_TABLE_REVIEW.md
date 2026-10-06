# PPA-MICRO01 exact-source dry-table review

Status: source-inspected, executable qualification blocked. No production or
reference change and no MICRO admission.

Canonical recovery baseline: `ca856e88e582d468a6f40971ce1f2a75e5089c40`.
EXACT01 Jarvis/Walsum remains admitted. Its two process modules and the exact
MICRO source member have no delta since the EXACT01 closeout. The standalone
MICRO migration is separate from external Jarvis/Walsum compensation.

## Exact source finding

`reference/swap-4.3.1/b1_11_frost_source/SWAP/RWU_micro.f90` has SHA256
`cac3d723cc11fb001878d53f2747bbff9fd53fb22949b682906df4361cb90477`.
In `get_MFLP_K`, the initializer sets
`start=int(100*log10(20000))=430`, sets `M_table(430)=0` and fills M and K
only at indices 429 down to 1. It does not initialize `M_table(431)` or
`K_table(430:431)`. At `h=-20000`, the rate branch does not take its strict
`h < -20000` zero branch. Its interpolation count is 430, so the unchanged
routine reads those uninitialized cells. The affected dry interval includes
`[-20000, -10**4.30]`, approximately `[-20000, -19952.62315]` cm.
This is a source-level definedness defect, not proof of any particular value
returned by an actual historical allocator or complete model run.

The prepared [component replay](../../tests/physics/run_ppa_micro01_dry_table.py)
extracts the original routine without changing its bytes. Explicitly synthetic
constant-K dependencies isolate table construction and lookup. Three finite
realizations of only uninitialized cells are tested at the dry boundary and
inside the gap, with below-cutoff, normal-table and wet controls. O0/O2,
bounds checking and floating-point traps are mandatory. The sentinel experiment
does not pretend to reproduce the actual allocator's historical memory.

## Other migration boundaries

The exact initializer rejects `swDoSatRel=1`, even though the input reader
allows 0 or 1. Its default is 0. MICRO frost calls a fatal unsupported-option
error before a later unreachable frost-reduction block. Hydraulic lift can
produce signed node exchange and is not equivalent to the current nonnegative
root-removal-only receipt. These options must not be silently promoted to
working SWAP5 physics. Global SAVE arrays, public numerical controls, hydraulic
tables, current root/leaf potentials and input reading require explicit
parameter, worker-scratch and result ownership before production migration.

## Execution blocker and recovery

The component replay was attempted but could not launch `gfortran`:
`FileNotFoundError: No such file or directory: 'gfortran'`.
No executable case completed. A normal `apt-get update` followed by compiler
installation failed before installing anything, with `setgroups`/`seteuid`
permission errors and an HTTPS method failure. No permission bypass attempted.

Required next action: run the persisted component gate in a Fortran-capable
authorized Work environment, save its result using `C3A_RESULT`, then decide
the corrected reference boundary before migrating the full MICRO equations.
A repair must explicitly choose the intended dry integration endpoint and
initialize every accessed M/K bracket. Uninitialized output is not a valid
preservation target. Do not claim corrected physics or reference admission
until that policy and its numerical evidence are qualified.

The existing production water/salt owner, numerical policy, transactional
state and restart schema are untouched. This review is not a full MICRO
qualification, seasonal equivalence claim or frozen Status-A change.

## Necessary executable fallback

The local compiler blocker remains. One branch-scoped GitHub Actions component
replay is prepared in `.github/workflows/ppa-micro01-dry-table.yml`, using an
Ubuntu Fortran runner. Its O0/O2 evidence must complete and be inspected before
any executable confirmation claim. No production/reference changes are made.
