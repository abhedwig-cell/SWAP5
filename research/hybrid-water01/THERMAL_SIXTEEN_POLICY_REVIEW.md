# Explicit sixteen-step heat policy

This successor adds explicit numerical count16 to the existing instance-local
one/four policy. It retains the original implicit heat solves, calculation order
within each solve, integrated conductive faces and all acceptance tolerances.
Default1 and admitted4 remain available. Sixteen requires the same positive
temporal budget; invalid configuration is atomic, activation locks the policy,
and initialization resets it. The native profile is
`thermal-subcycle16-1e-5C`, with selector `thermal-control-16`. The public launcher
accepts all three thermal profiles. The physical restart codec is unchanged;
immutable binding refuses checkpoints from either other policy. External clients
explicitly reconstruct their numerical policy before continuation.

## Source and qualification

Base canonical: `3e7c838ba1c98ed8d59d4fe33c750c666ce3d357`.
Complete model/test postimage: `dc44cfa69053e3f8dc0117b2de3d704039522f4d`.
Actual hosted qualification head: `aad0ddc4c5d0dc341a7efc36bd4857fbd1e68564`.
Subsequent changes only concern evidence, documentation, timing adapter and
workflow routing; all src/app/tools/tests/reference bytes remain identical to
that successful CI head. Selection and exact archive identities are in
`integration/f-ci/THERMAL_SIXTEEN_POLICY_ADMISSION.json`.

- Cold Windows and Ubuntu26.04 O0/O2 real heat owners pass count4/16,
  original default1, six boundary cases, face/state agreement, unchanged
  per-cell/global energy, A/B/A and refusal assertions.
- Current full Reference runtime O0/O2 drivers pass, including actual backend
  setter/reset, active-policy locking and strict temporal refusal/rollback.
- Original-input native16 O0/O2 own day1-to3 process restarts are exact on each
  platform: all suffix water/crop/conductive rows, complete checkpoint and final
  physical files. Each has ten malformed-stream, six invalid-profile and two
  same-source foreign-policy refusal controls. Public launcher3days passes.
- Current one/four four-day physical files reproduce prior raw gold exactly on
  each platform. Windows16 O0/O2 physical files also match exactly; no Linux
  cross-optimization or cross-platform binary restart compatibility is claimed.
- Hosted policy run [43047199930](https://github.com/abhedwig-cell/SWAP5/actions/runs/43047199930)
  and focused F-CI run [43047203832](https://github.com/abhedwig-cell/SWAP5/actions/runs/43047203832)
  succeeded. F-CI executes the actual frozen application predecessor, six current
  production O0/O2 cases and current selector. Full moving replay was explicitly
  unselected. The incidental KIM job is not inherited as admission evidence.

The initial new runtime fixture expected a successful16 trial, but admitted4
also refuses that same fixed-flux exact-identity water history. A shorter
interval did not change this. The final fixture explicitly verifies strict
temporal refusal, no candidate publication, committed-state preservation and
active16 lock. All pre-existing application assertions remain. Positive16
commits are demonstrated by the actual native original-input runs. The initial
failed logs and diagnostic sources are retained; no tolerance or model fix was
used to conceal that fixture error.

## Bounded runtime and physical results

Serial Windows GNU16.2 O2 four-day ABBA execution uses identical original five
input files, compiler, flags and utility library. Median native wall time falls
from7.938734350 to5.138368100seconds (35.2747percent), and accepted water steps
from3585 to2134. Both repetitions of each arm are deterministic. The16 own2-to4
restart reproduces all suffix rows and the final complete checkpoint exactly.
Executable SHA256 for16 O2 is
`6d320dfbe75cf270eea1d7dc75c86322d9dfb61854ba9c34758830558e158b72`;
checked O0 is
`9674b0f273a1b322c99b61f96b76547e199c27d78e71ffec922d80aa89cf68aa`.
This is ambient-host short-window evidence, with a different accepted time grid.
It is not a cross-arm byte-identity or full-project speed guarantee.

The independent audit retains unchanged daily water/uptake and conductive
assertions. Maximum native three-day water residual is2.306e-14cm on Windows,
1.520e-14cm on Linux O2 and2.051e-14cm on Linux O0. This conductive bookkeeping
does not qualify complete surface energy.

The standard Windows preservation adapter expected per-case RESULT.json, while
the ABBA producer stores actual return codes and hashes at its root. Its initial
FileNotFoundError is retained. The independent audit checks the actual A1 event,
root hashes, original archive digest and all five raw gold files directly; no
report was manufactured and no model rerun was required. Linux's original
standard preservation checker passes.

## Retained reproduction evidence

The Windows capsule retains5771 hashed members and4191 checked source/object/
module/library identities. The Linux capsule retains all6443 original transport
members plus raw Git sources and metadata (6743 hashed members), with5011
identity checks. They include executables, BUILD manifests, input hashes, raw
outputs, compile/native commands and logs; complete focused F-CI decoded logs
are in `thermal-sixteen-focused-fci-20261111.log.gz`.

| Capsule | Bytes | SHA256 |
| --- | ---: | --- |
| `thermal-sixteen-policy-windows-20261111.tar.xz` | 60699028 | `65d61fac85538e75e9c06402fcc6e91832da96c1d108fe09de9a16a1d7e88480` |
| `thermal-sixteen-policy-linux-20261111.tar.xz` | 44501504 | `6a1007a1cb8d53a969df1e32af2f9bcc877ab425a8c7edd576d0fbea9a264fff` |

Read-only reproduction (no model reruns):

```sh
python -B research/hybrid-water01/audit_thermal_sixteen_policy.py \
  --windows research/hybrid-water01/thermal-sixteen-policy-windows-20261111.tar.xz \
  --linux research/hybrid-water01/thermal-sixteen-policy-linux-20261111.tar.xz \
  --output /tmp/thermal-sixteen-policy-reaudit.json
```

Published `thermal-sixteen-policy-reaudit.json` records independent PASS.
Native start commands and elapsed times are retained in the selection record's
`windows_timing.events`; build and O0/O2/native/refusal recipes are retained in
the capsules and owning workflow. No checkpoint binding is rewritten.

Functional coverage: an explicit numerical execution option and public profile,
not an additional completed historical project. Reliability: cold O0/O2,
platform-own exact restart, policy isolation/refusal, physical balances and
preserved default/four routes. Development return:35.3percent shorter bounded
native window with no new full trajectory and no long new diagnostic campaign.

The previously qualified full1827-day four-step trajectory remains its exact
source/build scope. No full16 trajectory is admitted here. The original failed
Grass day188 oxygen comparison and unresolved residual, Hupsel day584 reference
qualification, whole scientific equivalence, complete energy and runtime parity
remain open. Next delivery after canonical admission is one explicitly selected
original16 full trajectory with frozen release identity, daily balance audit and
own wet/year/final restart cuts; the existing4 stream must never be rebound.
