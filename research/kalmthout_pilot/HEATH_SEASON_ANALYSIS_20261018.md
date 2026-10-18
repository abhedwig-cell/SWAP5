# Seizoensanalyse begroeide heideprofielen

SYMPHONICA, 18 oktober 2026. Basis `b0a4cba3d8b6e7862e075167ba9e4d87af8490d0` op `research/kalmthout-local-sources-20261018`. Dit werk gebruikt bestaande SWAP4.3.1-uitvoer. Geen nieuwe native berekeningen, SWAP5-werk of Actions.

## Uitgevoerde controle

Alle 16 begroeide historische profielscenario's zijn uit het opgeslagen heidearchief hersteld. Elke oorspronkelijke invoer- en uitvoerhash in de runreceipts is gecontroleerd, evenals de native succesmarker, executable-identiteit en de bestaande kalender-, waterbalans- en fysieke voorraadcontrole. De gedeelde meteorologie en regenbestanden zijn op hun oorspronkelijke hashes gecontroleerd. Het analyseprogramma geeft 656 periodebalansen en 10496 gepaarde componentverschillen. De 16080 dagelijkse eindtoestanden zijn opnieuw gecontroleerd. Er is geen nieuwe modelvalidatie tegen waarnemingen uitgevoerd.

Maand-, jaar- en april-septembertotalen omvatten bodem, plas en canopy. De bergingsverandering van elke maand begint bij de vorige dagelijkse eindtoestand. De som van de maandcomponenten en bergingsveranderingen reproduceert het volledige resultaat binnen 1e-8 mm. Dat is een boekhoudcontrole op de afgedrukte uitvoer, geen aangescherpte native solvergrens. De bestaande native EIC-term omvat ook verlies van canopycapaciteit bij jaarovergangen en wordt niet als zuivere interceptieverdamping benoemd.

De volledige analyse is afzonderlijk herhaald. Beide CSV-bestanden en de auditreceipt zijn bytegelijk. Een negatieve proef met een gewijzigde native uitvoer wordt vóór de analyse expliciet op hashverschil afgewezen. De vier bestaande peil- en LAI-contracttests slagen. Geen solverherkwalificatie geselecteerd: native code en invoer zijn ongewijzigd.

## Resultaten en betekenis

Alle waarden in de volgende tabel gelden voor 1 april tot en met 30 september. De bandbreedte is het minimum en maximum over de 16 expliciete scenario's, geen kansinterval. TPOT is de native potentiële transpiratie na de gebruikte gewas- en interceptiebehandeling; het is geen onafhankelijke atmosferische referentieverdamping.

| Jaar | Neerslag mm | Actuele transpiratie mm | Tekort ten opzichte van TPOT mm | Actueel / potentieel |
| --- | ---: | ---: | ---: | ---: |
| 2024 | 605.7 | 118.8 tot 131.1 | 0.0 tot 0.2 | 99.9 tot 100% |
| 2025 | 256.5 | 72.7 tot 171.9 | 17.2 tot 110.4 | 39.7 tot 90.9% |
| 2026 | 324.5 | 97.9 tot 180.8 | 11.0 tot 85.8 | 53.3 tot 94.3% |

De minima en maxima van verschillende kolommen hoeven niet hetzelfde scenario te betreffen. De natte eerste zomer onderscheidt de scenario's weinig naar transpiratiebeperking. De twee volgende zomers doen dat wel. Dit volgt uit modeluitvoer voor historische retentie en expliciete externe priors, niet uit gemeten lokale vegetatiestress.

De volledige 2x2x2x2-opzet maakt vergelijking mogelijk met steeds drie factoren vast. Acht paren per factor:

| Verandering, volledige 1005 dagen | Verschil actuele transpiratie mm | Betekenis binnen deze opzet |
| --- | ---: | --- |
| Nulflux naar vrije drainage | -134.5 tot -92.2 | Groot effect van de gekozen onderrand; netto onderranduitvoer 706.8 tot 749.2 mm |
| A1-retentiemonster 1 naar 2 | -64.3 tot -35.0 | Ook de twee lokale toplaagvarianten zijn materieel verschillend |
| Canopycapaciteit 0.5 naar 1 mm per LAI | -40.9 tot -37.1 | Potentiële transpiratie verandert mee; het verschil in TPOT minus TACT is slechts +1.3 tot +5.1 mm |
| Worteldiepte 35 naar 50 cm | -9.7 tot +8.2 | Kleinere, wisselende respons in deze geselecteerde profielen |

Een diepere wortelzone hoeft hier door terugkoppeling met bodemverdamping en berging niet ieder scenario meer totale transpiratie te geven. De kleine gemiddelde gepaarde respons bewijst evenmin dat worteldiepte in het gebied onbelangrijk is. De rangorde hangt af van de gekozen variatiebreedten, profielen en interacties. Bij interceptie mag een daling van TACT niet zonder TPOT als extra droogtestress worden uitgelegd.

## Vervolg naar lokale modellen

De eerstvolgende locatiekeuze moet de onderrand en de doorlatendheid van de verkitte horizont gezamenlijk onderbouwen. Vrije drainage en nulflux blijven gevoeligheidsscenario's; dit zijn geen bewezen boven- en ondergrenzen voor de werkelijke waterbalans. Nabije peilfilters hebben al bron- en hoogtegegevens, maar hun representativiteit, referentievlak, hiaten en filterstelling moeten per geselecteerd heide-eenheid worden beoordeeld. Een peilreeks wordt niet automatisch naar een cel verplaatst.

Huidige heide-eenheden zijn nog niet aan het historische profiel gekoppeld. Er is dus geen ruimtelijke kaart met 1024 voorspelde celwaterbalansen gemaakt. De lopende Nederlandse 28-runbatch op het bronnenspoor wordt niet herhaald of als voltooid geclaimd. Deze analyse vult de reeds afgeronde heideroute aan zonder de batch of broncollector te wijzigen.

## Herhalen

Na uitpakken van `evidence/SYMPHONICA_HOURLY_HEATH_20261018.tar.xz` in RUNROOT:

```sh
python3 research/kalmthout_pilot/swap431/summarize_heath_seasons.py \
  RUNROOT/results/wet_heath_scenarios OUTPUT
```

Uitvoer: `heath_period_balances.csv`, `heath_paired_sensitivities.csv` en `heath_analysis_receipt.json`. De receipt bewaart de gecontroleerde bronpostimages en hashes van de twee CSV-bestanden. Het script heeft uitsluitend Python-standaardbibliotheek en de bestaande native uitvoervalidator nodig. Een nieuwe GNU-build of een nieuwe brondownload is hiervoor niet nodig.

Herstelstatus: geïmplementeerd en lokaal getoetst; onderzoekspostprocessing, geen canonical-admission of kwalificatie van huidige celvoorspellingen. Aan deze tak zijn geen architectuurinterfaces, native solvercriteria of fysieke modelparameters veranderd. De bestaande massabalans- en herkomstgrenzen blijven gelden.
