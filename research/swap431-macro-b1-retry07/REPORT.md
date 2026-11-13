# RETRY07 — V1 plus de ongewijzigde CONTRACT06-patch

De gerichte afwijzing/herstel/kleinere-retrykwalificatie slaagt in oorspronkelijke context B, inclusief de volledige hostovergang en één vervolgstep. De korte eigen-bestandsherstart is daadwerkelijk uitgevoerd, maar faalt de toestandsgelijkheid al vóór de eerste nieuwe headcalc: de oorspronkelijke SWAP 4.3.1-interface ondersteunt macro-I/O niet. Eindstatus blijft **B1_CANDIDATE_WITH_EXPLICIT_EXCLUSIONS**, zonder referentiepromotie.

## Afbakening en identiteit

Basis is CONTRACT06 `e9ade290b2861159f94afe4b347c15badad6ba02`. De geïsoleerde branch is `research/swap431-macro-b1-retry07-20261113`. Canonical is vooraf gereconcilieerd op `a6720a0e8d7de6541069bdbdfd407fb1f41d3614`; de nieuwe basic/no-macro-opties raken deze oorspronkelijke closure niet. De bevroren oorspronkelijke bronnen, casus en native O0/O2-closures komen uit de bestaande STATE02, STAGNATION05 en CONTRACT06-bewijscapsules. Zie `*_IDENTITY.json` en `EVIDENCE.json`.

De kandidaat is V1 plus precies de bestaande eenregelige verwijdering van de extra H<h_enpr-Darcyblokkade. Er is geen nieuwe fysieke variant, geheugenpatch, solverinstelling, tolerantie, reductiewet of tijdstapgrens ingevoerd. `soilwater_retry.f90` en `swap_checkpoint.f90` bevatten uitsluitend de afgebakende aanroep-, meet- en stopinstrumentatie. De patch wordt pas op de geselecteerde levende oorspronkelijke context ingeschakeld; de oorspronkelijke aanloop blijft behouden. Er zijn zeven definitieve routes en twee afzonderlijk bewaarde invoeropstartfouten. De langste definitieve modelroute duurt 0,981 seconde, onder de grens van twintig seconden; geen route is gecensureerd. Geen tweedaagse of 481-daagse campagne.

## Echte afwijzing, herstel en directe controle

Context A (t1900=35796,92; dt=0,002 dag) accepteert met de patch in vijf iteraties. Daarmee vervalt deze oude afwijzingscontext als onderscheidende proef. Er is geen afwijzing afgedwongen. Alleen de vooraf geselecteerde tweede oorspronkelijke context B is vervolgens gebruikt: t1900=35796,9513533331; dt=2×10⁻⁵ dag; IDecMpRat=0.

In B wijst de kandidaat de werkelijke grote stap na de oorspronkelijke dertig iteraties af. De trace meldt loopindex 31 en uitkomstcode 4, met lokaal residu 0,061938 en totaal 0,021038 cm/d. FrReduQ blijft 1 en FlDecMpRat blijft false. De oorspronkelijke SoilWaterStateVar(2), MacroStateVar(2) en TimeControl(5) herstellen en verkleinen naar dt=10⁻⁵ dag. De kleinere retry accepteert ongereduceerd in zeven iteraties, met lokaal residu 1,445111×10⁻⁷ en totaal 1,444983×10⁻⁷ cm/d; beide voldoen aan de oorspronkelijke grenzen.

De directe route gebruikt dezelfde oorspronkelijke aanloop en slaat alleen de grote proef over. Zij roept dezelfde tijdstapverkleining aan en berekent rechtstreeks dt=10⁻⁵ dag. De oorsprong, geaccepteerde solveruitkomst, volledige gecommitteerde toestand, native eigen bestanden en de daaropvolgende solver- en hostuitkomst zijn bytegelijk tussen retry en directe route. De vervolgstep accepteert in drie iteraties. Alle definitieve B-meetvectors en eigen bestanden zijn ook bytegelijk tussen O0 en O2.

Direct na rollback zijn h/hm1, theta/thetm1, voorraden, geometrie, natte wandvelden en sorptieklok exact hersteld. Uitwisselingsdebieten, enkele randdebieten, eventflags, referenties en sorptiviteit verschillen dan nog. Deze verschillen bestaan ook vlak vóór de retry ten opzichte van de directe route; volledige onmiddellijke geheugengelijkheid wordt dus niet geclaimd. De echte herberekening wist hun effect hier: vanaf de geaccepteerde solverreturn zijn alle gemeten velden, inclusief klok en procesgeheugen, exact gelijk, ook na de vervolgstep. Dit ondersteunt in deze natte context een herberekenbaar trialeffect; het bewijst geen onschadelijkheid op een nog niet gekwalificeerde droge/eventovergang.

## Onafhankelijke waterinventaris

`assess_retry07.py` reconstrueert gradiënten en matrixresiduen uit h, geleidbaarheid, dikte, begin/eindvocht en bron-/sinktermen. Het controleert afzonderlijk de vijf macrovoorraden uit primitieve in-/uitdebieten, gepaarde uitwisseling, oppervlaktewater en gecombineerde inventaris. Het gebruikt voor iedere stap de werkelijk uitgevoerde dt, niet de volgende door de host gekozen dt.

| Grootheid | Geaccepteerde retry | Vervolgstep |
| --- | ---: | ---: |
| dt (dag) | 10⁻⁵ | 10⁻⁵ |
| Iteraties | 7 | 3 |
| Matrixvoorraadverandering (cm) | 2,682211×10⁻⁵ | 2,280209×10⁻⁵ |
| Macrovoorraadverandering (cm) | −3,182915×10⁻⁵ | −2,781082×10⁻⁵ |
| Gecombineerde balansafwijking (cm) | 1,444989×10⁻¹² | −4,284426×10⁻¹⁵ |
| Maximaal verschil gepaarde uitwisseling (cm/d) | 6,94×10⁻¹⁸ | 6,94×10⁻¹⁸ |

De eerste afwijking komt overeen met dt maal het toegelaten totale residu; de macrovoorraden sluiten afzonderlijk op afrondniveau. De native schrijver verandert geen gemeten modelveld (`checkpoint.txt` is bytegelijk aan `checkpoint_after_io.txt`).

## Korte eigen-bestandsherstart: uitgevoerd, niet gekwalificeerd

De checkpoint is genomen na de echte oorspronkelijke SoilWater(3), integral(3), heat(2), solute(2) en TimeControl(3). De native `inoutend(1)` schrijft een werkelijk eigen binair bestand; een nieuwe executable leest precies dit bestand via SWINCO=3/SWINITYPE=2. Een tweede, tekstuele eigen uitvoer maakt de veldinhoud inspecteerbaar. Er is geen replay of aanvullende serializer gebruikt.

Twee opstartfouten blijven afzonderlijk bewaard. Eerst bleek de oorspronkelijke lexer het door dtdpst gevormde `year-Mon-day` niet te accepteren: alleen de maandspelling is naar numeriek `year-month-day` omgezet, met behoud van het tijdstip. Daarna bleek de oorspronkelijke invoer-pre-read op SWENDTYPE te testen; met binair input én output op type 2 bereikt de route de echte herstart. Beide mislukkingen zijn invoeropstartfouten, geen geslaagde modelproeven; returncode alleen is geen kwalificatiecriterium.

De definitieve native herstart leest h en theta exact terug en voert één geaccepteerde volledige stap uit. Toch is al vóór headcalc sprake van:

- macro-totaalvoorraadverschil **0,010407692 cm**;
- maximaal domeinvoorraadverschil **0,032567926 cm**;
- sorptieklok overal nul tegenover maximaal **0,02002999974 dag** op de checkpoint;
- afwijkende eventflags, referenties, sorptiviteit en natte wandvelden.

Dit volgt rechtstreeks uit de oorspronkelijke interface: `readswap.f90:1159` waarschuwt `I/O of macropore variables from file (SWINCO=3) not implemented yet!`. De oorspronkelijke `swapoutput.f90:270–666`-routine `inoutend` bevat geen macrovoorraad, klok, event- of sorptiereferentietoestand. `DT` wordt wel geschreven/gelezen bij regel 465; toch kiest de native opstartroute een andere eerste dt (0,0001414213562 tegenover 0,00001 dag continu). De microsecondeprecisie van het oorspronkelijke datumformaat geeft bovendien een tijdafronding van −7,28×10⁻¹² dag. Geen van deze feiten verklaart of verhelpt de ontbrekende macrotoestand.

De eerste herstartstap eindigt daardoor op een ander tijdstip dan de continue vervolgstep. Hun verschillen na de stap worden niet als een vergelijking op gelijke tijd of als kwantitatieve trajectfout gebruikt. De mislukte toestandsgelijkheid vóór de stap is zelfstandig doorslaggevend. Dit is een reeds bestaande ontbrekende macroherstartondersteuning, geen aangetoonde regressie van de Darcy-patch en geen aanleiding om binnen deze ronde een algemene toestandsarchitectuur toe te voegen.

## Besluit en herstelpad

Voor deze oorspronkelijke natte context zijn echte afwijzing, oorspronkelijke rollback, ongereduceerde kleinere acceptatie, gepaarde waterinventaris en één volledige vervolgstep gekwalificeerd, met exacte directe controle en O0/O2-reproductie. Er is geen bewezen noodzaak voor aanvullende geheugenrollback in deze context. De kandidaat blijft geschikt voor verdere gerichte B1-kwalificatie, met expliciete uitsluitingen.

Eigen macroherstart is **FAIL / vooraf bestaande niet-ondersteunde interface**. Droge/eventovergangen, de h=0-overdracht, andere hydraulische modi en brede trajectgeldigheid blijven open. B0, B1.12, canonical en release zijn niet gewijzigd of gepromoveerd. Een vervolgstap moet eerst het concrete native macroherstartcontract afbakenen en de ontbrekende toestand bepalen; geen stille snapshotinjectie of replay en geen brede scenariozoektocht.

Herbeoordeling zonder modeluitvoering: `python research/swap431-macro-b1-retry07/assess_retry07.py`. `RESULT.json` bevat de volledige gemeten verschillen en controles. `RETRY07_EVIDENCE.zip` sluit aan op de drie bestaande capsules; `EVIDENCE.json` identificeert alle geverifieerde leden en de broncheckpoint.
