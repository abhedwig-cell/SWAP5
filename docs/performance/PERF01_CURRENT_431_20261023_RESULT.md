# Huidige SWAP5-rekenkern tegenover oorspronkelijke SWAP4.3.1

23 oktober2026. Afgerond begrensd vergelijkingsonderzoek. Baseline
`76d2ab9db8c20e976a25bb4c7414f176dd02c5cb`, productiebronboom
`ef90d0d745d85ba4090d22f238ee67dd8606e535`. Geen productiecode, default of
wetenschappelijke acceptatievoorwaarde gewijzigd.

## Uitkomst

Bij gelijk voorgeschreven hydraulisch werk is de huidige SWAP5-kern doorgaans
iets trager dan de oorspronkelijke4.3.1-kern. In de korte O2-proeven ligt de
mediane solver-CPU6–30% hoger. In de gebalanceerde jaarproef ligt de mediaan
ongeveer4% lager. Dit bevestigt globaal
de eerdere kernelvergelijking; er volgt geen algemene claim dat SWAP5 sneller is.

De grote eerder aangetoonde verbeteringen zitten in het verwijderen van
kwadratisch tracekopiëren, goedkoper afbreken van vergeefse Newtonfasen en een
bruikbare gekozen tijdnauwkeurigheid. Die gelden voor andere uitvoeringslussen.
Hun percentages worden niet met deze kernelverhoudingen vermenigvuldigd.

## Werkelijk gelijke proef

De oorspronkelijke B1.11/SWAP4.3.1- en TTUTIL-bronnen zijn vers gecompileerd;
216 originele bronleden zijn aan de vaste bronmanifesten gecontroleerd. Geen
oorspronkelijke fysische procedure is vervangen door een stub. Voor SWAP5 is
de huidige minimale Full Richards-closure gebouwd met het bestaande50-cellen-
diagnostische rooster:22 compilatie-eenheden plus koppeling per optimalisatie.

Tijdens dit onderzoek veranderden de huidige contract-, bindings- en HeadCalc-
bronnen door de afzonderlijke Picard-integratie. Daarom zijn beide huidige
optimalisaties opnieuw gebouwd en alle96 processen opnieuw uitgevoerd op de
bovenstaande baseline. De Picard-optie blijft hier uit. De oorspronkelijke
executables zijn uitsluitend hergebruikt na exacte controle van alle216
bronleden, driver, compiler en executablehash. De eerdere96 processen blijven
apart bewaard bij baseline `02d1e527f4a3cc0a64ae9a600c134c10a14afc7d`.
Hun volledige fysieke/werktellertraces zijn bytegelijk aan de nieuwe meting;
de CPU-samples uit beide meetrondes worden niet gemengd.

Beide bestaande drivers gebruiken50 cellen van2cm, dezelfde expliciete bodem-
en bronparameters, forcing, vaste0.005-dagstappen en overeenkomstige fysieke
tracevelden. De bestaande afzonderlijke harde massabalansassertie van1e-12cm
blijft actief. De gevraagde wortelopname en drainage zijn voorgeschreven; dit
is geen levende gewas- of HRU-simulatie. De SWAP5-kern wordt via haar typed
Reference-interface aangeroepen, inclusief de daarbij horende validatie,
toestandsbinding en kandidaatopbouw. De oorspronkelijke driver roept HeadCalc
met zijn globale toestand aan. Die architectuurkosten tellen dus mee.

De verzadigingsreparatie is aanwezig in de huidige bron. Deze proef selecteert
de bestaande conservatieve expliciete-fluxroute, zonder de optionele weather-
retry of een model-certificate-tolerantie. Zij meet niet opnieuw de97-daagse
4x-weer/gewasproef met dynamisch maaiveld.

## Actuele O2-metingen

Vijf seriële afwisselende paren per geval, vastgezet op dezelfde beschikbare
CPU. Geen eigen compilatie tijdens timing. De gemeten solver-CPU omvat de
rekenaanroep; validatie achteraf, trajectuitvoer, Pythonvoorbereiding en
compilatie zijn uitgesloten. GNU13.3 is daadwerkelijk gebruikt; exacte
oorspronkelijke compatibiliteitsflags en huidige flags staan in de bouwmetadata.

| Geval | Dagen | 4.3.1 mediaan s | SWAP5 mediaan s | SWAP5/4.3.1 |
| --- | ---: | ---: | ---: | ---: |
| Kale bodem | 30 | 0.161662 | 0.209691 | 1.297 |
| Voorgeschreven wortels | 30 | 0.158843 | 0.194894 | 1.227 |
| Droog | 1 | 0.005309 | 0.005943 | 1.119 |
| Ondiepe drukhoogte | 1 | 0.006810 | 0.007186 | 1.055 |
| Neerslagpuls | 3 | 0.016426 | 0.021036 | 1.281 |
| Voorgeschreven drainage | 30 | 0.157949 | 0.187780 | 1.189 |
| Gebalanceerde jaarproef | 365 | 1.289766 | 1.240229 | 0.962 |
| Gelaagde bodem | 30 | 0.160998 | 0.195563 | 1.215 |

Alle ruwe samples en bereiken blijven bewaard. Vooral de millisecondenproeven
hebben merkbare relatieve host-/meetvariatie. De jaarproef varieert bij4.3.1
van1.2525 tot1.3092s en bijSWAP5 van1.2004 tot1.2505s. Een gunstige mediaan
is geen garantie op4% winst in algemene toepassingen. De eerdere meetronde
gaf8% lagere jaarmediaan met overlappende bereiken; dat verschil tussen
meetrondes wordt niet aan een codewijziging toegeschreven.

Alle acht gevallen zijn ook met checked O0 eenmaal per kern uitgevoerd.
O0 dient als wetenschappelijke/diagnostische controle; de runtimechecking en
historische GNU-initialisatie-eisen maken die cijfers geen productiebenchmark.
In totaal zijn96 echte native processen uitgevoerd:80 O2 en16 O0.

## Fysieke overeenstemming en bewijs

Alle processen voltooien. Herhalingen per kern/optimalisatie geven exact dezelfde
volledige fysieke/werktellertrace. Aantallen stappen, stapgroottes en opgelegde
wortel-/drainagebedragen komen tussen beide kernen exact overeen. De grootste
historische drukhoogteafwijking is5.81e-12cm; theta6.78e-15; onderrandflux
6.37e-12cm/dag. De grootste onafhankelijke per-stapmassasluitfout is4.27e-14cm.
Geen fysische of bronassertie is versoepeld. De begrensde vergelijkingspoort
is een controle op afrondingsverschillen, geen nieuwe tijdnauwkeurigheidsrun.

Het archief bewaart392,000 volledige fysieke/werktellerrecords uit de eerste
herhaling van alle32 kern/optimalisatie/gevalcombinaties. Latere herhalingen
behouden hun exacte native tracehash plus stdout, stderr en klokmetingen.
De complete trajecten worden verliesloos opgeslagen met bytevlakken en XOR
tegen het vorige record of de overeenkomstige oorspronkelijke O2-trace.
Na reconstructie moet iedere volledige oorspronkelijke native SHA256 exact
overeenkomen. Geen toestand, tijdstip of fysieke waarde is afgerond/weggelaten.
De eerdere meetronde bewaart eveneens alle ruwe native resultaten en bronnen.
Alleen bytegelijke volledige trajecten delen verliesloos dezelfde opslag;
iedere historische trace behoudt haar eigen oorspronkelijke SHA256-controle.
Historische gecompileerde bronnen worden tegen hun eigen bevroren baseline
getoetst, de huidige bronnen tegen de huidige checkout. Een eerdere grotere
99.6MB-verpakking blijft als historische verpakkingsmetadata herkenbaar.

De verifier controleert tevens de daadwerkelijk gecompileerde oorspronkelijke
DEC-selecties tegen de vaste bronarchieven, TTUTIL, huidige productiebestanden,
gegenereerde grid/driver en alle ruwe klok-/resultaatbytes. Acht negatieve
controles verwerpen ontbrekende stdout, gewijzigde native klokuitvoer,
gewijzigde volledige trace, gewijzigde gecompileerde bron, ontbrekend proces
en een gewijzigde mediaan, plus gewijzigde historische gecompileerde bron en
ontbrekende historische native klokuitvoer. De oorspronkelijke meetronde kostte
43.50s compilatie/koppeling en35.27s native wandtijd. De actuele herbouw kostte
7.61s en de nieuwe96 processen33.20s; verpakkingskosten zijn afzonderlijk UNKNOWN.

Replay: `python -B benchmarks/performance/verify_perf01_current_431.py
benchmarks/performance/PERF01_CURRENT_431_20261023_EVIDENCE.tar.xz`.
Het ongewijzigde archief is voor overdracht verdeeld over vier `.part000`–
`.part003`-bestanden. De replay leest die automatisch, controleert elk deel en
vervolgens de oorspronkelijke volledige archiefhash. Het ingesloten recept
blijft het oorspronkelijke sealrecept; de huidige reader voegt alleen deze
verliesloze transportvorm toe.
Bronnen, kosten, ruwe gegevens, recepten en inventaris zijn versiegebonden in
`PERF01_CURRENT_431_20261023_STATUS.json` en het gelijknamige bewijs onder
`benchmarks/performance`.

## Betekenis voor de natte proef

De eerdere4x-reparatie en retry-optie zijn concreet bruikbaar binnen hun
toegelaten weather-route. Onderzoek met1e-2cm geeft daar bij beide onderzochte
wortelprofielen veel minder werk en kleine water-/gewasverschillen. Voor een
zuivere volledige vergelijking met SWAP4.3.1 ontbreekt nog dezelfde complete
weer/gewasuitvoering aan beide kanten. De huidige rekenkernvergelijking vult
dat ontbrekende toepassingsbewijs niet in. De algemene maaiveldherformulering
en een universele standaardtolerantie blijven aparte besluiten.
