# Natte weerberekening: codereparatie

Status: voorgestelde productiecode, begrensd lokaal getest; niet canoniek toegelaten.
Baseline: `95a3bd5721a4dfb4c0c38823c475ff55b95bee57`.

De oorspronkelijke viermaal natte berekening stopt bij verzadiging. De reparatie
koppelt de werkelijke regen en potentiële verdamping aan de dynamische
oppervlakterand, zodat oppervlakteberging en runoff tijdens elke proefstap
worden opgelost. De Mualem-doorlatendheid wordt continu tot verzadiging behandeld;
opslagverschillen vlak bij nul worden zonder aftrekverlies berekend. Newton
gebruikt bijpassende interne en randafgeleiden. De tijdcontrole vergelijkt een
hele met twee halve stappen en beoordeelt rond verzadiging ook wateropslag en
waterverplaatsing. Alleen geaccepteerde fluxen worden gepubliceerd.

De numerieke coördinatentransformatie uit een tussenversie is verwijderd: zij
liet kleine contractproeven slagen maar blokkeerde de volledige natte run. De
oplosser werkt in drukhoogte. Een moeilijke vaste stap mag om verkleining vragen;
dat is geen toestemming om een niet-geconvergeerde toestand te accepteren.

## Volledige proef

97 dagen, vier cellen over 30 cm, illustratief gewas, echte dagelijkse
Andelst-weersgegevens met viermaal regen: totaal 908 mm. Dit is geen
veldkalibratie. Elke dag bevat 64 externe intervallen.

| Tolerantie | Voltooide dagen | CPU-tijd s | Runoff mm | Verschil runoff t.o.v. 1e-4 mm |
| --- | ---: | ---: | ---: | ---: |
| 1e-4 | 97 | 26.56 | 34.59370 | 0 |
| 1e-3 | 97 | 11.84 | 34.57424 | -0.01946 |
| 1e-2 | 97 | 10.83 | 34.57557 | -0.01813 |
| 1e-1 | 97 | 9.53 | 34.57761 | -0.01609 |
| 1 | 97 | 8.73 | 34.56788 | -0.02582 |

De grootste onafhankelijk gereconstrueerde dagelijkse waterbalansafwijking is
kleiner dan 2.8e-12 mm. De harde interne transactiegrens blijft 1e-14 cm.
Bij 1e-3 verschilt de totale onderafvoer 0.00969 mm van de eindige 1e-4-proef.
Die vergelijking geeft discretisatiespreiding; 1e-4 is geen exacte waarheid.
De tijden zijn eenmalige CPU-metingen met gelijktijdige kwalificatietaken, geen
herhaalde of overdraagbare snelheidsclaim. Voor deze run levert verdere
verruiming vanaf 1e-3 relatief weinig extra rekentijdwinst.

O0 met runtimecontroles en O2 geven bij 1e-3 bytegelijke fysieke stdout.
Sluiten en reconstrueren na de natte dag 35 geeft dezelfde volledige uitvoer.
Een geforceerde afwijzing na één private stap behoudt alle 21 gecontroleerde
toestandsbits, gewasrevisie en ontbrekende geaccepteerde oppervlaktefluxen.
De bestaande solvercontracten worden tegen de onveranderde baseline vergeleken;
de oorspronkelijke weerprofielen, constitutieve en randafgeleiden hebben aparte
productieproeven. Het machineleesbare bewijs registreert de feitelijke uitkomst.

De 1e-6-proef is na 180 seconden wandtijd afgebroken met 32 volledige dagen
en krijgt geen PASS. Ook mislukte tussenversies blijven bewaard. De reparatie
is begrensd tot de beschreven weer/Reference/default-MvG/free-bottom-compositie.
Brede FCI en bestaande bevroren toelatingsbewijzen zijn niet als geslaagd
aangemerkt voor deze gewijzigde bronbestanden.
