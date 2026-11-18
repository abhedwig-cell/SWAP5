# REFERENCE46 - gekwalificeerde, beperkte diagnose

De theoretische sorptiereferentie blijft bij deze 90 events niet terecht exact ongewijzigd. De in REPAIR43 toegevoegde eindcontactfactor maakt de volledige theoretische increment nul, hoewel in dezelfde geaccepteerde tijdstap positieve sorptie bij positief contact plaatsvindt. Dit is een afgebakende inconsistentie in de contactweging van het referentiegeheugen. De klokcorrectheid uit CLOCK45 blijft overeind.

## Contract en bewijs

De SWAP4-handleiding (Kroes e.a. 2017, WER2780, gedrukte pagina 106, vergelijkingen 6.54-6.55) onderscheidt theoretische eigen sorptie met de oorspronkelijke sorptiviteit van de actuele vochttoestand, die ook verticale stroming en wortelopname bevat. De afwijking tussen beide corrigeert de actieve sorptiviteit. De broncode bewaart hiervoor `ThtSrpRefDmCp = theta_s + theta_theoretical - theta_initial`. Deze hulpgrootheid is geen actuele watervoorraad en hoeft niet gelijk te zijn aan de daadwerkelijk begrensde sorptiebijdrage.

Dezelfde oorspronkelijke checkpoint en dezelfde 360 geaccepteerde stappen zijn gebruikt. De selectie is onveranderd: domein 3, node 50, pogingen 36 t/m 125. Elke geselecteerde stap heeft positieve geaccepteerde sorptie, positieve oorspronkelijke sorptiviteit, positief RATE-contact en positieve contactleeftijdstoename. Alleen het nieuwe eindcontactgewicht is nul: na uitstroming ligt de macro-waterstand op de GWL/minimumvoorraad, terwijl de cel nog gedeeltelijk macro-waternat is. Het eindpunt is daarmee niet representatief voor de positieve contactbijdrage die de geaccepteerde gemiddelde rate gedurende deze tijdstap heeft gehad.

De referentie blijft alle 90 stappen exact 0.4440013882531527. De geregistreerde actieve sorptiviteit wordt exact door de bestaande correctieformule gereconstrueerd; de geregistreerde sorptie volgt de oorspronkelijke Philip-increment, vervolgens de bestaande contactweging en voorraadbegrenzing. Er is geen piekfluxcap actief voor deze sorptiebijdrage.

Een uitsluitend algebraische schaduw met oorspronkelijke sorptiviteit en de positieve geometrische coefficient uit de geaccepteerde RATE geeft per stap 1.64431659075e-10 tot 5.97781026087e-10 referentietoename; som 1.78293208357e-8. Ook vermenigvuldiging met de bestaande positieve voorraadfactor laat de som positief: 9.40041308158e-9. Iedere onbegrensde schaduwincrement is meer dan een miljoen ulps van de opgeslagen referentie. De nul is dus geen afronding. De werkelijke sorptiebijdrage aan theta sommeert tot 3.81650714052e-8; gelijkheid met de theoretische teller wordt uitdrukkelijk niet vereist.

Deze schaduwen zijn gevoeligheidsbewijzen voor de onjuiste nul, geen uitgevoerde fysieke trajecten, geen voorspelling van een gecorrigeerd vervolg en geen unieke vervangingsformule. De precieze behandeling van veranderende geometrie en voorraadbegrenzing moet voor een reparatie expliciet worden vastgelegd en gekwalificeerd. Een geldige minimale correctie moet het oorspronkelijke theoretische karakter en de doorlopende contactklok behouden en het contact consistent met de tijdstapbijdrage behandelen. Alleen de eindcontactfactor verwijderen zonder dat contract te toetsen is hiermee nog niet toegelaten.

## O0/O2 en grenzen

Prebuild broncheckpoint: 1d3386188. Baseline CLOCK45: 77aaff9c08f921430b8c91d89cb91ac9a1afdb78. O0: 2.0872203 s; O2: 1.7329820 s. Beide normaal afgesloten, ruim binnen hard20; intern16, 512-commitcap en vaste observatiehorizon behouden. Geen extra provider-evaluaties. Alle bestaande numerieke tekstuitvoer is bytegelijk aan CLOCK45, inclusief historie, ledgers, inventaris en eindtoestand; pogingregels gelijk na uitsluiting van de tijdmeting. De nieuwe waarnemingen zijn eveneens O0/O2 exact gelijk. De assessor verwijdert de geregistreerde observertoevoegingen en vergelijkt alle numerieke bronnen met de ouder.

Geen wijziging van fysica, referentie, klok, solver, tolerantie, MAXIT, dt, fluxreductie of budgetregels. Geen ontbrekend water aangetoond; de fout betreft de theoretische referentiebijwerking. Geen brede campagne, extra context, nieuwe herstart of volledige-periodekwalificatie. B1 blijft B1_CANDIDATE_WITH_EXPLICIT_EXCLUSIONS; B0, B1.12 en canonieke release blijven beschermd.

## Herleidbaarheid

- Primaire handleiding: https://edepot.wur.nl/416321 ; PDF SHA256 1cf1c350870fc7f7923dc17878fefa0dd2dc58b40fffb34b8d255d5a7fd2a82e; bestaande visuele broncontrole CONTRACT42 manual-108.png.
- `macropore_native.f90`: bestaande history_contact43-weging van ThtSrpRefDmCp en ongewijzigde TimAbsCumDmCp += DT.
- `macrorate_node.f90`: bestaande ABSORPTION met oorspronkelijke en actieve sorptiviteit; uitsluitend observatie toegevoegd.
- `SAME90_REFERENCE_AUDIT.csv`, `RESULT.json`, `TRACE_FIELDS.json`, onbewerkte traces en run-/bronidentiteiten; verzegeld via EVIDENCE.json en REFERENCE46_EVIDENCE.zip.
