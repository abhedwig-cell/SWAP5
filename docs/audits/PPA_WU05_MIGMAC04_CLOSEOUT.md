# PPA-WU05-MIGMAC04 characteristic-point input closeout

Date: 2026-10-05. Status: CANONICAL_PRODUCTION_ADMITTED_CLOSED.
Canonical base: 23bcc2925b22ab129a8a3bc4597ce616e4f0dd58.

Two configuration preparation routines supply the existing admitted constitutive
carriers. No new water/state/restart owner or candidate parameter mutation exists.
Kim input2 solves the exact source fit equation analytically: beta=-1/v,
gamma=1-A*exp(1)/v, transition=v. Finite positive A<=v and the source saturation
margin remain required. Exact B1.11 SHRINKPAR divides by zero when A=v, confirmed
with SIGFPE on O0 and O2; this permitted boundary now succeeds analytically.

The regular Hendriks input2 branch solves the exact B1.11 characteristic-point
residual using scaled exponentials and bounded bracketed iteration. Admitted input
order is 0<typical<peak<transition<saturation. Typical>=1e-8, peak/transition>=1e-5,
1e-8<=abs(P)<=10; alpha lies in [0.001,10], and resulting beta/alpha obey the direct
law's existing validity limits. The shape must vary by more than 1e-10 across the
bracket. Both residual and bracket-width criteria apply; a target-point void-ratio
check follows. Invalid, unidentifiable or out-of-bracket data fail closed.

For c1=2, c2=1.5, c3=0.55 the exact same source equation has alpha roots
0.7153960197508256 and 5.740840216514610. Therefore the branch typical>peak is
not silently assigned a Newton-seed-dependent root. Typical=peak and P=0 also
provide insufficient alpha information. Broader fitting requires a separate
selection/identifiability contract, rather than a hidden continuation state.

Independent 70-digit Decimal roots, direct unscaled source residuals, constitutive
continuity and target-point checks pass at O0/O2. The exact legacy preparer produces
small parameter differences (clay beta 7.4551706e-8, peat alpha <=2.7142682e-7) due
to its coarse 0.001 stopping rule; no bitwise legacy parameter equality is claimed.
The new root residual is <=1e-13*max(1,abs(c3)), bracket width <=1e-12*max(1,abs(alpha))
and target void error <=1e-12. These preparation criteria do not change Richards
or total-water tolerances.

Reference runtime exercises prepared clay and positive/negative-P peat laws:
dry growth, coherent wetting/contraction with displaced water entering the matrix,
reject/smaller retry, A/B/A, accepted-boundary restart and byte-identical O0/O2.
Direct Kim/peat/rigid and existing two-domain rapid-drain routes are preserved.
Exact source/test manifests and completed controlling gates belong in
integration/audits/PPA_WU05_MIGMAC04_QUALIFICATION.json before admission.

Excluded: ambiguous or nearly unidentifiable fitting branches, mixed Kim/peat
runtime and new mixed-law rapid-drain reference construction, broader coupling,
whole-model case equivalence, RossFast and concurrent MultiSWAP.

A8/A10/MIGMAC01/PERCH20 and MIGMAC02/MIGMAC03 controlling preservation gates
all pass at O0/O2. Initial A8 compile-directory failure and its successful serial
retry remain separately recorded; no numerical tolerance was changed.

## Canonical admission

PR #1021 merged the exact qualified tree `2fa27d985ddd1331a8043153432f78da5e672dc8`
at `ce6a85f11d4eb8d7234802745353e4c951581d96`. Published qualification commit:
`84a1032298822df1656c99aaa968b17f75f9d5ec`. All 35 source/test postimages match.
The closeout changes only documentation and status records.
