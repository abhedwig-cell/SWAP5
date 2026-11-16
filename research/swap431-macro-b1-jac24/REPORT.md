# JAC24 — minimale Jacobiaan-aanvulling voor de GWL-/minimumvoorraadkoppeling

**Dezelfde oorspronkelijke node-52-headpoging convergeert met de lokale rang-één-aanvulling in twee iteraties, zonder fluxreductie.** O0/O2 zijn numeriek exact gelijk. De verse V1-certificering slaagt met maximaal compartimentresidu **4,121976510118586e-10** en somresidu **−4,873777744326188e-11**. De oorspronkelijke grenzen van 1e-6 en 1e-5 zijn ongewijzigd.

Dit is een **lokale head-PASS**, vóór een hostcommit. De aanvulling is niet vrijgegeven als algemene solver, volledige periodeoplossing of nieuwe referentie.

## Eén kandidaat, dezelfde oorspronkelijke context

Baseline is SENSE23 340a19b4f0ff09115ceafc39a39777ba1ca1250a; de current-operator-route en stopvorm komen uit FRESH22. De native aanloop gebruikt hetzelfde oorspronkelijke eigen V5-bestand op 35797. De eerste 36 geaccepteerde stappen, 37 headpogingen zonder timing, oorspronkelijke target_begin en uitgebreide context zijn exact behouden.

Alleen oorspronkelijke poging 38 krijgt de aanvulling: begin t1900=35797,070666666681, dt=0,0013333333333333333 dag, FrReduQ=1. Er is geen gewijzigd head geïnjecteerd en geen andere retry geselecteerd. De actuele macro-evaluatie uit FRESH22 blijft actief. De fysieke providervergelijkingen, GWL, voorraadgrenzen, native branchdrempels, V1, MAXIT=30, dtbeleid, reductieregels en BAL/native uitvoercode zijn behouden.

Er zijn precies twee modelroutes uitgevoerd, O0 en O2. Beide stoppen normaal na return van deze ene headpoging, vóór een volgende hostretry of commit. Procesduur **0,784 s O0** en **0,773 s O2**, onder de harde twintigsecondenlimiet, zonder censuur of mislukte modeluitvoering. Geen variantenzoektocht, langere periode of brede campagne.

## De minimale toevoeging

De oorspronkelijke tridiagonale Jacobiaan behoudt de bestaande lokale macro-afgeleiden. Alleen de ontbrekende afgeleide van de **domeinbrede uitstroomfactor** wordt toegevoegd, voor de geselecteerde gedeeltelijke domein-3-tak met nul potentiële instroom, geen onverzadigde uitstroom en geen herverdeling:

`q_i = f * o_i / dt`, `f = 1 − E/O`.

Hier geldt `E=L−W+O`, zodat bij vaste geaccepteerde W:

`df/dh_j = −(dL/dh_j)/O − f*(dO/dh_j)/O`.

L volgt de actuele GWL-volumetak. De GWL-afgeleiden komen analytisch uit de oorspronkelijke interpolatie tussen h50 en h51; de volumedichtheid bij de GWL geeft dL. De totale potentiële uitstroom heeft de somgevoeligheid van de verzadigde componenten. Voor iedere uitgaande component geeft de oorspronkelijke headverschilrelatie `do_i/dh_i=−o_i/(Hmp_i−h_i)`.

De bestaande lokale afgeleide bevat de term `f*do_i/dh_i/dt` al. De aanvullende residubijdrage is daarom uitsluitend:

`ΔJ_ij = U_i * V_j`, met `U_i=−o_i/dt` en `V_j=df/dh_j`.

De aanvulling wordt op alle uitgaande componenten van domein 3 toegepast, niet alleen op node 52. Zij bevat zowel de GWL-/minimumvoorraadketen als de invloed van de totale potentiële uitstroom. Er wordt geen fysische grens vervangen of gladgestreken en geen volle numerieke Jacobiaan opgebouwd.

Het lineaire stelsel blijft de bestaande tridiagonale operator T plus één rang-één-term. Met dezelfde TRIDAG-routine worden `x0=T⁻¹F` en `z=T⁻¹U` bepaald, gevolgd door de Sherman–Morrison-stap:

`difh = x0 − z*(Vᵀx0)/(1+Vᵀz)`.

De rang-één-noemers zijn in de twee iteraties **6,04256071438238** en **5,763939404854703**. De uit de oorspronkelijke tridiagonale coëfficiënten en U,V onafhankelijk gereconstrueerde lineaire restfout is maximaal **2,775557561562891e-17**. Geen lineaire fallback is gebruikt.

## Kalibratie tegen de bestaande gevoeligheidsmeting

Vóór de eerste nieuwe Newtonstap wordt de eerder gekwalificeerde SENSE23-proefbasis tijdelijk geladen, uitsluitend om de analytische coëfficiënten uit te lezen. Er worden daarbij geen providerfluxen opnieuw geprobed of als targetstaat geïnstalleerd. De huidige targetstaat wordt eerst opgeslagen en daarna volledig hersteld met de afgebakende transactie uit SENSE23. jac24_current.bin en jac24_restored.bin zijn bytegelijk; IEEE-statusherstel wordt eveneens uit dat mechanisme behouden.

De geladen kalibratiebasis heeft exact de geregistreerde SHA256 `aec5d4383614499853fe809018b53844d54d852a205a77f45c28ea28378f62c3`. Zij is dus dezelfde gedeeltelijk actieve toestand als de eerdere centrale verschillen, niet een nieuw gekozen meetpunt.

| Afgeleide van domein-3-Q op node 52 naar | Analytisch JAC24 | SENSE23 centraal verschil |
| --- | ---: | ---: |
| h50 | −0,873609730481 | −0,873609731275 |
| h51 | −0,164925876690 | −0,164925876723 |
| h52 | −0,0101621315171 | −0,0101621315146 |

De grootste absolute afwijking is **7,94e-10**, onder de vastgelegde 1e-8-vergelijkingsgrens. Die grens is uitsluitend een afgeleidecontrole en verandert geen modelacceptatiecriterium.

## Gekoppeld resultaat met de oorspronkelijke criteria

| Dezelfde oorspronkelijke headpoging | FRESH22, actuele operator zonder aanvulling | JAC24 O0/O2 |
| --- | ---: | ---: |
| Iteraties | 30, afgewezen | 2, geconvergeerd |
| Grootste absolute compartimentresidu | 1,14304236263e-4 | 4,12197651012e-10 |
| Somresidu | −4,48408847401e-4 | −4,87377774433e-11 |
| Gebruikte fluxfactor | 1 | 1 |
| Extra line-searchtrials boven de eerste | 28 | 0 |
| Verse V1-certificeringen | 0 | 1 |

De rang-één-aanvulling is in beide uitgevoerde iteraties actief. Alle eindconvergentievlaggen zijn false: geen compartiment-, head-, ponding- of macrovoorraadweigering en geen dt- of fluxreductieverzoek. De laatste verse V1-evaluatie behoudt de actuele node-52-operator exact. Het grootste eindresidu ligt op node 51, niet node 52.

De eindresiduvector is onafhankelijk uit solver_1.txt gecontroleerd. De node-52-operator sluit uit zijn afzonderlijke opslag-, matrix-, verticale en macrotermen. Alle niet-timingtraces, kalibratiegegevens en begin-/returnexports zijn bytegelijk tussen O0 en O2. De target-return bevat nu de geconvergeerde headstaat; hij is geen eerder geaccepteerde checkpoint en wordt niet als native herstartbestand geschreven.

## Geldigheidsgrens

De kandidaat is bewust beperkt tot dezelfde oorspronkelijke poging 38 en de gemeten nul-instroomtak van domein 3, met gedeeltelijke minimumvoorraadbegrenzing en dezelfde GWL-interpolatiebracket. Buiten die tak levert de getter geen aanvulling en blijft de bestaande benadering over; dat gedrag is hier niet als algemene oplossing gekwalificeerd. Een afwijkende GWL-interpolatie of ongeldige uitgaande headrelatie stopt de onderzoeksroute. Ook de bescherming tegen een bijna-singuliere Sherman–Morrison-noemer is een onderzoeksstop, geen versoepelde modelacceptatie.

Er is geen aanspraak op een exacte volledige macro-Jacobiaan voor andere domeinen, geometrieveranderingen, instroombegrenzingen, herverdeling of branchgrenzen. Het huidige bewijs rechtvaardigt de **lokale numerieke kandidaat** voor deze headcontext; het toont geen fout in de fysische minimumvoorraadregel.

Hostcommit, waterinventaris na integratie, echte afwijzing/rollback met deze kandidaat, directe kleinere retry, eigen herstart en volledige tweede BAL-periode zijn niet opnieuw gekwalificeerd. De reeds bestaande kwalificaties voor de eerdere kandidaat worden niet automatisch naar deze solveraanvulling overgedragen. De behouden eindmelding IEEE_DENORMAL uit de snapshotinstrumentatie blijft dezelfde beperking als in SENSE23; geen algemene IEEE-identiteit met de niet-geïnstrumenteerde binary wordt geclaimd.

assess_jac24.py beoordeelt uitsluitend bestaande bestanden. RESULT.json, candidate.patch, TRACE_FIELDS.json, transactieveldenschema, originele native invoer, builds en geverifieerde JAC24_EVIDENCE.zip bewaren het concrete herstelpad. Geen officiële promotie of brede vervolgcampagne.
