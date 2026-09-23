# TAB-HYD generated K0 provider — production work-unit start prompt

Use this prompt in a **new, separately owned production chat/work unit**.

---

Ga verder binnen repository:

`abhedwig-cell/SWAP5`

Werk rechtstreeks met de GitHub-connector.

## ROL

Deze chat is exclusief eigenaar van de bounded production work unit:

**TAB-HYD-K0-PROD01 — generated MvG-equivalent constitutive provider**

Dit is een productie-implementatie- en kwalificatielijn.

Heropen de afgesloten TAB-HYD representatie-research niet tenzij een production gate de frozen candidate daadwerkelijk falsificeert.

Geen generieke user-supplied tabellen.
Geen herstel van legacy `SWSOPHY=1` als productiearchitectuur.
Geen `SWKIMPL=1`.
Geen nieuwe hydraulische physics.
Geen solver-policy redesign.
Geen tolerantie-retuning voor performance.

## STARTAUTHORITY

Reconcile bij aanvang opnieuw vanaf de actuele:

`integration/f-ci-canonical`

Laatst gereconcileerde canonical bij handoff:

`a2d99ddd149ffaa422d9c422f96bd66e92c8555d`

De controlling TAB-HYD research handoff staat op:

`research/tabulated-hydraulics-characterization`

Handoffdocument:

`research/tabulated_hydraulics/GENERATED_K0_PROVIDER_PRODUCTION_HANDOFF.md`

Research closeout:

`research/tabulated_hydraulics/RESEARCH_CLOSEOUT_20260923.md`

Laatste authority-clean handoffcommit:

`f66d713214109f8c426dd8e5cb073b72111302ea`

## FROZEN RESEARCH CONCLUSION

De generated typed K0 raw-head table-provider acceleration is research-qualified.

Controlling evidence omvat:

- provider-only raw-head400 typed evaluation: ongeveer 19% lager constitutive evaluation cost;
- real Reference-Richards K0 solve: materiaal lagere runtime met gelijke nonlinear/linear solve counts;
- serialized Reference runtime: materiaal lagere hot-loop runtime met gelijke retries/iterations en mass preservation;
- dynamic prescribed-qbot transaction/temporal-certificate fixture: PASS;
- generic timestep-context capability: PASS;
- preprocessing break-even: ongeveer 8,860 30-node vector evaluations;
- bounded F-SI39/KSATEXM extension: KX05/KX06 research-qualified.

Gebruik deze resultaten als handoff-evidence, niet als productie-admission.

## FROZEN REPRESENTATION

De eerste production candidate blijft exact:

1. 400 gegenereerde pressure-head rows per actief hydraulisch materiaal/node;
2. raw/physical pressure head `h` als runtime interpolation coordinate;
3. `ln(K)` als conductivity ordinate;
4. TSPACK preprocessing buiten de nonlinear hot loop;
5. explicit analytical wet theta/C continuation;
6. explicit Ksat plateau / branch semantics;
7. constant dry extension;
8. bounds-safe interval location;
9. immutable preprocessed provider state;
10. deterministic generation vanuit admitted typed MvG parameter authority.

Niet retunen op basis van benchmarkresultaten.

## TIMESTEP-CONTEXT CONTRACT

Research TAB-HYD-CTX01 selecteert:

`context_compatible(step_duration) -> logical`

Production semantics:

- non-deferred base implementation: fail closed;
- analytical MvG override: valideer bound timestep;
- generated table override: valideer bound timestep;
- temporal-indicator owner controleert capability generiek;
- mismatch faalt gesloten;
- hot `evaluate(...)` ABI blijft ongewijzigd.

Geen concrete provider-type dispatch in temporal-indicator logic.

## PRODUCTIE-EIGENAARSCHAP

Immutable provider/table state behoort aan parameter/provider configuration.

Lifecycle:

`typed MvG authority -> validate -> generate once -> preprocess once -> immutable provider -> reuse across trials/retries`

Verboden:

- per-Newton regeneratie;
- per-trial regeneratie;
- committed hydrological state in provider;
- retry/accept/rollback decisions in provider;
- verborgen mutable physical state in lookup caches.

Analytical MvG blijft default/reference route.

Generated providerselectie moet typed, expliciet, opt-in en fail-closed zijn.

## KWALIFICATIELADDER

Werk in deze volgorde:

**G1 CONTRACT PRESERVATION**
- analytical route identiek aan current canonical;
- generic timestep-context capability fail closed;
- bestaande owner/compiler gates behouden.

**G2 DETERMINISTIC GENERATION**
- finite/monotone generated state;
- deterministic identical input -> identical provider state;
- no per-call allocation;
- immutable ownership bewezen.

**G3 PROVIDER CONSTITUTIVE**
- reproduce 30-Staring research envelope;
- frozen admission limits vooraf vastleggen;
- geen post-hoc tolerantiekeuze.

Research reference order:
- theta max abs ~5.32e-5;
- C max abs ~5.17e-5;
- log10(K) max abs ~3.04e-4.

**G4 REFERENCE RICHARDS**
- bounded coarse/loam/clay profiles;
- same convergence class;
- same linear-solve count unless independently explained;
- mass preservation;
- frozen trajectory error envelope.

**G5 SERIALIZED REFERENCE**
- provider-consistent initialization;
- accepted/retry semantics;
- mass ledger;
- unchanged ownership;
- bounded performance characterization.

**G6 DYNAMIC CERTIFICATE**
- reproduce FMR44R positive prescribed-qbot gate or current-canonical successor;
- temporal certificate beschikbaar;
- unsupported route blijft fail closed.

**G7 INITIALIZATION / AMORTIZATION**
- meet provider construction in echte owner;
- bewijs cache lifetime;
- reject per-trial rebuild.

**G8 WHOLE-HUPSEL**
- use existing M1-C3 exact whole-Hupsel authority;
- exact required distribution SHA-256:
  `2b48353db6cdf00246a1e5c0dcaafc2c61858729fad18446a1dc66359ec2a360`;
- geen reconstructed/public/synthetic substitute.

Deze gate is bij handoff extern geblokkeerd zolang exact authorized bytes niet materialiseerbaar zijn.

**G9 INDEPENDENT QUALIFICATION**
- no new physics;
- analytical reference preserved;
- provider selection fail closed;
- source/evidence/commit bindings compleet;
- geen overclaim van speedup.

## F-SI39 / KSATEXM

Voor de exact-Hupsel authority is een bounded KSATEXM sub-slice nodig.

Preferred research pattern: **KX05**, met KX03 als scientific oracle.

Controlling evidence:

- KX05 constitutive: run `35863485123`;
- KX06 solver/performance: runs `35863794528`, `35863919254`.

KX05 semantics:

- determine immutable first-active pressure head from the exact strict canonical authority predicate;
- store it as immutable metadata;
- runtime branch uses that metadata;
- no branch tolerance;
- no analytical theta/Se recomputation in hot path.

Widen deze extension niet buiten het expliciet gekwalificeerde F-SI39/Hupsel envelope zonder nieuwe preregistration.

## EXPLICIETE NON-SCOPE

Niet admitten in deze work unit:

- generic user-provided hydraulic tables;
- legacy `SWSOPHY=1` compatibility;
- `SWKIMPL=1`;
- generic KSATEXM parameter space;
- hysteresis;
- frost/macropore table semantics;
- non-MvG hydraulic families;
- inverse-table support;
- globale SWAP5/MultiSWAP speedupclaim.

## WERKWIJZE

Werk in grote zelfstandige blokken:

`RECONCILE -> AUTHORITY BINDING -> PREREGISTER -> IMPLEMENT -> QUALIFY -> ANALYZE -> REPAIR -> PERSIST -> ADMIT/CLOSE`

Checkpoints zijn repository-checkpoints, geen interactiemomenten.

Vraag geen toestemming tussen normale fasen.

Persist tussentijds.

Stop alleen bij:

- echte wetenschappelijke/architectuur/governance-keuze zonder bestaande authority;
- externe blocker;
- production gate die frozen research candidate falsificeert;
- of volledige work-unit closure.

## EERSTE ACTIE

1. Reconcile current canonical tegen de handoff.
2. Controleer dat de constitutive contract/provider/temporal-indicator/serialized Reference authority niet relevant is gewijzigd.
3. Maak een fresh production work branch vanaf current canonical.
4. Preregister G1-G7 en de exacte production delta.
5. Implementeer eerst alleen de generic timestep-context capability + generated K0 provider ownership/selection.
6. Houd analytical route byte-/behavior-reference intact.
7. Ga vervolgens zelfstandig door de qualification ladder tot G7.
8. Markeer G8 expliciet BLOCKED_EXTERNAL zolang exact authority bytes ontbreken; verzin geen substituut.

Doelstatus:

**PRODUCTION-CANDIDATE QUALIFIED THROUGH G7 / G8 EXTERNAL BLOCKER EXPLICIT / NO UNSUPPORTED ADMISSION CLAIMS**

---
