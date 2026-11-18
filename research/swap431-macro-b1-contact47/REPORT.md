# CONTACT47 - dezelfde90, contactcontract gekwalificeerd

Voor de theoretische sorptiereferentie is bij deze90 events een consistente discrete contactweging afgebakend: neem de geometrische contactcoefficient van de geaccepteerde RATE en de oorspronkelijke sorptiviteit. Pas de waternatte-wandfactor en de aanvullende overlapfactor elk eenmaal toe. Gebruik dezelfde contactleeftijd en dt. De eindcontactfactor wordt geen retrospectieve vermenigvuldiger.

## Afgebakende keuze

C_RATE = Awl_RATE * Pp_RATE * (4 / DiPo_RATE) * wet_RATE * contact_RATE.

dRef = C_RATE * S_initial * (sqrt(tau + dt) - sqrt(tau)).

Dit behoudt het bestaande theoretische eigen-sorptiekarakter en de bestaande broncode-normalisatie van de referentie. De bestaande FrArMtrx-normalisatie hoort bij de werkelijke vochtbijdrage; deze opdracht voert geen algemene herbeoordeling van de historische referentienormalisatie uit. Klok, eventstart/einde en werkelijke fysieke fluxen blijven ongewijzigd. Het concrete contract en de eisen voor een eventuele toekomstige implementatie staan in CONTACT_CONTRACT.md.

Voorraadfactor FrOut hoort bij de werkelijke flux en wordt niet in de gekozen ideale referentieteller opgenomen. De oorspronkelijke sorptiviteit blijft onderscheiden van S_active. De handleiding ondersteunt de scheiding tussen theoretische eigen sorptie en werkelijk vocht (WER2780 p106 Eq6.54-6.56); de keuze voor RATE-geometrie bij dit nieuwe gedeeltelijke-contactregime is expliciet een discrete contractkeuze, geen unieke uitspraak van die handleiding. Het eindcontact opnieuw toepassen levert de reeds aangetoonde onjuiste nul. Nogmaals vermenigvuldigen met wet_RATE of contact_RATE telt dezelfde contactbeperking dubbel.

## Gerichte toets

Twee nieuwe, ongewijzigde modelreplays van dezelfde oorspronkelijke checkpoint, tot dezelfde vaste 360-step horizon. Alleen de bestaande selectie D3/node50/pogingen36..125 is gebruikt voor het contract. O0 1.7366752 s; O2 1.5114644 s. Beide normaal, ongecensureerd. Hard20 s per route, intern16 s en max512 commits behouden. Geen extra provider-evaluaties of aparte proefcontexten.

O0/O2 zijn exact gelijk buiten tijdmetingen, ook alle nieuwe afgeleide contactrecords. Alle Fortran-bronnen zijn bytegelijk aan REFERENCE46; de numerieke uitvoer, historie, inventaris en ledgers blijven exact gelijk aan die ouder. De referentie is in deze toets niet bijgewerkt. De broncheckpoint voor builds en runs is 49334bcb8.

Onafhankelijke reconstructie van overlap uit RATE-waterstand, GWL en celgrenzen geeft effectief contact 0.00258115379312 tot 0.00755057301412. Het verschil met wet_RATE * contact_RATE veroorzaakt hoogstens 9.04e-15 relatieve afwijking in dRef; dit is afronding van geometrische grootheden, zonder aanpassing van fysieke toleranties. De reconstructie van de actuele sorptiewet heeft maximaal 6.63e-16 relatieve afwijking. Na bestaande voorraad- en matrixnormalisatie sluit ook de werkelijke theta-bijdrage aan, maximaal 6.04e-16 relatief.

Voor elk van de90 geldt, binnen de uitsluitend analytische reconstructiegrens van de assessor:

- onbegrensde actuele sorptiehoeveelheid / dz = dRef * S_active / S_initial;
- werkelijke theta-bijdrage = voorgaande hoeveelheid * FrOut / FrArMtrx;
- piekcap niet actief, FrReduQ=1, sorptie gekozen;
- tau loopt door, ENDcontact=0 en geen werkelijk eventeinde in deze90.

De som van dRef is 1.7829320835654965e-8. Het voorraadgewogen alternatief is 9.400413081582368e-9 en heeft een andere referentiebetekenis. Dubbele wetting zou 3.571662129917554e-9 geven; dubbele contactweging 5.789925113212536e-10. Deze vergelijkingen zijn algebraische schaduwen op dezelfde geaccepteerde gegevens. Het zijn geen alternatieve modelruns of voorspellingen van een gecorrigeerde eindtoestand.

## Implementatiegrens

Het contract is nu algebraisch en geometrisch gekwalificeerd voor deze90. Er is nog geen teruggekoppelde reparatie, geen proefstaatherstel/rollbacktoets van een nieuw referentieveld en geen nieuwe herstartkwalificatie. Een implementatie moet de laatste actuele RATE-gegevens transactioneel gebruiken, scratch bij nieuwe rate vervangen en bij afwijzing ongeldig maken, en de increment precies eenmaal bij hostacceptatie toepassen. De bestaande echte droogreset blijft eigenaar van het eventeinde.

Geen toelating voor piekcap, FrReduQ<1, Darcy-keuze, nul werkelijke opname, perched situaties of andere overgangsregimes. Geen volledige-periode/BAL-kwalificatie of brede campagne. B1 blijft B1_CANDIDATE_WITH_EXPLICIT_EXCLUSIONS. B0/B1.12, canonieke SWAP5 en no-macrorelease zijn onaangeraakt. Veilige vervolgstap: minimale implementatie van dit afgebakende contract met eigen gerichte terugkoppelings- en transactietoetsen, uitsluitend binnen afzonderlijk geautoriseerde scope.

## Bewijs

Primaire bron: Kroes e.a., SWAP4 (2017), https://edepot.wur.nl/416321 , p106 Eq6.54-6.56. Lokaal reeds beoordeeld exemplaar SHA256 1cf1c350870fc7f7923dc17878fefa0dd2dc58b40fffb34b8d255d5a7fd2a82e; visuele bronpagina CONTRACT42 manual-108.png. Diagnose en waarnemingsschema uit REFERENCE46/CLOCK45 blijven onveranderd. RESULT.json, SAME90_CONTACT_AUDIT.csv en assess_contact47.py bevatten de herhaalbare read-only toets. EVIDENCE.json bindt het archief, broncheckpoint en alle geverifieerde bestanden.
