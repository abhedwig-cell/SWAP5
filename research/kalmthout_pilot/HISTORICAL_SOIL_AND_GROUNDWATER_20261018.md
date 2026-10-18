# Lokale heidebronnen, retentie en peilreeksen

Onderzoekswerk, 18 oktober 2026. SWAP4.3.1-project, geen wijziging van SWAP5 of canonical.
Basis: remote `d75fb5e28dc05bdb0fd2c8fe6b3fe2aa3133d338`; alle 14 gewijzigde bestanden van die oplevering zijn opnieuw tegen hun Git-blobidentiteit gecontroleerd.

## Werkelijke nieuwe broninhoud

De bodemkundige deelstudie van Hartmann en Verplancke (1981), UGent publicatie8505121, bevat zes lokale heideprofielen. Tabellen13-18 staan op PDF-pagina75-80. De lokale PDF-cache is visueel gecontroleerd, naast tekstextractie. Download:
https://biblio.ugent.be/publication/8505121/file/8527107.pdf

SHA256 `f0f177961cffcbe884a883fcb6f37529e03e321a12c8c6b0db2ad21cb3091d55`.
`collect_local_studies.py` bewaart ook de ecologische deelstudie (1981) en INBO PAS-analyse (2018), inclusief bronidentiteit. De oorspronkelijke rapporten worden niet in Git heruitgegeven.

De feitelijke retentiewaarden zijn vastgelegd in `local_sources/historical_retention_1981.csv`:35 regels, vijf pF-punten per regel. De eenheid blijft per regel expliciet. Vijf regels zijn gewichtspercentages zonder gemeten bulkdichtheid. Die worden niet als volumepercentage behandeld. Zeven andere volumeregels hebben een onopgeloste profielidentiteit: tabel16 noemt3b maar bevat podzolhorizonten die volgens beschrijvings-/textuurtabellen bij4b horen; tabel18 noemt4b maar heeft de regosolhorizonten van3b. Ook de gewichtsregel van tabel18 blijft geblokkeerd. Er is geen stille verwisseling toegepast.

De23 overige volumeregels zijn werkelijk gefit met van Genuchten, m=1-1/n. Theta_s is expliciet gelijkgesteld aan de gerapporteerde porositeit, niet aan een gemeten verzadigingspunt. Theta_r,alpha,n worden via deterministische multistart aangepast aan alle vijf punten. De residuen en actieve parametergrenzen zijn opgeslagen; een kleine fitfout is geen parameterzekerheid. Maximaal RMSE circa0.01166m3/m3. Veel theta_r-schattingen bereiken de bovengrens bij het droogste meetpunt. Deze fits zijn dus beperkte retentiebeschrijvingen, geen gekwalificeerde volledige hydraulische profielen.

Ksat en onverzadigde geleidbaarheid ontbreken in deze fitroute. De twee A1-regels van profiel2 blijven afzonderlijke monsters/varianten zonder verzonnen subdiepten. Verkitte horizonten en stuwwater worden niet opgelost door een textuur-PTF voor Ksat. Er zijn daarom geen nieuwe heidecellen automatisch aan deze curven gekoppeld en geen nieuwe native heideberekeningen geclaimd.

## Ondiepe grondwaterreeksen

`audit_groundwater.py` heeft alle193 eerder verzamelde exports gecontroleerd tegen de oorspronkelijke XML-hashes.77 filters bevatten werkelijk waarnemingen in de rekenperiode:17144 records, geen ongeldige datum/niet-eindige waarde. Geen filter heeft iedere dag van de1005-daagse periode een meting. Per reeks staan meetdagen, maanddekking, hiaten inclusief periodegrenzen, verschillende waarden op dezelfde dag, filterdiepten, kwaliteitsvlaggen en bronidentiteit in `groundwater_audit.json`.

Voor alle1024 cellen zijn de drie dichtstbijzijnde reeksen met echte periodewaarnemingen gelokaliseerd:3072 verwijzingen met afstanden. Nabijheid bewijst geen hydrologische representativiteit. Er is geen geïnterpoleerde of geëxtrapoleerde peilrand gemaakt en geen buisreferentiehoogte als celmaaiveld gebruikt.17088 periodewaarnemingen hebben onbekende betrouwbaarheid;56 zijn als goed gemarkeerd. Onbekend is niet als goed of fout hernoemd.

Een gerichte contracttest controleert randhiaten, onbekende kwaliteit, meerdere waarden op één dag, ontbrekende dieptemetadata en ongeldige waarden. Beide tests zijn echt uitgevoerd en geslaagd. De projectrunner voert deze audit en de historische retentiefit nu automatisch uit na bronverzameling.

## Vegetatie en beworteling: brondata ophalen

De bestaande DOV-observaties bevatten119 veldobservaties van bewortelingsdiepte,169 vegetatieobjecten en historische bodemgebruik-/watertafelgegevens. `collect_site_context.py` haalt hun oorspronkelijke XML op om echte waarnemingsdatum, getypeerde waarde en bronkwaliteit te bewaren. Een invoer-ID uit2019 is niet automatisch een meting uit2019: het gecontroleerde voorbeeld2019-002501 betreft beworteling op20april1951. Ophalen en dateren gaat vooraf aan enige gewastoekenning.

De verzameling is inmiddels echt voltooid:536 oorspronkelijke XML-exports, nul fouten,157 verschillende locaties.521 observaties vallen buiten de rekenperiode,14 erbinnen en één heeft geen datum. Alle119 bewortelingswaarnemingen dateren uit1951-1965; waarden4-200cm. De14 periodewaarnemingen zijn zeven bodemgebruik- en zeven vegetatierecords van12juni2024, hoofdzakelijk speelplaats/speelbos met beuk. Zij leveren geen heide-LAI of wortelverdeling. De automatisch gemaakte celindex omvat18432 verwijzingen: drie nabije observaties per bronparameter voor alle1024 cellen. Nabijheid is geen automatische toekenning.

Voorbeeld van de valkuil: de dichtstbijzijnde wortelwaarneming bij heidekandidaat KAL_0416 ligt circa2009m weg, stamt uit1965 en hoort bij historische permanente weide. Die van KAL_0876 ligt576m weg maar is een bosprofiel uit1954. Ze zijn niet als heideparameters gebruikt. De gehanteerde datums komen uit XML-fenomeentijd, niet uit invoerjaar of locatie-ID.

De publicatie Naseer et al.(2026), DOI10.1016/j.agrformet.2026.111070, vergelijkt Maasmechelen-heide en Brasschaat-bos. Het is geen Kalmthout-heidevalidatie. Eventuele toepassing is een expliciete externe analogie. Er is nog geen lokale volledige set voor seizoens-LAI, gewashoogte, weerstand, interceptie, wortelverdeling en opnamecriteria vastgesteld. Een historische worteldiepte is niet al die parameters tegelijk.

## Herstel en kwalificatie

De bestaande42 native bodemscenario's en70 celverwijzingen blijven hun eerdere beperkte kale-bodemstatus houden. Deze uitbreiding wijzigt geen native solver of modelacceptatiecriteria. Geen nieuwe volledige lokale vegetatiekwalificatie, geen canonical-admission.

Het volledige projectcommando is na de uitbreiding opnieuw uitgevoerd. Alle42 native postimages zijn met hun invoer-/uitvoerhashes en volledige kalender/balans gecontroleerd en hergebruikt, nul nieuwe native berekeningen. De profiel-/casemanifesten bevatten nu ook oorspronkelijke fenomeen- en resultaatdatums van de gebruikte textuurmetingen. Deze herkomstuitbreiding verandert geen fysieke SWAP-invoer. Het log staat in het aanvullende evidence-archief.

Aanvullende maaiveldroute: de officiële Vlaamse DTM-WCS levert GetCapabilities en DescribeCoverage, maar de concrete GetCoverage-aanvraag voor het gebied is daadwerkelijk met HTTP403 afgewezen. De precieze aanvraag en responsstatus zijn bewaard; er is geen DTM-raster ontvangen en geen celmaaiveld uit afgeleid. Een alternatieve officiële downloadroute blijft nodig. De dienstmetadata hebben bovendien een onbekende verticale bandeenheid; de productmetadata moeten TAW, opnameperiode en eventuele herprojectie/resampling bevestigen voordat toepassing verantwoord is.

De drie rapporten tellen samen256 PDF-pagina's. `study_manifest.json` bewaart hun individuele hashes. De collectorroutine vereist naast de Python-requirements de Poppler-programma's `pdfinfo` en `pdftotext`. De eerste gecontroleerde postimage van deze uitbreiding is remote `07f0ea62ac28c81525a099853f4211e6916e872e`; de geïntegreerde bronrunner is remote `8f08f4a8649527944d72e051d99682ad7494964e`. De latere opleveringscommit bevat de definitieve scripts en aanvullende evidence. Canonical blijft onaangeroerd door dit spoor.

Volgorde voor herstel:

```sh
python3 research/kalmthout_pilot/swap431/collect_local_studies.py RUNROOT/results/local_studies
python3 research/kalmthout_pilot/swap431/collect_site_context.py RUNROOT RUNROOT/results/swap431_site_context
python3 research/kalmthout_pilot/swap431/fit_historical_retention.py RUNROOT/results/local_studies/historical_retention_fits.json
python3 research/kalmthout_pilot/swap431/audit_groundwater.py RUNROOT RUNROOT/results/swap431_groundwater_audit
```

De volgende stap is de gedateerde lokale veldcontext bij de heide-eenheden beoordelen, ruimtelijke koppeling van de historische profielen kwalificeren en ontbrekende geleidbaarheids-/vegetatiegegevens uit aanvullende primaire bronnen onderbouwen. Geleidbaarheid en vegetatie worden niet door de automatisering verzonnen.

Het aanvullende `evidence/SYMPHONICA_LOCAL_CONTEXT_20261018.tar.xz` wordt na beide bestaande projectarchieven in dezelfde RUNROOT uitgepakt. Het bevat alle536 oorspronkelijke context-XML's, gedateerde observatie- en celindices, peilaudit en3072 grondwaterverwijzingen, studie-identiteiten, retentiefits, bijgewerkte bodem-/casemanifesten, hervattingslog en de mislukte DTM-aanvraag. Geen volledige rapport-PDF's. `local_sources/context_evidence_manifest.json` bevat de archiefidentiteit en individuele bestandshashes.
