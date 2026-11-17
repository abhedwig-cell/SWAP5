# INACTIVE35 — ontbrekende niet-lokale Jacobiaankoppelingen aangetoond

**De eerste inactieve afwijzing uit de eigen kandidaattraj­ectie is gereproduceerd en gericht verklaard als een onvolledig gelineariseerde macroporiënkoppeling.** Op de onderzochte Jacobiaantoestand zijn echte niet-lokale macroresiduderivaten gemeten waar de huidige tridiagonale Jacobiaan nul heeft en de huidige rang-één-aanvulling uitstaat. De fluxfysica is niet als fout aangetoond. Er is geen numerieke correctie ingevoerd.

De oorspronkelijke rollback plus kleinere retry geeft exact dezelfde geaccepteerde toestand als een directe kleinere stap. De verklaring is dus niet dat schadelijk achtergebleven trialgeheugen de geaccepteerde retry verandert. Dit kwalificeert alleen deze **inactieve** afwijzing; het nog ontbrekende actieve-afwijzingsbewijs blijft open.

## Exacte context en grenzen

Baseline is PERIOD34 `04c3b4ae12ce4d7aefe912081c6769920ef54dbc`. Remote onderzoeksbranch is daarmee gelijk; remote main blijft `be481cfb40f953e337116ef4a6dc5bc3ef64d4f7`. De oorspronkelijke native daggrens 35797 en dezelfde doorlopende kandidaat worden gebruikt. Dit is de eigen kandidaataanloop, niet de historische V1-aanloop.

Geselecteerd is uitsluitend poging **293**, na 292 commits, beginnend op t1900 **35797,370324351359**, dt **0,0006875745394909628 dag**. De t/dt-combinatie wordt op de levende host gecontroleerd. De aanloop, oorspronkelijke afwijzing en geaccepteerde retry zijn zonder rekentijdvelden exact gelijk aan PERIOD34. Er is geen latere toestand ingevoegd.

Vooraf zijn twee TRIAL-routes en bij een echte afwijzing gevolgd door acceptatie twee DIRECT-routes vastgelegd. Na de eerste detailbevinding is vóór extra uitvoering één transactionele providerproef op exact dezelfde Jacobiaantoestand afgebakend, met O0/O2. Totaal zes routes, allemaal normaal en ongecensureerd onder twintig seconden, maximaal **2,173818 seconde**. Er zijn geen andere contexten, brede periode, nieuw solveralgoritme of aangepaste fysische instellingen geprobeerd.

Fysica, actuele operator, rang-één-formule, guards, MAXIT, toleranties, dt en reductieregels zijn behouden. Aanvankelijk veranderen alleen diagnostische node-uitvoer, de exacte replaycontrole en een onderzoekscommitteller. Vervolgens komen een alleen-lezen providergetter en een optionele, volledig herstelde gevoeligheidsproef erbij. De bestaande Jacobiaan wordt door die proef niet veranderd. Beide exacte bron- en binaryclosures zijn vóór herbouwen bewaard en tegen hun buildidentiteiten gecontroleerd. B0, B1.12, canonical en de macroporiënvrije releasebasis blijven ongewijzigd.

## Reële afwijzing, herstel en directe retry

| Eigenschap | Afgewezen poging | Kleinere retry |
| --- | ---: | ---: |
| Gebruikte dt, dag | 0,0006875745394909628 | 0,00022919151316365426 |
| Newtoniteraties | 30, uitgeput | 27, geaccepteerd |
| Extra line-searchtrials | 62 | 49 |
| Grootste eindresidu | 2,645026813588580e-5 | 2,477537854039813e-7 |
| Somresidu | 8,191114338218926e-6 | −9,807976153896003e-7 |
| Actieve rang-één-iteraties op die head | 0 | 0 |

Bij de grote stap is het totale residu al binnen de oorspronkelijke grens, maar de lokale compartimentgrens niet: de grootste afwijking ligt op node 52 en is ruim 26 maal 1e-6. Headverandering, pond- en macrovoorraadflags zijn bij de laatste controle niet de blokkade. De grote stap krijgt geen verse V1-acceptatiecontrole, omdat de lokale criteria niet worden gehaald. De kleine retry krijgt die controle eenmaal en behoudt fluxfactor 1.

De iteratie is niet exact stilgevallen. Het grootste residu daalt na iteraties 1, 10, 20 en 30 van 5,40736e-3 via 8,05050e-4 en 1,33420e-4 tot 2,64503e-5, met veel gedempte stappen. Het probleem is trage gekoppelde convergentie binnen het ongewijzigde maximum.

De fysieke inventariskern wordt bij de oorspronkelijke rollback exact teruggezet: heads, vocht, pond, macrovoorraad, geometrie, natte wand en sorptieklok. In de onmiddellijke werkvelden blijven verschillen in macro-/matrixfluxen, randfluxen, sorptiereferentie en sorptiviteit over. De ledger blijft gedurende afwijzing, rollback en retrybegin exact onveranderd.

Na herberekening zijn **het volledige geaccepteerde solverdump, de host-/native context, ledger, hostcommit en alle primitieve commitbudgetten bytegelijk aan DIRECT**. De onafhankelijke waterinventaris van de targetretry wijkt −2,247904854675597e-10 cm af, binnen de oorspronkelijke geïntegreerde grens 2,291915131636543e-9 cm. In deze context zijn de achtergebleven werkvelden dus herberekenbaar zonder schadelijke doorwerking op de acceptatie. Geen algemene volledige rollback- of herstartclaim.

| Route | O0, seconden | O2, seconden |
| --- | ---: | ---: |
| TRIAL: afwijzing + rollback + retry | 1,462228 | 1,227781 |
| DIRECT: dezelfde kleinere stap | 0,838084 | 0,715728 |
| TRIAL met transactionele providerproef | 2,173818 | 1,894834 |

Alle niet-timingtekstexports en attemptvelden zonder rekentijd zijn bytegelijk tussen O0/O2.

## Operatorbijdragen en exacte uitsluitingen

De registratie voor nodes 50–57 sluit de residuvergelijking opnieuw op uit opslag, matrixsink/-source, root, beide verticale termen en totale macro-uitwisseling. De laatste afgewezen evaluatie op node 52 bevat, in cm/dag:

| Bijdrage | Waarde |
| --- | ---: |
| Matrixopslagverandering | 0 |
| Matrixsink | +0,0002749218682428194 |
| Matrixsource en root | 0 |
| Bovenste verticale term | −0,3208367664478565 |
| Onderste verticale term | +0,2009693789964548 |
| Negatieve totale macro-uitwisseling | +0,11956601531502303 |
| Som: F52 | −0,0000264502681358858 |

De macro-uitwisseling op die node bestaat hoofdzakelijk uit domein 1 met −0,12403958836839385, domein 2 met +0,00033089098234983063 en domein 3 met +0,00414268207102099. De diagnose van alleen domein 3 mag dus niet automatisch als volledige operatorverklaring worden opgevoerd.

Alle dertig Jacobiaanevaluaties van de grote stap hebben positieve domein-3-instroom **6,870636689271369e-7 cm**, uitsluitend de topbijdrage. De matrix- en interne instroombijdragen zijn 0, FrIn is 1 en topoverschot 0. In de kleinere retry is dezelfde topinstroom evenredig met dt verkleind. De eerste guard `I=0` van de bestaande aanvulling is daarmee onwaar.

Daarnaast ligt het native compartiment dat de grondwaterspiegel bevat, **ICpTpSatZon**, op **51**. De bestaande aanvulling is afgebakend op 50. Dit moet worden onderscheiden van de drukheadinterpolatie: die gebruikt nog steeds **heads 50 en 51**, met h50 < 0 < h51. De native grondwaterspiegel wordt exact door die interpolatie teruggevonden. De eerdere korte aanduiding “GWL-bracket 51” is dus gecorrigeerd: 51 is hier het volumecompartiment, niet de linker interpolatienode.

Bij de grote stap zijn 25 van de 30 Jacobiaantoestanden gedeeltelijk minimumvoorraadbegrensd; drie gebruiken L=W en twee hebben onbegrensde uitstroom. Bij de kleine retry zijn dat 19 gedeeltelijk, twee L=W en zes onbegrensd. Door de afgebakende guards wordt in geen van deze heads de bestaande aanvulling uitgevoerd.

## Transactionele gevoeligheidsproef: werkelijk ontbrekende termen

Getoetst is precies de toestand van poging 293, iteratie 30, **na Jacobiaanopbouw en vóór TRIDAG**. De echte MACRORATE-provider wordt geëvalueerd op een basispunt, centrale perturbaties ±1e-5 en ±5e-6 cm van heads 50, 51, 52 en 57, en een herhaald basispunt: achttien evaluaties per route. Dit is een gevoeligheidsmeting, geen finite-difference-Jacobiaan in de solver.

Vóór iedere evaluatie en na afloop wordt de bestaande SENSE23-procestoestand van **20.347.880 bytes** hersteld. Alle negentien volledige vergelijkingen van die geserialiseerde scope zijn bytegelijk; de herkende IEEE-flags zijn na statusherstel gelijk. De uiteindelijke snapshot is ook bytegelijk aan het begin. De ongestoorde basisprovideruitwisseling is exact gelijk aan de al opgebouwde Jacobiaantoestand. Na de proef zijn alle baseline solver-, operator-, context-, ledger- en commitexports exact onveranderd.

Op dit punt is voor domein 3: I = 6,870636689271369e-7 cm, O = 1,477148699182036e-5 cm, L = 0,03013536935396029 cm en W = 0,030146815539612012 cm. De uitstroomfactor is 0,8213966087076336. Alle proefpunten blijven in dezelfde gedeeltelijke tak en hetzelfde native volumecompartiment 51. De topinstroom heeft voor de getoetste headvariaties exact afgeleide 0.

Omdat het residu de macro-uitwisseling aftrekt, is de gemeten macrobijdrage aan J gelijk aan **−dQ/dh**. Representatieve centrale verschillen bij eps = 5e-6:

| Rij, kolom | Huidige off-tridiagonale J | Gemeten macrobijdrage totaal | Daarvan domein 3 |
| --- | ---: | ---: | ---: |
| 52, 50 | 0 | +0,4462934276028285 | +0,3409272299746343 |
| 53, 51 | 0 | +1,441772196882768 | ongeveer +1,098 |
| 52, 57 | 0 | −0,00006139552616302169 | −0,00003124970646833924 |

De exacte domein-3-waarde voor elke rij/kolom en beide proefgroottes staat in SENSITIVITY.json. De twee eps-waarden en O0/O2 geven dezelfde respons binnen de gemeten afronding. De effecten liggen ruim boven die ruis. De koppelingen buiten de tridiagonaal zijn dus echt aanwezig in de provider, terwijl de gebruikte Jacobiaan ze niet bevat en de huidige rang-één-guard uitstaat.

Voor domein 3 kan de voorraadketen analytisch worden nagerekend. Op de gemeten tak is `f=(W+I−L)/O`, `df=(dI−dL−f·dO)/O` en `q_i=f·o_i/dt`. Met de actuele volumedichtheid van compartiment 51 en de headinterpolatie 50/51 stemmen vier analytische kolommen van die keten voor alle 112 domein-3-uitwisselingsrijen overeen met beide centrale verschillen: grootste absolute afwijking **8,344536728266405e-10**. Deze analytische schaduwberekening is niet in de solver ingevoerd.

Voor rij 52, kolom 50 resteert naast domein 3 nog **+0,1053661976281942** uit de overige domeinen. Dat deel is hier nog niet per domein uitgesplitst. Een aanpassing die alleen de twee guards van domein 3 verruimt, heeft daarmee nog geen onderbouwde claim op een voldoende volledige operatorcorrectie. Zij kan een testbare kandidaat zijn, maar haar afdoendheid of het uitsluitend causale aandeel in de trage convergentie is niet getest. Er is geen fluxvergelijking als fysiek onjuist aangetoond.

## Besluit en eerstvolgende afbakening

Status: `MISSING_NONLOCAL_JACOBIAN_TERMS_PROVEN_IN_INACTIVE_TOP_INFLOW_GWL_COMPARTMENT51_CONTEXT`. De ontbrekende koppelingen zijn kwantitatief aangetoond op de concrete eigen afwijzingscontext. Herstel en directe kleinere retry zijn voor deze inactieve afwijzing gekwalificeerd. De trialwerkvelden verklaren geen geaccepteerde toestandsafwijking.

De kleinste volgende inhoudelijke stap is **op dezelfde Jacobiaantoestand de overige domeinbijdragen ontleden en het correctiecontract voor constante topinstroom en het actuele GWL-volumecompartiment afbakenen**. Daarna kan een minimale analytische aanvulling gericht op dezelfde grote stap worden getoetst. Geen blind guardverruimen, extra historische selectie of volledige periode herhalen om dit onderscheid te maken. Deze verdere implementatie is hier niet uitgevoerd.

B1 blijft `B1_CANDIDATE_WITH_EXPLICIT_EXCLUSIONS`. Actieve-afwijzingskwalificatie, volledige periodebalans, eigen herstart en algemene solvertoelating blijven open. De bekende IEEE_DENORMAL-melding staat in alle zes ruwe procesuitvoeren; de proef kwalificeert statusherstel binnen de geselecteerde proefscope, niet volledige programma-IEEE-identiteit.

STATUS, RESULT, SENSITIVITY, DIAG_SELECTION, PROBE_CONTRACT, TRACE_FIELDS, bronpatches, beide bron-/binaryclosures, ruwe operator- en proeftraces en de geverifieerde INACTIVE35_EVIDENCE.zip bewaren de reproduceerbare diagnose. assess_inactive35.py leest uitsluitend bestaande bestanden. Geen fysische correctie, nieuwe solvervariant of officiële promotie.
