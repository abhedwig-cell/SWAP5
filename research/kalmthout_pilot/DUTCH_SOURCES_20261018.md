# Nederlandse aanvulling voor SYMPHONICA Kalmthout

## Bronnen en afbakening

Werkbranch `research/kalmthout-local-sources-20261018`. Aanvulling op de oorspronkelijke SWAP4.3.1-projectroute; geen SWAP5- of canonical-wijziging.

De broninventaris heeft 203 cellen met minder dan 95% Vlaamse bodem- of landgebruiksdekking. Deze selectie omvat de 145 cellen waarvoor de bestaande scenariotoekenning geen bodem- of landgebruiksdekking vond. De selecties zijn niet identiek.

De officiële WUR-API https://www.soilphysics.wur.nl/soil.php is daadwerkelijk opgevraagd voor de 203 celcentra. Zij levert 172 afgeleide modale profielen en 31 expliciete antwoorden zonder bodeminformatie, nul fouten. Het gaat om 14 verschillende profielen, niet om 172 gemeten lokale boringen. De bronbeschrijving https://www.soilphysics.wur.nl/ vermeldt afgeleide standaardprofielen op basis van De Vries (1999). Bronlaagversie en actuele lokale representativiteit zijn niet vastgesteld. Alle oorspronkelijke antwoorden en exacte coördinaten zijn opgeslagen. Een centrumprofiel zegt niets over het hele celoppervlak of de verdeling binnen een mengcel.

De officiële PDOK-laag https://api.pdok.nl/kadaster/brt-bodemgebruik/ogc/v1/collections/landcoverunit/items levert 9826 oorspronkelijke landbedekkingsvlakken in tien gepagineerde antwoorden, zonder dubbele feature-identiteiten. Werkelijke geometrische doorsnijding op EPSG:32631 geeft enige dekking in 220 cellen en minstens 95% in 176 cellen. De maximale overlapfractie is circa 0.000215; overlap blijft apart zichtbaar en wordt niet dubbelgeteld in de dekkingsfractie. Geen ongeldige geometrieën aangetroffen. Waarnemingsdatums lopen van 2002-12-31T23:00:00Z tot 2024-12-31T23:00:00Z en blijven letterlijk behouden. Dit is geen uniforme opname van 2024-2026. De klassen zijn niet gelijkgesteld aan Vlaamse landgebruiksklassen of BWK-habitatcodes.

De CBS Existing Land Use-API blijkt in de gecontroleerde regionale steekproef BBG2017 te leveren. CBS biedt inmiddels NBBG2022 aan via https://geodata.cbs.nl/files/Bodemgebruik/NBBG2022/ , maar de nationale ZIP-downloads zijn 473 MB tot meer dan 2 GB. Deze zijn nog niet opgehaald. De oudere CBS-steekproef wordt niet als actuele landgebruiksinvoer gebruikt. BOFEK2020 en zijn officiële profieltabellen zijn als aanvullende bron gevonden, maar niet als ruimtelijk toegewezen profiel gebruikt.

## Modelrespons en uitvoeringsselectie

`run_dutch_soil_responses.py` berekent per verschillend WUR-profiel twee kale-bodemresponsen: nulflux en vrije drainage. Alle genoemde centrumcellen verwijzen naar de passende profielrespons; dit is geen oppervlaktegewogen celbalans of vegetatiesimulatie. De 14 profielidentiteiten worden niet uitsluitend op bodemcode samengevoegd: verschillende horizontopbouwen bij dezelfde code blijven onderscheiden.

De gerapporteerde horizontgrenzen worden letterlijk gebruikt en niet naar grotere diepte geëxtrapoleerd. De Staringbouwsteennamen worden expliciet aan de parameterset 2018 gekoppeld, bijvoorbeeld B1 naar B01. Retentie, gefitte Ksat en Mualemlambda komen voor deze scenario's uit de vastgelegde tabel 2018. Dit zijn externe klassepriors; de WUR-punt-API zelf levert geen lokale hydraulische meting. BDENS1500 blijft ongebruikte metadata bij uitgeschakelde warmte/solute/zuurstof, geen gemeten dichtheid. Kale bodem, RSOIL0 uit de technische referentie, uniforme initiële h=-75 cm en twee onwaargenomen onderranden zijn expliciete scenarioaannamen.

De volledige bestaande 24120 uur ERA5 wordt hergebruikt met oorspronkelijke SWAP Penman-Monteith, SWMETDETAIL1/SWRAIN0, wind op 10 m en temperatuur/vocht op 2 m. Werkelijke regen blijft uurlijks. Geen verlaagde verdampingsvraag, geen versoepelde numerieke criteria of solverwijziging. De oorspronkelijke executable SHA256 is `2e46b6c9cc53e548c401670bd3e0e8df7799e8f95dfed4c77b7454edcf79bc07`.

De eerste invoerpoging is afgewezen door TTUTIL: de initiële diepte was als integer geschreven tussen real-waarden. Dat literal is gecorrigeerd. De eerste nacontrole miste de native conventie dat inactieve TACT/EIC-kolommen ontbreken bij SWCROP0. De validator controleert nu expliciet dat vegetatie uitstaat en vereist actieve kolommen. Negatieve invoer en logs blijven bewaard; geen native controle is veranderd.

Selectie voor de volledige modelbatch: veranderde onderzoeksdriver en expliciete fysieke invoer, ongewijzigde native executable en numerical settings. Eerste gekwalificeerde profielrun: 8.719503784 s native wandtijd, 1005 dagen werkelijk voltooid met native succesmarker en kalender-/balans-/bergingscontrole. Verwacht voor 28 verschillende runs circa 270 s op deze host, op basis van de eerste uitvoering; verschillen tussen profielen kunnen dat verhogen. Per run geldt een uitvoeringslimiet van 120 s, uitsluitend als tijdscensuur en nooit als bewijs van numeriek falen. Een identieke succesvolle run wordt na hashcontrole hergebruikt. De initiale bronophaling duurde meerdere minuten door 203 afzonderlijke locatieaanvragen; broncache en bronresponsen worden behouden. Geen brede SWAP5-kwalificatie of Actions geselecteerd.

## Herhaalbaar projectcommando

```sh
python3 research/kalmthout_pilot/swap431/run_symphonica.py \
  RUNROOT /absolute/path/swap_gnu \
  /absolute/path/weather.csv /absolute/path/era5_endpoint_20261002.json \
  /absolute/path/grid_500m.csv \
  --wet-heath --dutch-sources --dutch-soil-responses --recorded-studies
```

`--recorded-studies` gebruikt de eerder vastgelegde bronidentiteiten en repositorytabellen zonder heracquisitie van de niet-heruitgegeven studie-PDF's. Zie de afzonderlijke herstelproef met 58 gecontroleerde bestaande native resultaten in `HOURLY_WET_HEATH_20261018.md`.

De Nederlandse broncontext en modelresultaten mogen de eerdere teller van 70 dominante Vlaamse bodemrespons-cellen niet automatisch vervangen. De samplingeisen en bronsemantiek verschillen. Actuele vegetatie, oppervlaktemenging, initialisatie en lokale onderranden blijven nodig voor echte celresultaten.
