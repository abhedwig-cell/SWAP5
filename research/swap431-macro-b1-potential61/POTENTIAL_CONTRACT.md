# POTENTIAL61 — volledige domein3-potentiegradiënt binnen actuele ondersteuning

Status: analytisch afgebakend en met echte provider-FD getoetst op de oorspronkelijke D2-punten53/54, O0/O2. Volledige112x112 gradiënt binnen het hieronder expliciete vaste-coëfficiënten-/geometrie-/ondersteuningscontract. Alle acht actieve headkolommen zijn getoetst; geen112-onafhankelijke-kolommen- of algemene toestandskwalificatie. Geen solver-Jacobiaan geïnstalleerd.

## Ondersteuning en vaste gegevens

Neem de potentiële uitgaande hoeveelheden S_i (verzadigd) en U_i (onverzadigd) [cm per vaste tijdstap]. P_i=(S_i+U_i)/dt [cm/dag]. In deze context is de echte domain3-watercel50 en de bodemcel57; sat-uitondersteuning51..57, mogelijke unsat-ondersteuning uitsluitend50. Cel50 heeft H<0, cellen51..57 H>0 en strikt positieve macro-naar-matrix drukgradiënt. Alle overige potentiële uitrijen zijn0 binnen deze ondersteuning.

W, dt, forcings, domeinwaterhoogte Zmp, materiaal/CDarcy-profiel, Pp/DiPo/Awl/wetfractie, sorptieklok en beginhistorie blijven binnen de huidige proef vast. Het volledige112-componenten Vol3- en CDarcy-profiel en Zmp zijn in alle geselecteerde perturbaties exact gelijk; cel49 is expliciete buitenondersteuningscontrole. Dit is een lokaal conditioneel contract, geen algemene toestemming om veranderende geometrie of materiaalcoëfficiënten te bevriezen. Andere inputafhankelijkheden moeten werkelijk nul blijven of via een aanvullende keten worden meegenomen.

## Verzadigde potentie

Voor i=51..57 is de huidige Darcy-tak volledig actief en volledig nat:

`S_i = dt*FrReduQ*CDarcy(3,i)*(Zmp-z_i-H_i)`

`dS_i/dH_j = -dt*FrReduQ*CDarcy(3,i)*delta_ij`.

Geen GWL-contactterm in deze volledig verzadigde uitcellen. De gedeeltelijke watercel is50 en valt buiten deze actieve verzadigde ondersteuning. Alle dS buiten deze zeven diagonalen zijn0 binnen het afgebakende contract. Wijzigingen van Zmp/CDarcy/wetfractie/support vereisen aanvullende termen, geen stilzwijgende voortzetting van deze diagonaal.

## Cel50: contact en vocht

SwAbs1 en echte startklok T0 gelden hier. ThetaS-theta blijft strikt boven de oorspronkelijke sorptiedrempel1e-8; geen cap of Darcy/sorptiviteitstie. Omdat cel50 de hoogste watercel is, is de ondiepere Darcy-absorptietak niet actief; de echte provider kiest op het open contact sorptiviteit.

Definieer

`Sact = Smax*((ThetaS-theta50)/(ThetaS-ThetaR))^a`

`A = 4*Awl*Pp*dz/DiPo * wet_fraction`

`R = A*Sact*(sqrt(T+dt)-sqrt(T))`

`span = min(z50+dz50/2,Zmp)-(z50-dz50/2)`

`overlap = max(0,min(z50+dz50/2,Zmp)-max(z50-dz50/2,G))`.

De originele piekcap min(R,1000*dt*dz) is hier strikt inactief. De werkelijke hoeveelheid is `U50=FrReduQ*(R/span)*overlap`. Schrijf B=R/span. Vocht is geen constante: met de officiële moiscap C50=dtheta50/dH50 volgt

`R'_50 = -R*a*C50/(ThetaS-theta50)`

`B'_50=R'_50/span`, zolang span en alle hierboven genoemde factoren vast zijn.

Bij het gesloten contact (W-punt53) blijft overlap0 in de geselecteerde buurt: alle dU50=0. Bij het gedeeltelijk open contact (V-punt54) is overlap=Zmp-G en

`dU50/dH50 = FrReduQ*(overlap*B'_50-B*G_50)`

`dU50/dH51 = -FrReduQ*B*G_51`; overige kolommen0.

De GWL-afgeleiden zijn die van de echte50/51-interpolatie uit FACTOR60. De eerste term is de lokale vochtketen, de tweede het niet-lokale contact. De piekcap, voortgezet/afgebroken sorptie-event, SwAbs2, actieve Darcy-alternatief/max-tie, veranderende wet-/span-/materiaalgegevens vallen buiten deze getoetste tak en moeten afzonderlijk worden afgeleid. De klok wordt niet aangepast en de theoretische sorptiereferentie wordt niet opnieuw geïnterpreteerd.

## Volledige matrix en koppeling aan factor

Daarmee is de volledige potentiegradiënt in dit contract een matrix met zeven verzadigde diagonalen en, alleen bij gedeeltelijk contact, twee elementen in rij50/kolommen50 en51. Andere elementen zijn structureel0 binnen de vaste ondersteuning. Deel door dt voor de gradiënt van P_i. De som van alle bedragrijen geeft dO, inclusief de onverzadigde contact- én vochtterm.

Combineer dit met FACTOR60:

`df_j=-(dL_j+f*dO_j)/O`

`dq_i/dH_j = f*dP_i/dH_j + P_i*df_j`.

De bijdrage aan de matrixresiduoperator heeft het tegengestelde teken. Een toekomstige correctie moet aanwezige lokale termen aftrekken om dubbeltelling te voorkomen. De oorspronkelijke onverzadigde lokale derivativetak heeft een eigen QOut>1e-7-grens; cel50 ligt hier daaronder. De nieuw afgebakende contact-/vochttermen mogen dus niet als reeds aanwezig worden beschouwd. De factor-rang-één-term en de ontbrekende cel50-potentierij zijn afzonderlijke onderdelen. Dit is geen volledige afgeleidekwalificatie van domeinen1/2 of alle gekoppelde fysica.

## Toelatings- en transactieregels

Een latere implementatie vereist actuele gevalideerde providergegevens: heads, t/dt, poging/iteratie/sequence/taak, juiste ondersteuning, materiaal/geometrie, onbeperkte inkomende factor, constante positieve I3, strikte gedeeltelijke uitfactor, oorspronkelijke actieve excessdrempels en geldige minimumtak. Elke lijnproef moet de oorspronkelijke fysische contact-/minimumtak opnieuw kiezen; niet over een zoeklus bevriezen. Geen JAC24/37-guard versoepelen.

Exacte minimum-, contact-, cap-, flow-, cel- of eventties zijn niet klassiek differentieerbaar en zijn niet geforceerd/getoetst. Bij L=min(V,W) geldt op de tie de richtingsregel dL=min(dV,0), niet automatisch een universele Jacobiaanrij. Buiten het geldige contract moet een implementatie expliciet weigeren of een apart onderbouwde tak gebruiken. Geen nieuwe tolerantie om de guard passend te maken.

De sample46-getter is vandaag diagnostiek. Zijn niet-geserialiseerde macrosequence veranderde tijdens probes zonder fysisch effect. Een toekomstige correctie mag die diagnostiek NIET zonder nieuw actueel stempel-/restorecontract als numerieke providerpayload gebruiken. Gebruik een correct gevalideerde en transactioneel herstelde afgeleidepayload of reconstrueer uit actuele gevalideerde gegevens.

## Toetsing en grens

Twee oorspronkelijke actuele punten; head49..57 centrale epsilon1e-7 cm en voor50/51/52 ook5e-8.48 echte providerperturbaties per route, alle actieve kolommen50..57 en één buitencontrole. Alle112 potentierijen vergeleken met de analytische kolommen; maximaal1,022e-14 cm/cm head verschil (rate1,022e-9 per dag). Lokale dB/dtheta afzonderlijk uit de echte ongecontacteerde sorptiviteit getoetst, relatieve afwijking hoogstens1,79e-9. De officiële moiscap-keten is binnen expliciet gepropageerde afronding van theta-FD gecontroleerd.

Per route50 succesvolle byte-exacte fysieke-/cache-restores en IEEE-herstelcontroles. De oorspronkelijke solverroute blijft gelijk. Geen factor- of potentiegradiënt toegevoegd aan de lineaire solve; geen geaccepteerde vervolgstep of convergentieclaim. Geen algemene112-kolommen-FD, universele constitutieve gradiënt of herstartpromotie.
