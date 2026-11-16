# LEDGER12 — cumulatieve numerieke wateruitvoer rond dezelfde daggrens

**Lokale numerieke uitvoercontinuïteit: PASS met O0/O2. Volledige oorspronkelijke periodebalans: niet gekwalificeerd wegens reeds ontbrekende historie.** De geaccepteerde fysieke daggrensherstart blijft exact. De beperkte uitbreiding bewaart nu ook cumulatieve en tussenliggende waterintegralen, balansbeginwaarden, uitvoerperiode en het werkelijk benodigde uitvoergeheugen.

## Afgebakend contract

Dezelfde oorspronkelijke context als MIDNIGHT11 wordt gebruikt: het bestaande DAY10-bestand vlak vóór de grens, volledige oorspronkelijke dagafsluiting op t1900=35797, eigen bestand en één echte volgende-dagstap. Een verse herstart moet de **op dat moment daadwerkelijk aanwezige** numerieke wateruitvoertoestand behouden en dezelfde cumulatieve toenamen geven als continu. Dit contract omvat niet het terughalen van informatie die het eerdere B-bestand nooit bevatte, noch bytegewijs toevoegen aan oude CSV/BAL/BLC/PEARL-bestanden.

Uitgangscommit `5306c47c7c80612a4c913a16e2a4b024db868543`; remote canonical blijft `f9ada0cb2134971f92267a209f3a1fc86901dda8`. Alleen de nieuwe onderzoekssubmap is gewijzigd. Geen wijziging van B0, B1.12, canonical, release of andere werkstromen; geen promotie.

## Ontbrekende toestand en minimale aanvulling

De oorspronkelijke native bestanden missen de macro-cumulatieven CQMp*, tussenintegralen IQ*/IAv*, beginvoorraden WaSrDm*Ini/IWa*Beg en de overeenkomstige matrix-/drainage-integralen en uitvoerperiodetellers. `LEDGER_FIELDS.json` bevat de expliciete lijst van132 velden, met eigenaar, type en vorm. Het betreft een vast wateruitvoerblok voor deze geselecteerde casus, geen algemene toestandsarchitectuur.

V3 voegt dit getypeerde blok toe aan het reeds gekwalificeerde completed-day-formaat. Alle waarden worden eerst in een lokale buffer gelezen en op marker, veldtelling, volledigheid en eindigheid gecontroleerd. Na de native initialisatie worden ze geïnstalleerd; de normale volgende-dag-resets blijven ongewijzigd en gebeuren op dezelfde hostfase als continu. Herstel van numerieke uitvoer wordt expliciet aangevraagd. Een oud V2-bestand zonder de vereiste integralen wordt dan vóór installatie afgewezen; oude fysieke bestanden mogen wel als de vastgelegde bootstrap worden gebruikt, met expliciet ontbrekende eerdere historie.

De eerste onderscheidende proef vond precies twee afwijkende uitvoervelden na de stap: IAvFrMpWlWtDm1 en IAvFrMpWlWtDm2. De oorzaak is de oorspronkelijke lokale `FrMpWalWetOld` in MACROINTEGRAL, die de gelijknamige modulevariabele overschaduwt. In deze native compilerclosure bleef de lokale array effectief tussen aanroepen bestaan, maar zij werd bij een vers proces niet hersteld. De gemeten afwijkingen waren 8,66681×10⁻⁵ en 2,55877×10⁻⁵ dag in de tijdgewogen wandintegralen.

Uitsluitend dit uitvoergeheugen is expliciet eigendom van MOD_macropore gemaakt als `FrMpWalWetIntegralOld`, met beginwaarde nul en opname in het native uitvoerblok. De gemiddelde-wandformule, debietintegratie en fysieke uitwisseling veranderen niet. De nieuwe continue uitkomst is voor alle131 eerder gemeten velden exact gelijk aan de oorspronkelijke continue pilot; de geherstarte uitkomst is nu ook exact. Er is geen algemene uitspraak dat de oorspronkelijke impliciete opslag portabel correct was. `preliminary-shadow/` bewaart de fout en oorspronkelijke postimage; `preliminary-ledger-only/` bewaart de eerste exacte herstelproef vóór toevoeging van de daadwerkelijke renderercontrole.

## Werkelijk uitgevoerde kwalificatie

Er zijn vier definitieve positieve routes (continu/eigen herstart met O0/O2), één vroege afwijzing van een oud bestand zonder vereiste historie, en vier bewaarde positieve pilotroutes. Iedere modelroute bleef onder één seconde; de langste definitieve route duurde0,627 seconde. De limiet blijft twintig seconden. Er is één afzonderlijk bewaarde compilefout door de verkeerde eigenaar van `snowinco`; geen model was toen gestart. Geen volledige twee dagen,481dagen of nieuwe scenariozoektocht.

De uitvoertoestand is bytegelijk bij installatie, na de echte volgende dagstart/vóór headcalc en na de volledige volgende-dagstap. De oorspronkelijke fysieke velden, temperaturen en gewascontext blijven bytegelijk aan de continue route, met dt0,0001733361984161963 en eindtijd35797,0001733362. De onafhankelijke fysieke inventarisafwijking blijft −1,35928×10⁻¹⁴cm; de maximale gepaarde uitwisselingsafwijking2,77556×10⁻¹⁷cm/d.

Los van deze gelijkheidsvergelijking zijn de cumulatieve toenamen van bodemflux, drainage, snelle macrodrainage en netto matrix-macrouitwisseling gecontroleerd tegen de primitieve werkelijk gebruikte debieten maal dt. De writer verandert geen gemeten integralen of voorraden. Alle tekstuele meetvectors zijn exact tussen O0 en O2.

Daarnaast is de **oorspronkelijke OUTBMA-routine** werkelijk aangeroepen na de geselecteerde stap. Haar volledige inhoud is exact tussen continu en herstart, met uitzondering van de besturingssysteem-tijdstempel `Generated at`. Dit is een rendererprobe: tijdelijk wordt de geldige eerste-balansrecordtak ioutdat=2 gekozen en daarna de echte teller teruggezet. De routine en opmaak zijn niet nagebouwd. Voor deze casus met macroporiën vanaf het oppervlak verandert OUTBMA geen geselecteerde cumulatieve toestand; de voor-/nadump is exact. Dit is geen bewijs dat een natuurlijk gepland eindperiode-uitvoerevent of bestandsappend is doorlopen.

## Essentiële historische grens

Het bestaande oorspronkelijke B-/DAY10-bootstrapbestand bevatte geen uitvoerhistorie. De aanwezige macro-beginvoorraden zijn daardoor nul, terwijl de huidige macrovoorraad ongeveer2,02cm bedraagt. De originele OUTBMA-probe laat dit ook zien; haar periode-etiket volgt het oorspronkelijke TSTART en is geen geldig bewijs van een gereconstrueerde totaalbalans vanaf die datum.

Er zijn geen eerdere totalen verzonnen en geen beginvoorraden stil herijkt om een balans te laten sluiten. De lokaal opgebouwde integralen worden nu wél correct over de onderzochte herstart bewaard. Daarmee is het **transport en de voortzetting van de aanwezige uitvoertoestand** gekwalificeerd, maar de wetenschappelijke geldigheid van de cumulatieven over de volledige oorspronkelijke periode niet. Die claim vereist echte uitvoerhistorie van dezelfde kandidaat vanaf de bedoelde balansoorsprong. Een oude V1/B0-campagne met andere fysieke uitwisseling kan die historie niet vervangen. De huidige grenzen rechtvaardigen geen nieuwe brede campagne om haar alsnog te verkrijgen.

## Besluit en herstelpad

Status blijft B1_CANDIDATE_WITH_EXPLICIT_EXCLUSIONS. Gekwalificeerd zijn de132 geselecteerde numerieke wateruitvoervelden, lokale primitieve toenamen en de BMA-rendererinhoud over deze completed-day-checkpoint en één volgende stap met hetzelfde native ABI. Niet gekwalificeerd zijn volledige oorspronkelijke periodebalansen, daadwerkelijke bestandsappend/planning, volledige CSV/BAL/BLC/PEARL-ketens, andere domeinaantallen/modes, gereduceerde toestand of brede trajecten.

Herbeoordeling zonder model: `python research/swap431-macro-b1-ledger12/assess_ledger12.py`. Lees STATUS.json, RESULT.json, LEDGER_FIELDS.json en output_continuity.patch. Bronnen, succesvolle en onderscheidende mislukte proeven en native closure zijn verzegeld. De volgende stap moet eerst het gewenste historische balansbegin en de beschikbaarheid van echte historie afbakenen; een lokaal continuïteits-PASS mag niet als volledige periodekwalificatie worden gepresenteerd.
