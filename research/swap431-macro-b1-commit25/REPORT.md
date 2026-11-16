# COMMIT25 — echte hostcommit en waterinventaris van JAC24

**De Jacobiaan-kandidaat slaagt voor de echte hostcommit en waterinventaris van dezelfde oorspronkelijke stap met O0/O2.** De onafhankelijke inventarisafwijking inclusief canopy is **−6,500659385788587e-14 cm**, binnen de oorspronkelijke geïntegreerde totale residugrens **1,3333333333333334e-8 cm**. De vijf macrodomeinen sluiten afzonderlijk op afrondniveau. Alle niet-timingexports zijn bytegelijk tussen O0 en O2.

Dit breidt de eerdere lokale head-PASS uit tot **één echte geaccepteerde hoststap**. Er is geen volgende stap, afwijzings-/rollbackroute, eigen herstart of volledige periodebalans uitgevoerd.

## Dezelfde kandidaat en oorspronkelijke stap

Baseline is JAC24 426b8d31a92a23b9f6b58dd58b96f67f220cd213. Alle Fortranbronnen van solver, Jacobiaan-aanvulling, fysieke providers, native codec en uitvoer zijn bytegelijk aan JAC24. Alleen de onderzoeksdriver verschuift zijn stop van headreturn naar de oorspronkelijke hostcommit en schrijft de bijbehorende voor-/na-inventaris en ledger. Een onderzoeksstop bij een onverwacht afgewezen target voorkomt onbedoeld verder doorrekenen; deze guard is niet geactiveerd.

De route start in een vers proces vanaf hetzelfde native eigen bestand op de afgesloten daggrens 35797. De eerste 36 geaccepteerde budgetregels en 37 eerdere headpogingen blijven exact behouden. Dezelfde targetpoging 38 begint op **35797,070666666681**, met gebruikte **dt=0,0013333333333333333 dag**. Zij convergeert zoals JAC24 in twee iteraties, met FrReduQ=1, dezelfde verse V1-controle en exact dezelfde proefresiduen. Ook de kalibratie, rang-één-trace en targetreturn zijn bytegelijk aan JAC24.

Daarna voert de echte host zonder vervangende statecopy zijn bestaande vervolg uit: SoilWater(3), flux-/voorraadberekening, MACROPORE(4) met macrostate en macro-integralen, integral(3), bodemtemperatuur en TimeControl(3). Pas dan worden de commitexports geschreven en stopt het proces.

Precies twee modelroutes zijn uitgevoerd: O0 **0,704 s**, O2 **0,593 s**. Beide stoppen normaal, zonder censuur, onder de harde twintigsecondenlimiet. Geen brede campagne, extra variant of doorrekening van een volgende balansperiode.

## Werkelijke commit en stapduur

Het eindpunt is **t1900=35797,072000000015**. De budgetstream bevat nu 37 geaccepteerde regels in plaats van JAC24's 36; de nieuwe regel hoort bij de target. Er blijven 38 headpogingen: geen nieuwe retry of verborgen vervolgstap.

De oorspronkelijke tijdcontroller kiest na deze gemakkelijke convergentie **dt=0,002 dag voor de volgende stap**. Dat is geen gebruikte integratieduur van de huidige stap. Alle balanscontroles gebruiken de geregistreerde accepted_dt=0,0013333333333333333. Het verschil tussen tijdstempels is niet als exactere dt gebruikt, vanwege de afronding van grote absolute t1900-waarden.

De committed h/theta zijn exact de geconvergeerde JAC24-targetreturn. De matrixvoorraad wordt vervolgens werkelijk door watstor bijgewerkt; de macrovoorraden, compartimentverdeling, eventklokken en wet-walltoestand veranderen door de originele macrostateprocedure. Het is dus geen hernoemde headexport zonder integratie.

## Onafhankelijke waterinventaris

De matrixverandering komt uit afzonderlijke begin-/eindtheta, dz en matrixfractie per compartiment. De macroverandering komt uit de vijf domeinvoorraden; domeinvoorraden zijn ook vergeleken met de som van hun compartimenten en het totaal. Pond en canopy komen uit afzonderlijke begin-/eindvoorraden. De geselecteerde oorspronkelijke case heeft SWSNOW=0 en SWFROST=0; er is hier geen sneeuw-/ijsvoorraadterm weggelaten.

De externe integraal komt uit de werkelijk gebruikte primitieve rates over accepted_dt: bruto regen en irrigatie, runon, canopyverdamping, pond-/bodemverdamping, wortelopname, onderrand, drainage, subsurface-irrigatie, rapid drainage en de staphoeveelheid runoff. Zij komt niet uit een afgeronde BAL-regel of door aftrekken van een eerder afgeleide totale balans.

| Grootheid over de geaccepteerde stap | O0 en O2, cm |
| --- | ---: |
| Matrixvoorraadverandering | −0,0005471728387796002 |
| Macrovoorraadverandering, vijf domeinen | −0,00010155226635849123 |
| Pondvoorraadverandering | 0 |
| Canopyvoorraadverandering | −0,0000001981343671357723 |
| Netto externe integraal inclusief canopyflux | −0,0006489232394402206 |
| Totale inventarisverandering minus externe integraal | **−6,500659385788587e-14** |
| Oorspronkelijke dt × CritDevBalTot | **1,3333333333333334e-8** |

De alternatieve inventaris zonder canopy, met netto regen/irrigatie, geeft **−6,500648543766863e-14 cm**. Beide vormen verschillen alleen op afrondniveau. De gemeten canopyvoorraad gaat van **0,0025821006921540445** naar **0,0025819025577869087 cm** en volgt exact de oorspronkelijke `(crsflx_in−crsflx_out)*dt`-boeking binnen rekenafronding.

De fysieke inventarisfout sluit bovendien binnen 1e-15 cm aan bij de laatste gekoppelde somresidu-integratie uit JAC24. De gebruikte offline afrondcontroles veranderen geen modelcriteria. De uit fluxes() gereconstrueerde verticale matrixfluxen worden niet als onafhankelijk bewijs van dezelfde voorraadidentiteit opgevoerd; de onafhankelijke hele-inventariscontrole gebruikt de externe rates en werkelijke stocks.

## Afzonderlijke macrovoorraden en actieve minimumgrens

Per domein is de gemeten voorraadverandering getoetst tegen `dt*(top-lateraal + top-verticaal − uitwisseling naar matrix − rapid drainage)`, waarbij rapid drainage alleen voor domein 1 meetelt.

| Domein | Voorraadbalansafwijking, cm |
| --- | ---: |
| 1 | −2,7459961117037163e-17 |
| 2 | 6,785157423980573e-18 |
| 3 | −2,222614453595284e-18 |
| 4 | 1,2874900798265365e-19 |
| 5 | 5,421010862427522e-20 |

Alle vijf eindvoorraden blijven positief. Domein 3 eindigt op **0,0353436710755035 cm**, exact gelijk aan de oorspronkelijke minimumvoorraad uit de definitieve gekoppelde fluxberekening. De nieuwe Jacobiaan heeft de fysische minimumvoorraad dus niet omzeild om convergentie te verkrijgen: de echte macrostate bereikt die grens met de berekende rates.

## Cumulatieve boeking door de echte host

ledger_target_begin en ledger_target_return zijn bytegelijk: de headsolve heeft de cumulatieve waterboekhouding niet zelfstandig vooruitgezet. Na de hostcommit zijn de werkelijke cumulatieve veranderingen vergeleken met de primitieve stapintegralen. Dit omvat regen, irrigatie, runon, canopy-/pond-/bodemverdamping, wortelopname, onderrand, drainage, subsurface-irrigatie, rapid drainage en runoff. Ook MB/IC-topinstroom en netto macro-/matrix-uitwisseling sluiten op hun primitieve integralen.

De grootste gemeten afwijking in de genoemde scalarboekingen is ongeveer **4,12e-18 cm**. De niet-nul SICINI van de lopende balansperiode blijft behouden; de commit veroorzaakt geen nieuwe periodereset of fictieve carry-in. Er is geen aanvulling van ontbrekende historie uit andere routes.

## Geldigheidsgrens en herstelpad

Status is PASS_LOCAL_HOST_COMMIT_AND_WATER_INVENTORY_O0_O2. De numerieke kandidaat blijft beperkt tot de geselecteerde JAC24-tak en poging. De aangetoonde hostcommit geldt voor deze ene geaccepteerde stap, niet voor een andere branch, volgende stap of algemene lange route.

Echte weigering met deze kandidaat, rollback/herstel, vergelijking met directe kleinere retry, native herstart van de nieuwe toestand en volledige tweede BAL-periode blijven afzonderlijk ongekwalificeerd. Er wordt geen nieuw native checkpoint geschreven of een eerdere herstart-PASS automatisch overgedragen. De behouden IEEE_DENORMAL-melding uit de snapshotinstrumentatie blijft dezelfde gedocumenteerde beperking als in SENSE23/JAC24; er is geen algemene IEEE-statusidentiteit met een niet-geïnstrumenteerde binary aangetoond.

assess_commit25.py beoordeelt uitsluitend bestaande bestanden. RESULT.json, driver_only.patch, oorspronkelijke target- en commitexports, primitive budgetregel, ledger, bronidentiteiten, native bouwclosure en het geverifieerde COMMIT25_EVIDENCE.zip bewaren het reproduceerbare herstelpad. Geen officiële promotie of brede vervolgcampagne.
