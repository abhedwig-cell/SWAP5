# Current Hupsel51 repair workpoint

WORKSTREAM: original no-macro daily water solver; PR1686.
BASELINE: canonical3fb625da7 merged without conflicts into branch codex/hupsel51-water-balance; runtime source and all relevant hashes pinned in WINDOWS.json.
IMPLEMENTATION: bounded original coupled linear-pond Jacobian in daily_host.py/hybrid_step_budget.f90. No physical equation, mass limit, source forcing, numerical policy or persistent schema changes. Activation remains explicit experimental closed undrained/no-snow/lagged-K input; default/macro routes unchanged.
TESTED: current Windows generated donor/kernel O0 and O2 full1096; exact physical/CSV/native own50â†’52 and530â†’532;36 original scalar derivative checks per optimization. Three named full applications and native continuations PASS, with complete RC2 physical/source-image preservation. See WINDOWS.json and README.md.
QUALIFIED: Ubuntu26.04 run43844795787 terminalSUCCESS on composed runtime6e2cd26f873f9a935af92816a2f1d947df9293c7; full O0/O2, all native own windows and three named full cases PASS. CI_ADJUDICATION records unchanged historical F-CI/MC-SOL source predicates that also fail at the canonical parent. Do not repeat successful Windows runs while their dependency surface is unchanged.
EVIDENCE: WINDOWS_RAW.zip plus exact archive/member hashes, pinned input/compiler/object/writer identities and native endpoints. Original pristine431 partial/cap and corrected-tangent-only control retain separate status; whole science remains NOT_QUALIFIED. Frozen RC2 files untouched.
NEXT SAFE STEP: PR1686 review; no further runtime checks remain for this bounded repair. Preserve the baseline CI failures as separate source-authority/admission issues; do not repin historical evidence merely to make CI green. Do not mark an active CI job as completion or promote whole scientific equivalence.

## Preserved rejected investigations

3d54d0b06 added a projected receipt guard;2045873a2 made its reduction exact/fast. It passed51 but the elapsed-scaled version caused named-cost regressions and later dtmin433 nonconvergence with a0.053186346541cm candidate error. a1f4ed8e0 separated the full-day limit but did not provide practical full-period qualification. All are rejected research; production receipt helper was removed in48267be1c. Original HeadCalc's missing pond response was then corrected in the existing solver. Former code/raw evidence stays in history and C:\SWAP5-testing\hupsel51. Native rejected-state/unchanged-checkpoint evidence from the predecessor remains at C:\SWAP5-RC2\application-acceptance\new-variants-20261116\hupsel-reactive-undrained. No threshold tuning or physical clipping was adopted.

## PR1686 CI completion

Current CI forwarding now has a PR1686-only successor. The entire tested
runtime is unchanged from6e2cd26f; immutable evidence remains anchored at
4ee0e08b. Run tests/hupsel51/test_successor.py and the verifier,
then await the three updated CI jobs and merge with an exact expected head.
After merge verify canonical parents/runtime/tree and run a fresh bounded
actual canonical full1096/native-own and component O0/O2 check.
