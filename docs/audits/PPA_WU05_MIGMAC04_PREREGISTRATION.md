# PPA-WU05-MIGMAC04 characteristic-point shrinkage input

Date: 2026-10-05. Preregistered before production edits.
Canonical base: 23bcc2925b22ab129a8a3bc4597ce616e4f0dd58.
Local ff143716c tree f67aa3e6e0250e017b9edc23f5b878c00c84dd7a is identical.
Exact B1.11 macropore SHA256 f44049c551b5206ada58f1bb150bc250c5502171e49568a7ad8f01eed7bf106f.

Scope: Kim clay input2 and the uniquely determined regular Hendriks peat input2
branch from characteristic ratios. Preparation is immutable configuration work,
not a new physical state, optimizer or runtime owner. Prepared laws enter the
existing admitted constitutive/geometry/Reference transaction chain.

Clay SHRINKPAR(2) solves A*(1+v*beta)*exp(-v*beta)=0. For finite parameters,
the exact root is beta=-1/v, gamma=1-A*exp(1)/v; transition=v. This eliminates
the legacy unbounded Newton loop and its derivative-zero case A=v. Retain
source A<=v and transition<=theta_s/(1-theta_s)-0.01.

Peat SHRINKPAR(4) uses c1=transition/peak, c2=typical/peak and
c3=(target_void/baseline_void-1)/P. Target void is e0+typical for P>0,
and 0.5*e0+typical for P<0. Solve
c2^alpha*(exp(-alpha*c2)-exp(-alpha*c1))/(exp(-alpha)-exp(-alpha*c1))=c3.
For 0<typical<peak<transition this relation decreases strictly with alpha.
Use stable scaled exponentials and a bounded 80-iteration bracket on [0.001,10],
then beta=alpha/(peak/transition). Require resulting direct law valid.
Fit scope: e0>=0, all ratios finite, transition<saturation, typical>=1e-8,
peak/transition>=1e-5, 1e-8<=abs(P)<=10. This is a bounded regular branch,
not admission of all permissive legacy reader ranges.

For typical=peak the equation is independent of alpha and is non-identifiable.
For typical>peak it need not be monotonic and can have two roots; reject this
branch rather than choosing an undocumented Newton seed. P=0 supplies no alpha
information through this target equation. Out-of-bracket roots fail closed.
No fitting tolerance or iteration budget may weaken water or Richards tolerances.

Gates: fixed high-precision parameter oracles; independent constitutive residual
and target-point reproduction; clay endpoint/continuity; positive/negative P;
non-identifiability, absent roots, NaN and A=v derivative-zero boundary; O0/O2;
prepared-law Reference growth, contraction/displacement, rejected smaller retry,
A/B/A and accepted restart; existing MIGMAC02/MIGMAC03 and A8/A10/MIGMAC01/PERCH20
preservation. Persist source postimages, negative findings and bounded admission.

Numerical fit contract: require residual <=1e-13*max(1,abs(c3)) and parameter
bracket width <=1e-12*max(1,abs(alpha)); require the bracket's shape variation
>1e-10 so nearly flat, numerically unidentifiable data fail closed. The target
void point is independently checked to 1e-12 after parameter construction.
