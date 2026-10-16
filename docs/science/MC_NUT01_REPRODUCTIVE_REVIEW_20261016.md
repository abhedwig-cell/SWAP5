# MC-NUT01 reproductive, translocation and death assessment

Status: completed source assessment with bounded executable discriminators;
**no reproductive production admission**. Baseline canonical
`1c28da44ba0ddf0cdb10be5930c5f6b8de33f9c8`, after SOL PR1258.
The existing vegetative B1.11 request admitted through PR1253 at
`c9e5efad50cf6cf18342a57efbee398260fdce82` is preserved. Its request binding,
configuration, day application and WOFOST81 nitrogen provider remain byte-identical
to that admission. Recovery and evidence: `MC_NUT_SOL_STATUS.json`, section
`reproductive_review_20261016` under `integration/audits`.

## Source and scope

The immutable B1.11 component capsule contains complete `literal/wofostnut.f90`,
SHA256 `071e65763be9e771b32b417252584d50874715d9ff11d3482c131826cc80bbb2`.
The assessment executes its literal demand lines354..370 and update lines197..255
against the real current `MOD_wofost81_nitrogen` request/apply provider. Eight
executions are not implied: four discriminators run inside each of two O0/O2
programs. The closure is one unchanged production provider, a literal oracle and
a small review driver; all inputs, flags, outputs and costs are archived. This
establishes semantic differences and algebraic counterexamples, not a qualified
crop trajectory, new production policy or full B1.11 equivalence.

| Process | Literal B1.11 | Current accepted WOFOST81 / PR1253 | Assessment |
| --- | --- | --- | --- |
| Storage demand | `(NMAXSO*WSO-ANSO)+`, divided by TCNT; separate from leaf/stem/root demand | Storage and growth terms belong to WOFOST81 request; selected1253 deliberately discards them | Reproductive source policy must handle storage demand and DVSNT explicitly; extending the vegetative gate is insufficient. |
| Translocation onset | Storage supply becomes available at DVS >= DVSNT; soil/fixation uptake separately gated by DVSNLT and RELTR | WOFOST81 has its own onset;1253 refuses DVS at/after that onset | Keep the two source thresholds distinct; do not remove1253's guard. |
| Root donor | `max((ATNLV+ATNST)*FNTRT, ANRT-WRT*RNFRT)` | Positive actual root surplus above residual; no FNTRT term | An explicit source profile and donor-domain decision are needed. |
| Partition cutoff | Translocated donor rates remain zero at ATN <=1e-5, while storage supply may remain positive | Translocation partitions at positive total | Independently reject nonconserving active cutoff cases in any future bounded profile. |
| Death N | Residual concentrations RNFLV/RNFST/RNFRT times organ death dry matter | Current organ N concentration times death dry matter | A different apply policy is required; replacing the request alone cannot implement this. |
| Same-step depletion | Original updates clip negative living organ N to zero | Current apply limits translocation by surviving N after senescence | Literal donor overdraw needs an explicit reference/domain decision before production use. |
| Dead-material return | Original lines258..269 split roots and deceased leaves, retaining explicit fraction and cumulative losses | Existing delayed material owner and daily whole-N contracts remain authoritative | Reuse that owner; assess the leaf return fraction and export split before claiming historical return equivalence. |

## Executed discriminators

All rates below use a one-day interval and kg N/ha; residuals are whole-N gains
computed independently from initial organs, final organs, supplied/fixed N and
reported loss. These are deliberately discriminating algebraic states. Their
reachability in a complete crop trajectory has not been established.

| Probe | Literal B1.11 | Actual WOFOST81 | Consequence |
| --- | --- | --- | --- |
| Safe reproductive donors, FNTRT=.25 | Root translocation .08; whole-N gain0 | Root translocation .01904761904761905; residual0 | The two policies differ even in a conserving case. |
| Large storage demand, same donors | Root transfer2 from an initial root pool .5; final clipping creates gain1.5 | Applied root transfer .4; whole-N residual0 | Literal clipping cannot be copied as a conserving production rule over unrestricted inputs. |
| Leaf death10 at live leaf N concentration .05, residual .01 | Leaf N loss .1 | Leaf N loss .5 | Death semantics need independent review and material-return accounting. |
| Positive translocatable total2e-6, below the source cutoff | Storage is credited2e-6 while donor transfer remains zero; gain2e-6 | Whole-N residual0 | Small active translocation requires fail-closed treatment, like the already bounded vegetative small-demand exclusion. |

O0 and O2 produce identical raw discriminator outputs. The actual WOFOST81
request/apply status and independent balance pass in all four probes. The source
counterexamples are observed **failures of unrestricted literal conservation**,
not a claim that the complete legacy model reaches those states or that its
scientific reference has been formally declared defective. No tolerance is
relaxed and no donor clipping or invented correction is admitted by this review.

## Dependency-ordered implementation decision

Proceed within MC-NUT01 with a separately selectable source profile; preserve
WOFOST81 as default and preserve the exact vegetative1253 profile. The first safe
implementation unit is a small real process contract for reproductive storage
supply, FNTRT root donors and residual-concentration death together: they debit
the same organs in one day and cannot be qualified independently as additive
exports. Use the literal source order and explicitly refuse active small-cutoff
or donor-overdraw cases before mutating accepted state. This is a proposed
bounded domain, not authority to silently change the historical equations.
A broader correction to reachable source defects needs its own reference-policy
qualification decision; the current algebraic probes alone do not settle that.

Then compose the selected prepare/apply policy with the existing crop/Soil-N
transaction, its one fixation input and soil debit, and its existing pending
residue owner. Explicit immutable identity must carry DVSNT/FNTRT and the chosen
residual/TCNT/return-fraction semantics. Existing native/opaque continuation must
retain that identity, organ N and pending material; introduce no second N owner
or sidecar. Whole soil+live crop+pending N counts incorporation as internal and
external loss only once. Senescence PR1239 is actually merged at
`3b661766dc59298a7f541c970c2d3a55602d926c`; its frozen premerge status flag is not
a reason to rebuild that owner.

Require focused O0/O2 source-order leaf tests first, then real daily state,
whole-N, threshold/overdraw refusal, rejection/retry/replay and fresh-process
restart. Actual coupled Richards and original default/1253 programs are selected
only after the policy is executable. No full FCI, alternative solver, highest
low-air or unrelated numerical qualification is selected for this read-only source
assessment. Full master coverage and capability dispositions do not change.
