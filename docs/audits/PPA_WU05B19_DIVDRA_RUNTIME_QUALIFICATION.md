# PPA-WU05B19: bounded signed frost/DIVDRA runtime

Status: implemented, locally persisted, tested and locally qualified.
Not canonically admitted. Aggregate frost migration remains open.

Baseline: `e5eab995ef04fc813dd644025fb0f32e4f5050a1`.
Final candidate production tree: `24fda78fd9a38964c16c89d5505b0056185ac410`.
The preregistered [runtime contract](PPA_WU05B19_DIVDRA_RUNTIME_CONTRACT.md)
owns the bounded interface. `integration/audits/PPA_WU05B19_STATUS.json`
owns recovery; `PPA_WU05B19_SOURCE_REVIEW.json` remains the historical source
review and is not an implementation status record.

## Implemented behavior

An explicit default-OFF physical selector and immutable B18 parameters enable
single-level signed scalar drainage or infiltration. Ordinary rootless
serialized Reference with constant prescribed bottom mode 2 regenerates the
frost geometry and nodal proposal from each immutable trial-start hydraulic
and thermal state. Positive scalar denotes soil-to-drain outflow. The runtime
supports the existing admissible normal and low-air B18 branches and its
explicit separate-infiltration option.

The final nodal proposal feeds the existing source/sink provider. The final
bottom proposal feeds the existing boundary. There is one mass ledger.
Observation provenance records the raw scalar, starting GWL, geometry,
component result, final signed nodal exchange and actual native trial duration.
Full and half endpoint assessment independently regenerates both proposals
and rejects domain, blocking, low-air or deepest-node disagreements. Existing
head and temperature budgets remain separate numerical policy.

Parameter and forcing validation are shared by the backend and application.
Distribution grid, compartment thickness/bottom and default-MvG saturated
conductivity must match column-owned parameters exactly. Mixed materialized
drainage rows, response controls, nonzero root/irrigation sources, nonfinite or
tiny nonzero scalar inputs and old dynamic bottom control carriers are held
before solver execution. Dynamic mode-2 controls are explicitly excluded:
otherwise the initial boundary and endpoint regeneration could use different
bottom owners.

Production changes are restricted to the backend, application preflight and
an additive public B18 validation wrapper. B18 arithmetic, positive-only
DIVDRA wrappers, solver arithmetic, physical state, transaction semantics and
restart schema are unchanged.

## Local verification scope

The final runtime matrix has 24 independently launched trajectories at each
optimization: scalar -0.01/0/+0.01 cm/day, both bottom signs, normal/low air,
separate infiltration OFF/ON where applicable, and blocked/unblocked geometry.
Each trajectory executes actual adaptive full/half rejection, an independent
8,192-step continuation, literal scalar/storage checks, fresh worker replay,
empty-registry restart with continuation identity, and the real application
initialize/run/close lifecycle. Four trajectories also run 16,384-step fine
continuations at both optimizations. All O0/O2 stdout is byte-identical.
Twenty-eight invalid owner/domain configurations are checked through both
runtime and application, plus an unbracketed frozen geometry rejection.

The largest runtime hard-mass residual is `6.357028220680913e-15 cm`, below the
unchanged `1e-12 cm` gate. Independent cumulative head/temperature comparisons
use the preregistered `1e-6 cm` and `1e-4 C` envelopes over `1e-4 day` intervals.
Their observed maxima are `2.125502e-8 cm` and `3.074508e-5 C`, respectively.
This is short controlled-interval qualification, not a long winter simulation
or a performance claim.

The declared preservation gates use complete freshly compiled modules:

All declared local gates passed on the final production tree. Preservation
contains 32 normal and 48 low-air complete original executions, with full
O0/O2 byte identity and the original immutable output comparisons.

| Gate | Completed evidence |
| --- | --- |
| B18 corrected scientific reference | 4,536 inputs per optimization, 3,240 accepted, 1,296 original tiny-scalar holds, 32 invalid domains and two actual-reference boundaries; unchanged arithmetic proof |
| B1 through B15 normal | 32 original complete process/family executions, O0/O2 identity and original immutable output comparisons |
| B8/B10/B11 through B15 low air | 48 original complete process/family executions, O0/O2 identity and original immutable output comparisons |
| Adjacent runtime | Immutable VQ73/VQ74, original full FAPP09/VQ128, four salt/root/frost method/dispersion variants with fresh-process restart and physical bit identity |
| Root and drainage science | Literal root 330+12 cases, extended 1,507 cases, analytic 148 cases with 132 derivative checks |
| Integration and documentation | Exact final source-tree moving-canonical guard, docs source checks and strict MkDocs |

The B18 corrected-reference maximum nodal error is `5.898059818321144e-17`;
maximum scalar error is `1.387778780781446e-17`. Its isolated scientific scope
does not itself establish runtime admission.

## Negative evidence and limits

An early wet low-air test assumed every last native trial lasted exactly
half the requested interval. Actual adaptive subdivision disproved that test
assumption. Provenance now exposes actual native trial duration and tests use
it. Final low-air initial heads form a hydrostatic near-wet profile. The old
failed output is retained; no production mass or temporal budget was relaxed.
High rejection counts remain evidence of cost, not a speed guarantee.

The final adjacent replay also encountered loss of the scratch executable's
owner execute bit between fresh-process invocations. Its failed log is
retained. The harness restores that bit only on the test executable it linked
before each invocation; the complete matrix is then rerun.

An attempted increase to twelve concurrent low-air processes exceeded this
environment's 8 GiB memory limit. The cgroup reported seven OOM kills; several
programs ended without their final PASS marker or completed receipt. Those
partial outputs do not establish qualification. The groups were stopped and
all uncompleted programs relaunched with a shared maximum of four heavy
processes across both optimizations.
Complete existing cases are reused only after source, executable and stdout
hash verification. Memory observations and partial logs remain negative evidence.
The bounded rerun completed all 48 original low-air executions without a
further OOM kill; the seven earlier kills remain recorded failures.

Excluded scope remains root/salt/snow/macropore hybrids with this new selector,
external surface or thermal coupling, trajectory/history routes, multilevel
distribution, unbracketed geometry and B18 unavailable component domains.
This work does not introduce ice-water phase change or latent heat physics.
Existing admitted routes are preserved independently; passing their tests
does not enable their combination with this selector.

## Reproduction and admission boundary

Use the versioned build, qualification, preservation, adjacent and component
scripts under `tests/frost/*ppa_wu05b19*`. Build each normal/low-air module
closure from committed production source at O0/O2. Run qualification on the
consistent low-air grid build and adjacent tests on the ordinary normal-grid
build. Preservation can split optimization runs into fresh process groups;
the evidence collector verifies every receipt, complete counts, binary and
stdout hashes, current source identity and final O0/O2 output identity.

`collect_ppa_wu05b19_evidence.py --scratch <absolute scratch path>` refuses to
seal qualification if any declared gate is incomplete. `--partial` explicitly
creates a recovery record with incomplete gates and no qualification claim.

The final source-bound evidence is
`docs/audits/evidence/PPA_WU05B19_LOCAL_REPLAY.json.gz`; its SHA256, gate
results and measured maxima are recorded in
`integration/audits/PPA_WU05B19_QUALIFICATION.json`. The earlier
`PPA_WU05B19_PARTIAL_RECOVERY.json.gz` remains historical partial evidence.
Documentation checks are rerun after this final report and contract update.

Local implementation, Git persistence, testing, qualification and canonical
admission remain separate states. GitHub push and PR publication are blocked
by automatic approval review pending explicit user authorization. No remote
persistence, PR, merge or canonical admission is claimed here.
