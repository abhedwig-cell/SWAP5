# CONTACT47 - afgebakend contract voor theoretische contactweging

Status: voorgesteld voor dezelfde90 D3/node50 events36..125; algebraisch te kwalificeren met O0/O2. Geen wijziging van de opgeslagen referentie of van het fysieke traject. Baseline REFERENCE46 a88e2eb9f21bfeb880c62402b048862e2bfd85bd. Originele checkpoint en observatiehorizon blijven behouden.

## Definitie

Gebruik de geometrie uit de laatste, actuele, geaccepteerde mean-rate-evaluatie vóór de native owner de eindvoorraad en geometrie bijwerkt. Definieer C_RATE = AwlCorFac_RATE * PpDmCp_RATE * (4 / DiPoCp_RATE) * wet_RATE * contact_RATE. wet_RATE is dezelfde reeds toegepaste waternatte-wandfactor als in ABSORPTION, eenmaal toegepast. In deze90 betreft dat FrMpWalWet van de deels natte cel. contact_RATE is de bestaande REPAIR43 overlapfactor, eveneens eenmaal toegepast. Het product wet_RATE * contact_RATE is het aandeel van de celwand dat tegelijk macro-waternat en in contact met onverzadigde matrix is.

De theoretische increment is dRef = C_RATE * S_initial * [sqrt(tau + dt) - sqrt(tau)]. S_initial is de ongewijzigde SorpDmCp van de contactevent; tau en dt zijn die uit dezelfde geaccepteerde rate. In de hypothetische referentiebijwerking zou dRef eenmaal aan de geaccepteerde referentie worden toegevoegd. Tau += dt en alle bestaande eventstart/eind-/droogresetregels blijven behouden. Geen trapezium- of eindcontactweging, geen nieuwe fysieke tijdintegrator en geen vervanging van tau door gewogen contacttijd.

## Theorie tegenover werkelijke flux

De primaire autoriteit is SWAP4 WER2780 (2017), p106, Eq6.54-6.56: theoretische vochttoename met oorspronkelijke sorptiviteit; afwijking van werkelijk vocht corrigeert actieve sorptiviteit. Daarom bevat de gekozen theoretische teller geen FrOut, FrReduQ, actuele SorpAct, FrArMtrx of daadwerkelijke flux. Dat zijn geen alternatieve definities van het geometrische contact. Actuele voorraadbegrenzing en piekfluxcap blijven volledig in de bestaande fysieke rate. In deze90 is de sorptiepiekcap niet actief en FrReduQ=1. Er is geen toelating voor andere regimes.

Het onderscheid kan onafhankelijk worden getoetst: de onbegrensde actuele sorptiehoeveelheid per dz moet gelijk zijn aan dRef * S_active / S_initial. De bestaande actuele theta-bijdrage is vervolgens FrOut / FrArMtrx maal die hoeveelheid. De theta-normalisatie bevat FrArMtrx; de opgeslagen theoretische referentie houdt haar bestaande broncode-normalisatie. Deze identiteit rechtvaardigt niet het toevoegen van FrArMtrx aan de referentie.

De keuze om aanbodbegrenzing buiten de ideale teller te houden is een expliciete discrete contractkeuze passend bij de theoretisch/werkelijk-scheiding, geen bewering dat de handleiding het nieuwe gedeeltelijke-contactregime uniek voorschrijft. Een FrOut-gewogen alternatief correspondeert met een andere theoretische referentie (begrensde eigen opname) en zou die betekenis wijzigen. Het wordt uitsluitend ter vergelijking berekend.

## Eindpunt en transacties

Nul ENDcontact mag een reeds geaccepteerde positieve tijdstapbijdrage niet achteraf wissen. Een echte eventeind-/droogreset mag de bestaande historie nog steeds wissen. Voor deze90 ontbreekt zo'n reset; eindwand blijft gedeeltelijk waternat. De eindgeometrie is wel relevant voor de volgende rate, niet als retrospectieve vermenigvuldiger van deze rate.

Een toekomstige implementatie moet uitsluitend actuele, laatste providergegevens gebruiken, gebonden aan domein/node, poging, iteratie, provider-generatie, tijd en dt. Geen herberekening uit ENDgeometry of verouderde proefstaat. Een eventuele tijdelijke referentie-increment is scratch: vervangen bij nieuwe rate, ongeldig bij afwijzing/rollback, pas eenmaal bij hostacceptatie toepassen. Na herstart eerst opnieuw een actuele rate opbouwen; geen nieuw native persistent veld nodig voor deze scratch. Deze levenscyclus is een implementatie-eis en wordt hier niet als rollback-/herstart-PASS geclaimd.

## Selectie en uitsluitingen

Twee onveranderde O0/O2-replays van dezelfde oorspronkelijke360-step context; hard20 seconden per route, intern16, max512 commits, vaste horizon. Alleen90 bestaande records beoordelen. Geen extra providers/probes/contexten, geen fysische/formulewijziging, geen brede campagne. Algebraische contacten positief; Sinitial/Sactive-reconstructie; RATE-eenmalige overlap; correcte afwijzing van END0 en dubbele wetting; O0/O2-identiteit; bron- en uitvoeridentiteit met REFERENCE46.

Geen implementatiekwalificatie van teruggekoppelde referentie, correctiegevoeligheid van later traject, afwijzing/rollback, piekcap, FrReduQ<1, Darcy-keuze, zeroactual, perched of andere nat/droogregimes. B1 blijft kandidaat met expliciete uitsluitingen; geen volledige periode/BAL/herstart/canonieke promotie.
