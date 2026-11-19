# SELECT50 - actieve CONTACT47-afwijzing en directe kleinere retry

De gerichte selectie heeft een echte afwijzing met positieve CONTACT47-proefbijdrage opgeleverd. In oorspronkelijke SELECT28-D2 (oude poging3066) wijzen drie ongereduceerde pogingen werkelijk af bij MAXIT30. De tijdelijke CONTACT47-bijdrage wordt na iedere rollback ongeldig en nul; er wordt niets aan de referentie gecommit. Het gehele kleinere vervolg is exact gelijk aan een directe kleinere route vanuit dezelfde oorspronkelijke toestand. Er blijft een expliciete beperking: inactieve eventinitialisaties worden niet volledig bytegelijk teruggezet.

## Oorspronkelijke contexten en bron

Baseline ROLLBACK49 da27aad15a69ea40bf898e392e92d14c3b5969f6. Succesvolle build-/runbroncheckpoint c8cacc16a. De FEEDBACK48-referentie-implementatie, klok, fluxwetten, derivatieven, guards, toleranties, MAXIT, tijdstap- en reductieregels zijn ongewijzigd. Alle Fortran-bestanden zijn bytegelijk aan ROLLBACK49 behalve de oorspronkelijke-contextdriver in soilwater_native. HARNESS.patch is achterwaarts tegen de baseline gecontroleerd.

Uitsluitend twee vooraf geselecteerde, bestaande SELECT28-contexten zijn gebruikt; geen scan of nieuwe forcing. De oorspronkelijke prefixes worden met de eerdere TRIDAG/V1/Darcy-activatie hersteld. De volledige prefix_budget, origin, nativecontext en ledger zijn in beide optimalisaties bytegelijk aan de bewaarde SELECT28-bewijzen: D1 1137commits, D2 1309commits. Die herstelprefix is geen nieuw kandidaattraject; FEEDBACK48 wordt pas op de gekozen head/retries actief. De oorspronkelijke native35797 heeft SHA256 21bd728c9983d6a0d4e82d6b2fd12729dc02284277a5dab5d296d8edc1dcbf16.

D1 (oude2630) accepteert in12iteraties met positieve CONTACT47-bijdrage in alle42provider-evaluaties. Eenmalige gecommitte increment3.605713020015352e-10. Maxres4.875862483003091e-7, inventarisfout -7.694189477848489e-10cm binnen2.222222222222222e-9cm. Geen afwijzing, dus geen DIRECT-D1.

## D2: echte actieve afwijzing

Oorspronkelijke t35797.290420649493 en dt2.8284271247461902e-4. De eerste poging faalt werkelijk bij MAXIT30: maxres3.9748157738932199e-6 en somresidu -1.1074072016984172e-5. Geen geforceerde failure, singulariteitsfout, verlaagde toelatingsgrens of fluxreductie.

Van123 bestaande provider-evaluaties hebben119 een positieve CONTACT47-scratch. Ook de laatste teruggekeerde scratch heeft masker1 en positieve increment3.429229609448318e-10. De host accepteert niet en roept de oorspronkelijke rollback aan. Daarna registreert de getter ready0/mask0/som0. De ledger blijft ongewijzigd en er bestaat geen referentiecommitreceipt. Dit is de ontbrekende positieve afgewezen CONTACT47-bijdrage die de lege-cachecontext297 niet kon leveren.

De oorspronkelijke TimeControl5 deelt dt door3. De volgende twee kleinere pogingen wijzen eveneens af bij MAXIT30, met respectievelijk68 en52 positieve CONTACT47-evaluaties. De cache is na beide rollbacks opnieuw ongeldig en nul. De vierde poging accepteert vers in3iteraties bij dt1.0475656017578482e-5, maxres1.5796352162943117e-7. CONTACT47 is op die uiteindelijk geaccepteerde kleine poging niet actief. De kwalificatie betreft dus het veilig verwerpen van actieve proefbijdragen en het correcte vervolg, niet een positieve nieuwe referentiecommit op de laatste kleine stap.

## Directe kleinere vergelijking

DIRECT-D2 herstelt exact dezelfde oorspronkelijke origin en begint rechtstreeks met dt9.4280904158206339e-5, verkregen met dezelfde oorspronkelijke TimeControl5. Die eerste kleinere poging faalt ook. Het volledige suffix van3 solverpogingen is exact gelijk aan TRIAL-pogingen2..4, na normalisatie van alleen de pogingindex: solvertraces, alleproviderreceipts en alle fysieke pogingvelden. Er is geen selectie van alleen de uiteindelijke succesvolle solveruitkomst.

De geaccepteerde en gecommitte inventaris/nativecontext, ledgers en step_budget zijn bytegelijk. Beide routes eindigen op35797.290431125148. De onafhankelijke inventarisfout is1.154971428410961e-11cm binnen de bestaande dt*1e-5-grens1.0475656017578482e-10cm. VerseV1-controle, per-domeinbalansen en primitieve cumulatieve incrementen slagen; maximale ledgerincrementafwijking6.31e-17cm.

## Wat rollback wel en niet bewijst

Waterinventaris, heads en fysieke kern herstellen; alle contactklokken en reeds actieve eventhistories blijven gelijk aan de oorspronkelijke toestand. De nieuwe positieve CONTACT47-increment wordt niet gecommit en de scratch wordt gewist. Het directe vervolg bewijst dezelfde toekomstige berekening voor dit oorspronkelijke geval.

Onmiddellijke volledige native bytegelijkheid is niet bereikt. Nativevelden ThtSrpRefDmCp en SorpDmCp houden proefinitialisaties voor uitsluitend D4/node49 en D3/node50. Beide hebben voor en na rollback contactleeftijd0: de oorspronkelijke ABSORPTION-eventstart zet de referentie tijdens een rate naar theta_s en initialiseert sorptiviteit. De referentie wordt hier0 ->.444, niet0 ->.444 plus de afgewezen CONTACT47-increment. De owner-rollback herstelt die inactieve initialisaties niet. De bestaande ratecode initialiseert ze opnieuw wanneer een nieuw event bij tau0 werkelijk wordt geactiveerd. Dit verklaart hun beperkte betekenis, maar vervangt geen volledige byte-restauratieclaim.

Daarnaast verschillen de bekende flux-/boundaryhelpers, eventflag en dynamische shrinkhulpen VlMpDyCp/SubsidCp. De kleinere dt verschilt uiteraard bij latere retries. Deze verschillen zijn expliciet gecontroleerd; ze raken hier geen reeds actieve eventreferentie of contactklok. Geen algemene rollback- of nativeherstarttoelating voor willekeurige histories. Een eventueel strenger contract voor ook inactieve eventvelden vereist afzonderlijke afbakening en kwalificatie; deze opdracht wijzigt dat oorspronkelijke gedrag niet.

## O0/O2 en budget

| Route | O0 seconden | O2 seconden |
|---|---:|---:|
| TRIAL-D1 |14.554263|11.712098|
| TRIAL-D2 |11.285743|9.808749|
| DIRECT-D2 |14.029417|9.263836|

Alle6 routes normaal en ongecensureerd; zowel de interne16s-grens als externe20s-grens bleven behouden, inclusief oorspronkelijke prefixreconstructie. D2-routes zijn na elkaar uitgevoerd om rekentijdconcurrentie te vermijden. Kandidaatcap512commits en de bestaande4retrygrens zijn niet verruimd; feitelijk1commit per route. Selectie stopt bij de eerste gepaarde actieve witness D2. Geen verdere context of brede campagne.

O0/O2 zijn identiek in solver, fysieke toestand, referentie, cache- en providerreceipts voor D2, commit, ledger en budget. De bekende diagnostische uitzondering uit ROLLBACK49 blijft in D1 zichtbaar: contact43_trace veld14 SorpFac is onbepaald in een tak zonder Darcy, met rawDarcy0 en gekozen sorptie. O0 geeft0, O2 een eindig subnormaal getal; alle andere velden zijn gelijk. Geen claim van totale niet-timingdiagnose-/IEEE-identiteit. De actieve D2-witness en DIRECT-D2 zijn buiten timings volledig bytegelijk tussen O0/O2.

Een aanvankelijke syntaxfout in de nieuwe prefixreceipt verhinderde beide eerste builds; geen model is tegen die bron gestart. De fout is vóór succesvolle builds/runs hersteld en beide mislukte buildlogs zijn ongewijzigd bewaard als BUILD_FAILED_INITIAL. Geen fysieke of numerieke correctie betrof dit.

## Kwalificatiestatus

De open selectie van een echte CONTACT47-actieve weigering is voor deze oorspronkelijke D2 gesloten. Het verwerpen van de positieve cachebijdrage en de directe kleinere retry-equivalentie zijn gekwalificeerd met de beschreven inactieve-historybeperking. Volledige native/inactieve-historybyte-rollback blijft niet gekwalificeerd. Geen vervolgtraject/fullperiode/BAL/nieuweherstart of algemene toelating. B1 blijft B1_CANDIDATE_WITH_EXPLICIT_EXCLUSIONS; B0/B1.12/canoniek/no-macrorelease onaangeraakt.

RESULT.json, assess_select50.py en de onbewerkte originele/returned/rollback/committraces bevatten het herhaalbare bewijs. TRACE_FIELDS.json beschrijft de receipts. EVIDENCE.json bindt het verzegelde bron-/uitvoer-/buildarchief aan de resultaatcheckpoint.
