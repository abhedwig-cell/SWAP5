# Uurlijkse heideprofielscenario's en actuele satellietgegevens

Onderzoeksspoor SYMPHONICA, 18 oktober 2026. SWAP4.3.1, geen SWAP5-wijziging en geen canonical-admission. Herstelbasis remote3683fbbb217e57f49e0f63746216fbb56b9d764d, lokale basis13e3f51.

## Afbakening

Ontbrekende lokale metingen maken een verkennende berekening met expliciete priors niet onmogelijk. Ze begrenzen wel wat de uitkomst betekent. Deze uitbreiding berekent een historisch nat-heideprofiel met lokale gemeten retentie en externe vegetatie-/geleidbaarheidspriors. Zij kent die respons niet automatisch toe aan huidige heidecellen. De eerdere42 kale-bodemscenario's blijven afzonderlijke resultaten.

## Nieuwe primaire bronnen

De NHI-pagina https://nhi.nu/tooling/gewasweerstanden-tool/ verwijst naar het pakket:
https://nhipackages.blob.core.windows.net/packages/gewasweerstanden-tools-en-rapportage.zip

Het pakket is werkelijk opgehaald,338901074 bytes, SHA256 `0e176069c2df49ac7388e0fd928904e6255a56196e005fb0306d7d6f2cc2430d`. Het bevat een apart pakket voor niet-landbouwgewassen. De volledige Windows/R-omgeving wordt niet uitgevoerd. Alleen bronparameters, oorspronkelijke bestanden en resultaten worden gelezen. Het rapport is *Kalibratie gewasweerstanden nietlandbouwgewassen*, HKV PR4624.10, maart2023. De metadata en relevante oorspronkelijke invoerbestanden worden apart bewaard.

Voor heide bevat de kalibratie op uurbasis over1991-2020 RSC288.84s/m, Rsoil150s/m, albedo0.3, Kdif0.60 en Kdir0.75. De366 LAI-waarden in `Basisdata/msw_templates/fact_svat.inp`, vegetatie-index14, liggen tussen1.0 en2.5. De heidecode20 verwijst naar deze vegetatie-index. De dagkalibratie geeft een andere weerstand en een ander interceptieconcept. Die waarde is niet stilzwijgend overgenomen.

NHI heeft de weerstanden afgestemd op een langjarige gewasfactorreferentie, niet op Kalmthoutse fluxmetingen. Het is dus een prior. Ook het interceptiecontract verschilt: de NHI-uurinstelling gebruikt een constante Ruttercapaciteit1mm. De oorspronkelijke SWAP4-invoer ondersteunt een capaciteit per LAI. Daarom worden0.5 en1mm/LAI als expliciete gevoeligheden gebruikt, geen exacte reproductie van de NHI-kalibratie. Gewashoogte40cm en lineair afnemende worteldichtheid zijn expliciete scenarioaannamen. Worteldiepten35/50cm komen overeen met twee historische lokale nat-heidebeschrijvingen, maar zijn geen huidige metingen.

Voor Ksat wordt de Staringreeks2018 gebruikt: Heinen, Bakker en Wösten2020, WENR2978, tabel3, B01:31.23cm/d, O01:22.32cm/d. Dit zijn gefitte klassewaarden, geen gemeten Ksat van de lokale oerbank. Bron:
https://nhi.nu/documents/74/waterretentie_en_doorlatendheidskarakteristieken_-wageningen_university_and_re_CCC9SDU.pdf

## Fysieke invoer en uitvoeringskeuze

Historisch profiel2, Wilgenduinen, uit de lokale studie1981. Zeven beschreven horizonten van0 tot106cm. De kolom eindigt bij106cm; de onderliggende laag met uitsluitend gravimetrische retentie wordt niet aangevuld. De twee verschillende A1-monsters blijven twee varianten. Alpha,n,theta_r,theta_s komen uit de eerder vastgelegde lokale retentiefits. Ksat krijgt bovengenoemde externe prior; Mualemlambda0.5 is een aanname. De weerstand van de verkitte horizont is daarmee niet lokaal gekwalificeerd. Bulk density1500 is ongebruikte metadata bij uitgeschakelde warmte/zuurstof/solute, geen overgenomen lokale meting.

De16 combinaties zijn twee A1-varianten, twee worteldiepten, twee interceptiecapaciteiten en twee onderranden: nulflux en vrije drainage. Geen irrigatie of drainage, geen lokale peilvoorschrijving, uniforme initiële h=-75cm. Zuurstofstress uit, in overeenstemming met de NHI-instelling met p1/p2=99m; de fysiologische geschiktheid voor actuele natte heide is nog open.

De oorspronkelijke24.120 uurlijkse ERA5-records worden hergebruikt. Neerslag en straling waren eerder correct naar intervalstart verschoven; temperatuur, dauwpunt en wind zijn instantane waarden op die tijd, gedurende het uur constant verondersteld. StralingMJ/m2/uur wordt kJ/m2/uur. Dampdruk volgt uit dauwpunt volgens dezelfde Murray-constanten als de native PM-route. Wind wordt op10m ingevoerd, temperatuur/vocht op2m. LONG_TZ=0 voor UTC. Geen nieuwe forcingdownload.

SWETR0, SWDIVIDE1, SWMETDETAIL1, NMETDETAIL24 en RutterSWINTER3. Bij deze native detailroute moet SWRAIN0 worden gebruikt: de neerslag blijft werkelijk uurlijks, gelezen uit de gedetailleerde meteorologie. De eerdere SWRAIN3-proef is terecht door de oorspronkelijke invoercontrole afgewezen en als negatieve evidence bewaard. Er is geen modelcontrole verwijderd.

De eenvoudige gewasmodule gebruikt jaarlijkse statische cycli. LAI wordt met een vastgelegde maximale benaderingsfout0.05m2/m2 in de native tabelcapaciteit vertaald. Dit is een invoerbenadering, geen versoepeld numeriek criterium. Wortels groeien niet opnieuw; RDI=RDC. De native jaarovergang reset wel de canopyberging. De capaciteitverliezen komen volgens de oorspronkelijke code in EIC terecht. EIC is daarom geen zuivere verdampingsmeting. De waterbalans omvat bodem, plas én canopy; jaarlijkse grensdagen worden afzonderlijk bewaard.

De eerste complete1005-daagse native proef heeft werkelijk code100 en de succesmarker opgeleverd, met circa2.25s wandtijd en maximale dagbalansafwijking5.09e-6cm. De eerste massavalidator miste een native uitvoerconventie: inactieve fluxen ontbreken als CSV-kolom. Dat is hersteld met expliciete controles dat RUNON/drainage uitstaan en BOT uitsluitend bij nulflux mag ontbreken. Geen onbekende actieve flux wordt als nul ingevuld.

Uitvoeringsselectie: nieuw onderzoeksdriver en andere fysieke invoer, ongewijzigde native executable SHA256 `2e46b6c9cc53e548c401670bd3e0e8df7799e8f95dfed4c77b7454edcf79bc07`. Eén gerichte native proef, gevolgd door de16 relevante scenario's en een hervattingscontrole. Verwachte native duur circa40s op basis van de werkelijk gemeten eerste proef. Geen solverherkwalificatie, SWAP5-testmatrix of Actions geselecteerd.

## Satelliet-LAI

Planetary Computer STAC, collectie `modis-15A2H-061`, gecombineerd productMCD15A2H v6.1. Alle109 beschikbare composieten zijn opgehaald, voor elk drie banden: LAI, FparLai_QC en FparExtra_QC. De oorspronkelijke rasterwaarden zijn voor een regionale uitsnede bewaard, samen met bronhashes, native rastergeometrie, tijdsintervallen en de koppeling aan alle1024 celcentra. Dit zijn nominale500m satellietpixels op een ander raster; het is geen oppervlaktegemiddelde van de SWAP-cel en geen geïsoleerde heidefractie.

De initiële band-voor-band tokenaanvragen veroorzaakten HTTP429. De client gebruikt nu het officiële gedeelde containertoken en respecteert Retry-After. De complete heruitvoering heeft109 van109 objecten verzameld, nul fouten. Het eerste negatieve resultaat blijft herkenbaar bewaard.

Van111616 cel/composietcombinaties hebben94721 een numerieke LAI,67963 gebruiken het hoofdalgoritme en26740 voldoen aan de extra strenge selectie. De kwaliteitsbits volgen tabellen3-5 uit:
https://lpdaac.usgs.gov/documents/926/MOD15_User_Guide_V61.pdf

Voor de twee droge heidekandidaten zijn31 en30 strenge waarnemingen beschikbaar. Voor beide natte kandidaten slechts één. Bovendien ontbreekt in de catalogus een groot deel van de zomer/herfst2025. Er is niet geïnterpoleerd of met een andere sensor/productversie aangevuld. Deze gegevens worden niet automatisch als volledig gewasverloop ingevoerd.

## Maaiveld en status

De alternatieve officiële dienst https://geo.api.vlaanderen.be/dhmv/wcs biedt wel de oorspronkelijke1m-DTM-metadata, maar ook de concrete GetCoverage-aanvraag is met HTTP403 afgewezen. Er is nog geen terreinraster ontvangen. De eerdere INSPIRE-route en deze nieuwe route blijven beide aantoonbaar, zonder fictieve hoogteafleiding.

Volgende actie: voltooi en controleer de16 native scenario's, bewaar de volledige waterbalansen en bronpostimages, en beoordeel daarna de ruimtelijke overdracht en de nog onvoldoende onderbouwde oerbank- en vegetatie-eigenschappen. Deze bestanden kwalificeren geen actuele heidecel en geen canonical-code.
