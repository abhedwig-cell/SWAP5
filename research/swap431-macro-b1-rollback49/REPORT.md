# ROLLBACK49 - echte afwijzing en directe retry, actieve witness nog open

De gerichte toets levert een gedeeltelijk resultaat. In oorspronkelijke context297 wijst FEEDBACK48 echt af en is de kleinere retry na rollback exact gelijk aan de directe kleinere poging. De nieuwe CONTACT47-increment is daar echter nul. In de enige aanvullende oorspronkelijke context36 is de increment positief, maar accepteert de kandidaat. Daarmee is een echte afwijzing met actieve CONTACT47-bijdrage niet aangetoond; deze kwalificatie blijft open.

## Context297: echte afwijzing, lege nieuwe cache

De oorspronkelijke PERIOD34-prefix is exact hersteld:296 pogingen/294commits, oorspronkelijke t35797.370782734390 en dt7.639717105455142e-5. Alleen op de geselecteerde poging en retries zijn apply37 en repair43 aangezet; er is geen eigen gerepareerde prefix ingevoegd. De FEEDBACK48-fysica/referentiecode is niet gewijzigd.

De poging faalt bij de oorspronkelijke MAXIT30-grens, zonder fluxreductie en zonder geforceerde fout. Maximaal residu0.0046788619160148676, som0.019239922355418975. Alle106 bestaande provideroproepen van die head hebben een leeg CONTACT47-masker en nul increment. Dit is dus een echte host-/solverafwijzing, maar geen actieve referentieafwijzing. Een reeds bestaande Jacobiaanactivering verandert die beperking niet.

MacroStateVar(2) maakt de nieuwe cache ongeldig; de getter registreert ready0/mask0/som0. Er is geen referentiecommit en de ledger verandert tot hostacceptatie niet. De fysieke kern/voorraden zijn hersteld. De oorspronkelijke onmiddellijke snapshot is niet integraal bytegelijk: inventarishelpers macro_exchange/macro_rapid/matrix_exchange/boundary_rates/sorptivity en het weigeringsflag verschillen; in nativecontext verschillen SorpDmCp en SubsidCp. Deze reeds bekende scratchverschillen worden niet als volledige native-restauratie gepresenteerd.

De oorspronkelijke TimeControl5 verkleint dt naar2.5465723684850474e-5. Deze retry accepteert in10iteraties met verse V1-controle, maxres1.1124484666780177e-10. DIRECT297 vertrekt uit dezelfde oorspronkelijke origin en past dezelfde verkleining direct toe. Solvertrace, alle10 retry-Jacobianen na pogingindexnormalisatie, geaccepteerde context, gecommitte toestand, ledgers en volledige step_budget zijn exact gelijk. Onafhankelijke inventarisfout -2.8174026832231483e-15cm, grens2.5465723684850477e-10cm; domeinen/ledgerincrementen sluiten aan.

## Context36: actieve referentie, geen afwijzing

Op basis van bestaande INITIAL30/REMAINING31-bewijzen is uitsluitend oorspronkelijke36 toegevoegd: t35797.070000000014,dt.002. De eerste35 pogingregels zijn exact de oorspronkelijke prefix; origin/inventaris/nativecontext/ledger zijn bytegelijk aan REMAINING31/TRIAL_G1. Het is geen nieuwe forcing of bevroren gevoeligheidspunt.

De kandidaat accepteert in2iteraties. Alle6 bestaande provideroproepen hebben een positief CONTACT47-masker en increment; de definitieve increment7.406704930487748e-9 wordt eenmaal gecommit in D3/node50. Referentie0.444 ->0.4440000074067049. De formule is onafhankelijk uit de actuele RATE-waarnemingen gereconstrueerd. Maxres1.556569080675585e-8, onafhankelijke inventarisfout1.5168144518185045e-11cm binnen2e-8cm. Geen rollback of DIRECT36 uitgevoerd, omdat deze kandidaat niet afwijst. De oorspronkelijke historische afwijzing van36 telt niet als een afwijzing van de nieuwe kandidaat.

## O0/O2, runtime en bronbinding

Zes modelroutes, allemaal normaal en ongecensureerd onder hard20s per route:

| Route | O0 (s) | O2 (s) |
|---|---:|---:|
| TRIAL297 |2.349334|1.856442|
| DIRECT297 |1.158899|0.961438|
| TRIAL36 |0.957321|0.759405|

O0/O2 geven identieke solveruitkomsten, fysieke toestanden, referentie/inventaris, commits, ledgers en budgetten. Een bestaande ongebruikte diagnostische factor in contact43_trace (nulgebaseerd veld14 SorpFac) verschilt in de6 rijen van TRIAL36: O0 geeft0, O2 een eindig subnormaal getal. In die rijen is rawDarcy exact0, sorptie gekozen en alle overige velden exact gelijk. Die lokale factor wordt niet toegewezen in de niet-Darcy-tak; de bron is onveranderd overgenomen uit FEEDBACK48. Er is daarom geen claim dat elk niet-timingdiagnoseveld bytegelijk is. Deze waarneming leidt niet tot een fysische reparatie binnen deze opdracht. IEEE-stderr-identiteit wordt evenmin geclaimd.

Broncheckpoint297:9b171a366. Bronnen, buildlogs en identiteiten van deze eerste variant staan in version297; executable is behouden als native297.exe. Checkpoint voor de enige extra contextguard36:a611d31eb. De laatste variant verandert uitsluitend de selectieguard/runner; actuele bronnen/buildlogs/identiteiten blijven naast de eerste variant bewaard. HARNESS_OBSERVATION.patch laat de volledige delta zien. De read-only providertrace/getter verandert geen RATE, referentie of afwijzingsbeslissing. Geen extra fysieke evaluatie of calibratie uitgevoerd; het oude calibration_base.bin is alleen door de hergebruikte runner gekopieerd, niet gebruikt als proefstaat.

## Begrenzing en vervolg

Klok, CONTACT47-formule, fysieke fluxwetten, tolerantie, MAXIT, dt-/reductie-/rollbackregels en budgetregels zijn behouden. Hard20, intern16 en bestaande caps blijven gelden; geen brede campagne. Selectie stopt na deze twee oorspronkelijke contexten, niet na een geclaimde actieve witness. Geen geforceerde afwijzing, geen extraDIRECT36, geen nieuwe herstart/volledige periode/BAL of canonieke toelating. B0/B1.12/canoniek/no-macrorelease onaangeraakt; B1 blijft B1_CANDIDATE_WITH_EXPLICIT_EXCLUSIONS.

De oorspronkelijke opdracht is dus niet volledig gekwalificeerd voor een positieve afgewezen referentie-increment. Een veilige volgende gerichte stap zou uitsluitend bestaande oorspronkelijke contextbewijzen selecteren waarin sorptie in de nieuw opgenomen main-GWL-cel positief is én een kandidaatweigering aannemelijk is. Dat is geen toestemming voor een brede zoektocht en wordt hier niet uitgevoerd. Reeds bewezen297-directvergelijking en actieve36-acceptatie hoeven daarvoor niet opnieuw te worden gedraaid.
