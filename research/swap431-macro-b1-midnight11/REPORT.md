# MIDNIGHT11 — native macroherstart precies op de daggrens

**PASS voor t1900=35797, na volledige oorspronkelijke dagafsluiting en vóór de volgende dagstart, met O0/O2 en één volledige nieuwe-dagstap.** De checkpointcontext, verse installatie, context vóór headcalc en gemeten fysieke eindtoestand inclusief temperatuur, hydrauliek en gewascontext zijn exact. Status blijft B1_CANDIDATE_WITH_EXPLICIT_EXCLUSIONS; geen officiële promotie.

## Het bedoelde daggrenscontract

Een datum op de daggrens is onvoldoende om de uitvoeringsfase te bepalen. Direct na TimeControl(3) moet de oorspronkelijke host nog gewasgroei/-afhandeling, dagintegralen en uitvoer uitvoeren. Het nieuwe checkpointpunt ligt daarom pas **onderaan de oorspronkelijke tijdlus, na alle dagafsluitingsblokken**, vóór de volgende TimeControl(2). Het water-/macrogeheugen en de geaccepteerde gewascontext horen bij die volledig afgesloten dag. Dagafsluiting wordt na lezen niet opnieuw uitgevoerd; de volgende dagstart wordt wel echt uitgevoerd.

De bestaande V1-subdagbestanden blijven alleen leesbaar voor subdagtoestanden. De nieuwe schrijver gebruikt `SWAP431_MACRO_RESTART_V2`, versie2 en een afzonderlijke fasecode2 voor de voltooide dagafsluiting. De lezer controleert marker, versie, fasecode en samenhang met exact geheel t1900, tcum≈1, flDayStart=true en flDayEnd=true. Een bestand met dagflags mag niet als V1 worden geaccepteerd. De volledige overige native payload- en inventariscontroles blijven behouden. `completed_day.patch` maakt de beperkte fase-/hostwijzigingen zichtbaar.

Na het lezen van de oorspronkelijke gewasconstanten wordt `fl_readcropfile=false` gezet: die constanten zijn dan werkelijk voorbereid. Hiermee wordt voorkomen dat de volgende dagstart opnieuw de crop-initialisatieroute selecteert. Er is geen wijziging van fysieke vergelijkingen, residucriteria, solver, tijdstapgrenzen of reductieregels. Er is geen algemene nieuwe toestandsarchitectuur. De schrijver in deze onderzoekspostimage vereist expliciet het voltooide-dagpunt; dit maakt geen algemene schrijver voor alle fasen.

## Bestaande context en begrenzing

Basis is DAY10 `223398b8da089a7da239cef2999fdb92c9dd1a7d`. Beide optimalisaties beginnen bij het bestaande oorspronkelijke DAY10-eigen bestand vlak vóór de daggrens. De continue route voert de oorspronkelijke grensstap en volledige dagafsluiting uit, schrijft precies op35797 het eigen bestand en berekent één nieuwe-dagstap. Een vers proces leest dit bestand en berekent dezelfde nieuwe-dagstap. Geen replay of handmatig geconstrueerde beginvelden.

Het oorspronkelijke TSTART-laadvenster en alle fysieke invoerbestanden blijven behouden. TEND blijft zoals in DAY10 beperkt verlengd tot Jan3 om de bestaande oorspronkelijke derde-dagforcing te laden. Er wordt slechts de grensstap plus één nieuwe-dagstap uitgevoerd; geen koude tweedaagse/481-daagse of brede campagne.

Remote canonical is gereconcilieerd op `f9ada0cb2134971f92267a209f3a1fc86901dda8`; de gerichte delta sinds DAY10 bevat geen gewijzigde oorspronkelijke macro-Fortran of swap431-onderzoeksdependency. Alle veranderingen staan op de nieuwe onderzoeksbranch, uitsluitend in deze onderzoekssubmap. B0/B1.12/canonical/release en andere werkstromen zijn onaangeroerd.

## Resultaten en controles

- Checkpoint: exact t1900=35797, na alle dagafsluitingshandelingen; native writer laat de gemeten inventaris ongewijzigd.
- Geïnstalleerde uitgebreide toestand: bytegelijk aan de checkpoint, inclusief klok, voorraden, geometrie, tijd/dagflags, warmte en gewascontext.
- Volgende werkelijke dt: 0,0001733361984161963 dag; gelijke eindtijd35797,0001733362.
- Uitgebreide context vóór headcalc en volledige gemeten fysieke toestand na hostcommit: bytegelijk tussen continu en eigen herstart.
- Alle definitieve tekstuele meetvectors: bytegelijk tussen O0 en O2.
- Onafhankelijke gecombineerde waterinventarisafwijking: **−1,35928×10⁻¹⁴ cm**, afzonderlijk uit beide routes berekend. Alle vijf macrovoorraden sluiten op afrondniveau; gepaarde uitwisseling maximaal **2,77556×10⁻¹⁷ cm/d**.

Bij de solverreturn verschilt alleen het oude verticale matrixfluxprofiel dat de echte hostcommit opnieuw opbouwt; na commit is ook dit exact. De overige gemeten solverreturnvelden zijn gelijk. Geen afwijzings- of reductieflag ontstaat op de geselecteerde stap. Deze proef gebruikt de ongewijzigde oorspronkelijke headcriteria en voegt geen afzonderlijke verse residu-oracle toe.

Twee negatieve O2-initialisaties bewijzen dat een ongeldige V2-fasecode en een V2-dagtoestand vermomd als V1 stoppen vóór installatie. Er zijn vier positieve routes en twee vroege negatieve initialisaties, geen setup-/modelmislukkingen. Langste route **0,526 seconde**; geen censuur, alle onder twintig seconden.

## Expliciete uitsluitingen en herstelpad

Dit PASS geldt voor precies deze oorspronkelijke voltooide-dagfase en één volgende stap. Een checkpoint tussen TimeControl(3) en voltooide gewas-/uitvoerafhandeling blijft buiten scope. Exacte cumulatieve uitvoer-/PEARL-ledgers zijn niet hersteld of gekwalificeerd. Andere daggrenzen, modi, gereduceerde toestand, droge/h=0-transities en volledige trajecten zijn evenmin automatisch toegelaten. Geen officiële referentiepromotie.

`STATUS.json`, `RESULT.json`, `assess_mid11.py`, `completed_day.patch`, bronnen en bewijsarchive vormen het herstelpad. Herbeoordeling zonder model: `python research/swap431-macro-b1-midnight11/assess_mid11.py`. Alleen een nieuwe concrete vraag rechtvaardigt een volgende gerichte selectie; dit resultaat start geen brede campagne.
