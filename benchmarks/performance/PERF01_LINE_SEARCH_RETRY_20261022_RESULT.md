# Productie-optie voor goedkoper afbreken van vastgelopen Newton-pogingen

De expliciete optie `weather_line_search_retry` is geïmplementeerd op de echte
Reference-route. Ze staat standaard uit. Bij een volledig mislukte
dempingszoektocht eindigt de Newton-fase eerder; de bestaande corner-herstart
of kleinere tijdstap volgt. Alle criteria voor een geaccepteerde oplossing
blijven gelijk. De warme start staat eveneens uit.

Geïntegreerd via PR1378 op `a1f9fb2b6e756c3178c02dda2de8aa2d6160d14e`.
De complete samengevoegde boom is exact de gekwalificeerde boom; de
bron-/bewijscontrole en15 afwijzingscontroles slagen op die werkelijke merge.
Het definitieve bewijs staat in `PERF01_LINE_SEARCH_RETRY_ADMISSION_20261023.json`.

## Rekentijd van de daadwerkelijke implementatie

Drie afwisselende seriële paren per neerslagreeks, dezelfde nieuwe O2-code,
dezelfde kolom en dezelfde nauwkeurigheid van 1e-3 cm, telkens 97 dagen:

| Neerslag | Optie uit, mediane CPU | Optie aan, mediane CPU | Verschil |
| --- | ---: | ---: | ---: |
| 1x, 227 mm | 2.599610 s | 2.502851 s | -3.7%, vrijwel gelijk |
| 4x, 908 mm | 8.596678 s | 5.603282 s | -34.8% |

Dit omvat de extra controle die de optie tot de toegestane route begrenst.
Daarom vervangt deze tabel de eerdere onderzoeksmetingen voor een claim over
de daadwerkelijke implementatie. Er liep geen eigen compilatie tijdens de
paren. Er is hostvariatie; dit is geen algemene of regionale snelheidsbelofte.
De oorspronkelijke CPU-samples en dagelijkse werktellers zijn bewaard.

Bij 4x blijven de werktellers gelijk aan de onderzoeksvariant: 20.1% minder
Jacobiaanopbouwen en 55.3% minder dempingspogingen. Er worden iets meer pogingen
afgewezen, maar de vastgelopen pogingen kosten veel minder werk. De oplossing
verandert geen bovenrandformule of tijdstapgroeibeleid.

## Fysieke uitkomst en behoud

Alle dagen voltooien voor 1x/4x, optie uit/aan, O0/O2. Met de optie aan zijn
de fysieke stdout en bestaande werktellers exact gelijk aan het eerder
gekwalificeerde onderzoek. Bij 4x is de grootste dagelijkse bergingsafwijking
tegenover uit 0.000068285 mm en de totale runoffafwijking +0.000124473 mm.
Eindberging, gewasbiomassa, LAI en transpiratie blijven exact in deze kolom.
Bij 1x blijven alle vergeleken fysieke waarden exact. Onafhankelijke dagelijkse
waterbalansen sluiten tot ongeveer 2e-13 mm.

De 21-provider directe test bewijst daadwerkelijke activering: een mislukte
fase gaat van 20 naar 13 Jacobiaanopbouwen, zonder een mislukte oplossing te
accepteren of de fysieke basis te wijzigen. Een onbekend wortelprovidertype en
een sensitiviteitsverzoek behouden exact hun oude route. De bestaande typed
minimumtijdstapgrens blijft vóór HeadCalc afwijzen. Original retry-, corner-,
bovenrandafgeleide- en warme-start/fallbackasserties slagen op O0 en O2.

Na de wijziging van het numerieke type zijn de getroffen weather-, kolom- en
nutriënten-builds volledig herbouwd. De oorspronkelijke SOL/ETref/gewas-,
wortelsubstap- en NUT cold/thermal/calendar/harvest/saved-outputasserties slagen
op nieuwe native uitvoer. 306 bestaande fysieke bestanden/streams blijven
exact. Herstart na natte dag 35 en volledige rollback van 21 vastgelegde
64-bitwaarden slagen met de optie uit en aan. Vier bestaande warme seizoenen
blijven behouden. De ongewijzigde reader-builds worden uitsluitend gedeeld na
volledige bron- en invoeridentiteit.

De complete oorspronkelijke bronautoriteit op canonical 17a6c17a met 34 controles
blijft behouden. De nieuwe exacte bronopvolger slaagt voor 15 controles en alle
vijf owning entrypoints. De volledige oorspronkelijke FSI35 O0/O2-runner is
opnieuw uitgevoerd en slaagt in 36.921 s; de eerdere native PASS is hiervoor
niet overgenomen. Originele asserties zijn niet verwijderd of versoepeld.

## Gebruik en grens

Selecteer vóór het initialiseren van de bestaande weather-applicatie:

```fortran
config%tiles(1)%parameters%weather_line_search_retry = .true.
```

De typed-solvernaam is `abort_failed_line_search`. De service begrenst activering
tot dynamische bovenrand, continue default-MvG, middeling 1, vrije onderrand 7
en herkende voorgeschreven bron-/wortelproviders. Andere configuraties behouden
de oorspronkelijke route. Er is geen nieuwe restartpayload of fysieke toestand.

De wetenschappelijke claim blijft de geteste kolom en de geraakte bestaande
behoudsgrens. Vooral een niet-monotone Newton-reeks kan soms later nog herstellen;
de nieuwe optie kiest dan eerder de bestaande kleinere-staproute. Een algemene
convergentiegarantie of volledige bodem-/veldkalibratie wordt niet geclaimd.
Er zijn geen nieuwe 1e-6-, hoogste-low-air- of uitgebreide RossFast-runs geselecteerd.

Bronnen, ruwe uitvoer, getoetste postimages en indexen staan in de bijbehorende
status en de capsules `PERF01_LINE_SEARCH_COMPOSITION_20261022_EVIDENCE` en
`PERF01_LINE_SEARCH_RETRY_SOURCE_20261022`. De status registreert kwalificatie
en daadwerkelijke canonical-admission afzonderlijk.
