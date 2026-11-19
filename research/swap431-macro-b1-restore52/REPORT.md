# RESTORE52 - exact sorptieherstel en directe kleinere retry gekwalificeerd

De minimale INACTIVE51-implementatie slaagt in dezelfde oorspronkelijke D2-context met O0/O2. ThtSrpRefDmCp en SorpDmCp worden bij iedere echte afwijzing voor alle betrokken domeinen/cellen exact naar hun oorsprong teruggezet. De contactklok blijft ongewijzigd. Het volledige kleinere vervolg na rollback is gelijk aan de directe kleinere route, inclusief gecommitte toestand en waterbudget.

## Implementatie

MacroStateVar(1) bewaart twee lokale saved arrays naast de bestaande watergeometrie. De snapshot is gebonden aan een geldige tijd, NumDm en NumNod. MacroStateVar(2) herstelt beide wanneer de bestaande FEEDBACK48-kandidaat repair43/swmbf1/swabs1 actief is; een ontbrekende of niet-passende oorsprong wordt geweigerd. Er is geen node-/domein-/tau0-/pogingselectie in de restauratie.

De snapshot wordt op de oorspronkelijke saved-stategrens steeds opgebouwd, ook voordat de kandidaat wordt geactiveerd. Daardoor heeft de eerste geselecteerde D2-poging een correcte oorsprong, terwijl de originele restauratieprefix met repair43false zijn eerdere rollbackgedrag houdt. Geen nieuw native persistent veld of formaat. De nieuwe buffers zijn uitsluitend tijdelijke origin-state. TimAbsCumDmCp en AwlCorFac blijven in deze D2-route al exact en krijgen geen extra buffer of formule.

Een noodzakelijke gerichte kostenaanpassing voorkomt het volledig wissen van al lege CONTACT47-scratcharrays. delta/mask starten op0/false; elke payloadschrijf zetdirtytrue. Invalidate zetready altijdfalse en wist delta/mask wanneer dirtytrue, waarna dirtyfalse wordt. Bij dirtyfalse zijn beide al exact leeg. Dit behoudt invalidatie/stamp-/rollbacksemantiek, zonder extra provider, fysieke berekening of gewijzigde budgetgrens. De bestaande cache-getters bevestigen na alle weigeringen ready0/mask0/som0. De eerste succesvolle O2-variant met onvoorwaardelijk wissen heeft dezelfde niet-timinguitvoer als de uiteindelijke postimage.

Klok, CONTACT47-formule, eventstart/einde, fysieke fluxwetten/derivatieven, solver, guards, toleranties, MAXIT, dt- en reductieregels zijn behouden. IMPLEMENTATION.patch toont de volledige delta tegen INACTIVE51. De wijziging blijft in de geisoleerde onderzoeksbron.

## Dezelfde oorspronkelijke D2

Baseline INACTIVE51 7bc7ac98a86cfd3b87c0ae7641dd9b70dcb78049; definitieve broncheckpoint bc2912fb9. De oorspronkelijke SELECT28-D2 (oude3066) is hersteld: t35797.290420649493,dt2.8284271247461902e-4. Prefix_budget met1309 oorspronkelijke commits, origin, nativecontext en ledger zijn bytegelijk aan de bewaarde ouder. Native35797 SHA256 21bd728c9983d6a0d4e82d6b2fd12729dc02284277a5dab5d296d8edc1dcbf16. Geen gefixeerde proefstaat, gewijzigde input of nieuwe contextselectie.

TRIAL bevat dezelfde drie echte MAXIT30-afwijzingen, alle ongereduceerd, met119/68/52 positieve CONTACT47-evaluaties. De eerste teruggekeerde positieve proefincrement wordt niet gecommit. Rollback maakt de tijdelijke bijdrage ongeldig en leeg en herstelt nu bovendien beide volledige historiearrays. Alle TimAbsCumDmCp- en AwlCorFac-waarden blijven gelijk aan de oorsprong, evenals de ledger tot acceptatie. De herstelde historie blijft ook exact aanwezig bij het begin van iedere kleinere retry; er wordt geen verontreinigde snapshot opnieuw bewaard.

De eerste kleinere dt is9.4280904158206339e-5. DIRECT begint vanuit exact dezelfde oorsprong met dezelfde oorspronkelijke TimeControl5-verkleining. De volledige suffix van3 solverpogingen is na alleen pogingindexnormalisatie exact gelijk aan TRIAL2..4, inclusief alle bestaande providerreceipts en individuele solvertraces. De vierde TRIAL-/derdeDIRECT-poging accepteert vers in3iteraties bij dt1.0475656017578482e-5, maxres1.5796352162943117e-7. CONTACT47 is op die laatste kleine poging niet actief; de kwalificatie toont het veilig verwerpen van de positieve eerdere proeven.

De actuele eventinitialisatieformules en fysieke poginguitkomsten zijn gelijk aan INACTIVE51. De pre-initialisatiewaarden van de herstelde inactieve velden verschillen nu terecht; die waarden worden door de bestaande nieuwe-eventtak opnieuw berekend. Ook vlak voor de uiteindelijke hostcommit zijn de teruggekeerde inactieve referentie-/sorptiviteitsvelden nu schoner dan de oude variant. Na de oorspronkelijke ownercommit is de volledige gecommitte nativecontext opnieuw exact gelijk aan de ouder. Er is dus geen claim dat alle tussenliggende diagnosevelden gelijk moeten blijven aan het defecte rollbackgedrag.

## Inventaris en O0/O2

Beide routes eindigen op35797.290431125148. Geaccepteerde en gecommitte context/inventaris, ledger en step_budget zijn exact gelijk tussen TRIAL en DIRECT. De onafhankelijke waterinventarisfout is1.154971428410961e-11cm binnen1.0475656017578482e-10cm. Per-domeinbalansen en alle primitieve cumulatieve incrementen voldoen aan de bestaande grenzen. De ledgerincrementafwijking blijft maximaal6.31e-17cm. O0/O2 geven dezelfde niet-timingtekstuitvoer, inclusief de nieuwe eventinitialisatiereceipts, restoredumps en solver/providergegevens.

| Definitieve route | O0 (s) | O2 (s) |
|---|---:|---:|
| TRIAL-D2 |12.690067|9.015166|
| DIRECT-D2 |13.809424|8.335047|

Alle vier kwalificatieroutes normaal en ongecensureerd, onder hard20s en ook met terminale interne tijd onder16s. De bestaande interne16-policy met terminale acceptatieprioriteit en de512owncommit-/4retrygrenzen zijn niet gewijzigd. Routes zijn na elkaar uitgevoerd om concurrentie te vermijden. Geen brede campagne.

## Bewaarde eerste variant

Voor de kostenaanpassing zijn twee routes tegen bron33ba1d067 uitgevoerd en bewaard in initial_always_clear, met binaries native_initial52.exe. O0 bereikte correct de oorspronkelijke interne16s-prefixstop bij35797.282231540456, dus voor D2 (extern16.9624844s); deze route is geen rollback-PASS. O2 bereikte D2 in14.4670131s en herstelde de historie al correct. De definitieve vier routes zijn tegen een gewijzigde, vooraf gepersisteerde cachepostimage uitgevoerd; de eerste budgetuitkomst is niet overschreven of als fysisch falen verhuld. Totaal6 modelroutes, geen extra context/probe of grensverruiming. Dit is geen algemene of portable snelheidsgarantie.

## Kwalificatiegrens

Het INACTIVE51-contract voor beide sorptiearrays is geimplementeerd en gekwalificeerd in dezelfde oorspronkelijke D2-transactie, met echte positieve CONTACT47-weigeringen en een directe kleinere vergelijking. De inactieve-historybeperking uit SELECT50 is hiervoor gesloten.

Volledige onmiddellijke native byte-restauratie blijft buiten scope. VlMpDyCp/SubsidCp en oorspronkelijke flux-/boundary-/eventwerkgegevens kunnen nog verschillen; dt verandert bij kleinere retries zoals voorgeschreven. Er is geen claim over andere contactregimes, een nieuwe eigen herstart, volledige periode/BAL of algemene solver-/nativetoelating. B1 blijft B1_CANDIDATE_WITH_EXPLICIT_EXCLUSIONS; B0/B1.12/canoniek/no-macrorelease onaangeraakt.

RESULT.json en assess_restore52.py bevatten de herhaalbare bron-, fysieke en transactiechecks. TRACE_FIELDS.json beschrijft de reeds bestaande receipts. EVIDENCE.json verzegelt beide bronvarianten, builds, binaries, alle eerste en definitieve uitkomsten en de bewaarde oorspronkelijke contextafhankelijkheid.
