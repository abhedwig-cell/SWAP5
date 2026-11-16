# NEXT18: volgende BAL-periode met niet-nul canopybeginvoorraad

De gerichte kwalificatie is **onvolledig wegens de twintigsecondenlimiet**. De native overdracht en de echte periodereset zijn voor O0/O2 exact bevestigd. Een volledige BAL-periode met niet-nul beginvoorraad is niet gekwalificeerd: geen route bereikte de eindgrens. CANOPY17 blijft de laatst volledig gekwalificeerde periode; geen referentiepromotie.

## Afbakening

Baseline is CANOPY17 e4998f71b213bfc5c9e3e96fcc27397cc73702f4. De eerstvolgende gerichte periode is 3 januari 1998, t1900=35797 tot 35798. De oorspronkelijke jaarlijkse DATEFIX zou een veel langer traject vragen. Daarom selecteert uitsluitend de uitvoerplanning SWYRVAR=1 met OUTDAT 2 en 3 januari. Beide routes hebben dezelfde planning. TSTART, oorspronkelijke invoercontext en fysische instellingen blijven behouden; TEND is 3 januari.

Per optimalisatie zijn precies twee modelroutes uitgevoerd: ononderbroken vanaf het oorspronkelijke balansbegin op 1 januari, en een vers proces met het eigen native bestand op de volledig afgesloten grens van 2 januari. Iedere route gebruikt subprocess timeout=20 seconden. Geen aanvullende modelroutes, verruiming, brede campagne of vervolg tot een jaargrens. De gemeten procesafhandeling duurt 20,028–20,236 seconden inclusief afbreken; dit is geen verruimde rekentijdtoelating.

Alle BAL-, integral-, fysica- en native codecbronnen zijn bytegelijk aan CANOPY17. Alleen de onderzoeksdriver registreert de geselecteerde periode en laat het model langer doorlopen. De driver schrijft uitsluitend op de reeds gekwalificeerde eerste grens een V5-bestand met volledige historie; een tweede eigen eindbestand met latere historiemetadata wordt hier niet beproefd.

## Bevestigd resultaat

De oorspronkelijke eerste 1453 budgetregels zijn in beide optimalisaties exact gelijk aan CANOPY17. De voorraad op 35797 is eveneens gelijk. Het V5-bestand wordt in een vers proces gelezen: alle uitgebreide native contextvelden en 133 ledgerwaarden zijn exact gelijk aan de ononderbroken route. De volledige-historiemarkering blijft origin=35795, end=35797, complete=1.

Bij de echte reset voor 3 januari wordt SICINI **0,0025926018136122326 cm**, exact gelijk aan SICACT op de voorafgaande grens. De oude periode had SICINI=0. De nieuwe cumulatieve regen en canopyverdamping beginnen werkelijk bij nul. Context en ledger bij periodebegin zijn bytegelijk tussen continu en herstart en tussen O0/O2.

De oudere brede inventarisdump vóór head bevat zes verschillen tussen continu en native: macro_exchange, macro_rapid, matrix_exchange, matrix_vertical, boundary_rates en event. Deze dump bevat voorafgaande fluxen en eventwerkvelden die bij de volgende berekening opnieuw worden bepaald; hij wordt daarom niet als geheel bytegelijk gerapporteerd. De overgedragen native context, ledger en overige inventarisvelden zijn gelijk. Alle gemeenschappelijk vastgelegde geaccepteerde budgetstappen zijn vervolgens exact gelijk: 7577 voor O0 en 8202 voor O2 tussen continu en herstart. Over alle vier routes zijn de eerste **7577 stappen van 3 januari** bytegelijk, inclusief fluxfactor en de vijf domeinfluxen. Dit kwalificeert geen niet-opgeslagen tussentoestand of eindinventaris.

## Afgebroken routes en geldigheidsgrens

| Route | Volledige budgetregels | Laatste geregistreerde t1900 |
| --- | ---: | ---: |
| O0 continu, inclusief eerste periode | 9030 | 35797,67339122522 |
| O0 native herstart | 8159 | 35797,72468301477 |
| O2 continu, inclusief eerste periode | 9655 | 35797,730764133026 |
| O2 native herstart | 8636 | 35797,78453894471 |

Dit zijn de laatste volledige opgeslagen regels, geen gegarandeerde exacte toestand op het afbreekmoment. De budgetstream wordt iedere 128 stappen geflusht; een ongeschreven staart kan ontbreken. Verschillende aantallen bij dezelfde wandkloklimiet zijn geen numerieke afwijking.

In alle routes verschijnt de eerste geaccepteerde gereduceerde stap op 35797,071397877706. De minimale geregistreerde FrReduQ is 0,010000000000000002. De oorspronkelijke reductieregels zijn behouden; deze periode ondersteunt dus geen claim dat alle stappen zonder reductie slagen. Er is geen iteratieprofiel verzameld en geen oorzaak van de langere rekentijd bewezen.

Geen route heeft period_final of het afrondende outcome. De BAL/BLC/BMA/CSV-bestanden zijn bij gedwongen beëindiging nog nul bytes door uitvoerbuffering. Daaruit volgt geen fout in de BAL-correctie; evenmin levert dit een toets van de afgeronde tweede BAL-regels op. Eindvoorraad, onafhankelijke volledige periodebalans en correcte geprinte Initial/Final/Change met niet-nul SICINI blijven **NIET GEKWALIFICEERD**. Er worden geen ontbrekende gegevens uit een andere route aangevuld.

## Bewijs en herstel

assess_next18.py controleert uitsluitend bestaande resultaten en start geen model. RESULT.json onderscheidt de geslaagde overdracht/reset van de onvoltooide periode. De oorspronkelijke cases, native bestanden, gebufferde budgetregels, bronidentiteiten en buildresultaten zijn bewaard. NEXT18_EVIDENCE.zip bevat een geverifieerd manifest en de native bouwclosure. De oude CANOPY17-evidentie blijft de volledige periodeonderbouwing. Alleen een afzonderlijke concrete vervolgvraag kan extra diagnose selecteren; geen automatische campagne of budgetverruiming.
