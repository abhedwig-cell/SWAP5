# FACTOR60 — niet-lokale afgeleide domein3-uitfactor

Status: afgebakend en met echte provider getoetst op oorspronkelijke D2-iteraties53 (W-tak) en54 (volumetak), kolommen50/51/52, O0/O2. Geen Jacobiaan geïmplementeerd; geen volledige analytische112-kolommenkwalificatie of convergentieclaim.

## Grootheden en scope

Per actuele proef zijn W de vaste geaccepteerde domeinvoorraad [cm], I de inkomende hoeveelheid gedurende de vaste dt [cm], V het actuele volume onder GWL [cm], L=min(V,W) en O de som van ALLE potentiële uitgaande hoeveelheden [cm]. Binnen de geselecteerde context is I uitsluitend positieve boveninstroom, constant bij headperturbaties. FrIn1, geen topinstroomexces, f strikt tussen0 en1, excess/dt>1e-7 en O>excess. De hieronder gegeven formule geldt uitsluitend in die actieve ongewijzigde begrenzingstak.

`f=(W+I-L)/O`

Voor elke kolom j bij vaste W/I/dt:

`df/dh_j = -(dL/dh_j + f*dO/dh_j)/O`.

De positieve I mag NIET door0 worden vervangen. Op de voorraadstak V>W is L=W en dL0; f=I/O en df=-f*dO/O. Deze afgeleide is dus doorgaans NIET nul. Op de volumetak V<W is dL=dV; de GWL-bijdrage moet mee. Voor variabele instroom is de algemene formule (dI-dL-f*dO)/O; dit ruimere domein is niet door deze D3-toets gekwalificeerd en mag niet stilzwijgend op domein2 worden toegepast.

## GWL- en geometrieketen

De echte GWL ligt in cel50 met H50<0<H51. In de geselecteerde ondersteuning:

`G=z51 + H51*(z50-z51)/(H51-H50)`

`G_50=(z50-z51)*H51/(H51-H50)^2`

`G_51=-(z50-z51)*H50/(H51-H50)^2`; overige directe G-kolommen0.

VOLUNDR integreert de werkelijke compartimentvolumes met een gedeeltelijke bovenste cel. Zolang ondersteuning, bodem en totale-volumeclip niet wisselen:

`dV = rho50*dG + sum_i(a_i*dVol3_i)`, rho50=Vol3_50/dz50.

De a_i zijn de exacte VOLUNDR-overlapgewichten. Alleen rho*dG gebruiken is pas geldig als de geometriebijdrage aantoonbaar nul is of afzonderlijk wordt meegenomen. In alle geselecteerde perturbaties van50/51/52 is de volledige112-componenten Vol3-profielverandering exact0. De analytische GWL-keten en de VOLUNDR-gewichten sluiten op de echte provider. Dit bewijst geen universeel bevroren-geometriecontract voor andere toestanden/kolommen. V ligt hier onder de totale-volumeclip.

## Totale uitpotentie, inclusief contact

O=sum_i(S_i+U_i), met S/U de potentiële verzadigde/onverzadigde hoeveelheden. Domein3 heeft hier geen snelle drainage. dO bevat dus ook sum(dU_i). Kleine U-waarde is geen rechtvaardiging voor dU0.

In de W-context is het onverzadigde contact in cel50 gesloten en blijft dat in alle geselecteerde perturbaties zo. In de V-context is G net onder de vaste macro-waterhoogte en is het contact open. Daar geeft de originele contactweging U50=B(H,theta,...)*overlap, overlap=Zmacro-G in deze ondersteuning. Derhalve

`dU50 = overlap*dB + B*(dZmacro-dG)`.

Zmacro is in deze toetsen onveranderd. Op head51 is dB0 en kan de contact-GWL-term rechtstreeks worden onderscheiden; op head50 moet tevens de bestaande constitutieve/vocht-/event-/capafhankelijkheid van B worden meegenomen. Deze unit meet de volledige dO via echte centrale providerperturbaties en toetst de keten naar df. Er wordt geen complete analytische constitutieve dB-implementatie geleverd.

Voor vaste ondersteuning en materiaalcoëfficiënten is de verzadigde potentiegradiënt op een actieve uitcel de bestaande Darcy-gradiënt; bij verschuivende macrohoogte, geometrie of contact moet die keten worden aangevuld. Support-/richtingsdrempels blijven originele fysica. Geen afgeleide van een bedrag als rate gebruiken: P_i=(S_i+U_i)/dt [cm/dag], O blijft bedrag [cm].

## Factorcorrectie als rang-één-term en grens daarvan

Voor de uitfactorbijdrage aan de matrixresiduoperator F_i bevat de ontbrekende term

`DeltaJ_factor(i,j) = -P_i * df/dh_j`.

Dit is het buitenproduct u_i=-P_i en v_j=df/dh_j. Het teken volgt uit F_i met -q_i. Een volledige uitfluxafgeleide is echter

`dq_i/dh_j = f*dP_i/dh_j + P_i*df/dh_j`.

De bestaande lokale Jacobiaan bevat slechts zijn toegelaten lokale potentietermen. Voor een volledige operatorcorrectie moet ook -f*(dP_i-dP_i_local) worden bepaald, zonder dubbeltelling. Juist in cel50 is de contact-GWL-afgeleide van de onverzadigde potentie niet nul. De oorspronkelijke ABSORPTION-derivativetak heeft bovendien een eigen QOut>1e-7-grens; de kleine actuele cel50-flux ligt daaronder. Daarom mag niet worden aangenomen dat de hele potentiegradiënt al lokaal aanwezig is. Een toekomstige factor-rang-één-term is niet automatisch een volledige domein3-Jacobiaan.

## Guards en grensgevallen

Toekomstige toelating vereist het actuele providerstempel (heads, t, dt, poging, iteratie, taak/sequence), vaste W/I en geen ingangsbegrenzing; echte cel50/ondersteuning; geldige geometrie- en potentiegradiënten; O>0, strikt0<f<1 en dezelfde actieve excessdrempels. Geen bestaande JAC24/37-guard versoepelen: hun nulinstroom/vaste51-voorwaarden dekken dit geval niet. De correctie moet op basis van de huidige provider worden opgebouwd en elke echte lijnproef moet de oorspronkelijke minimum-/contacttak opnieuw evalueren. Een Newtontak over een hele zoeklus bevriezen is geen onderdeel van dit contract.

Bij V=W is de klassieke afgeleide niet uniek: voor vaste W is de richtingsafgeleide dL=min(dV,0). Dit vraagt een expliciet eenzijdig/semismooth contract of uitsluiting van ties; deze unit heeft geen tie geforceerd en kiest geen nieuwe numerieke tie-tolerantie. Ook f0/f1, O0, excessdrempel, contact0/volledig-contact, celgrens, veranderende flow-support, geactiveerde geometrieclip of gewijzigde instroom vallen buiten de geselecteerde kwalificatie en vereisen een eigen geldige tak. Geen tolerantieversoepeling of fysicawijziging.

## Kwalificatiegrens

Twee actuele providerpunten; per punt drie heads, centrale stap1e-7 en5e-8 cm, beide tekens. In totaal24 echte providerperturbaties per modelroute. De volledige fysieke toestand en providercache en IEEE-vlaggen zijn bij alle26 restores per route exact teruggezet. Alle perturbaties blijven op de bedoelde minimum-/contacttak en dezelfde gedeeltelijke factorondersteuning. O0/O2-uitvoer is exact.

De quotientketen sluit; directe verschillen van de oorspronkelijke f-berekening bevatten aantoonbare subtractieafronding. De wiskundig identieke, uitsluitend diagnostisch gebruikte volgorde ((W-L)+I)/O sluit op de keten tot7,83e-11 per cm head. De directe provider-FD wordt niet verworpen of vervangen, maar getoetst binnen het uit de werkelijke f-afrondingsafwijkingen gepropageerde interval. De echte fysische factorberekening blijft ongewijzigd. De GWL-/geometrieketen en productafgeleiden op nodes50 en52 zijn eveneens getoetst.

Niet gekwalificeerd: alle112 analytische potentiekolommen, volledige analytische dB, exacte ties, andere grenzen, een nieuw lineair-solve-updatepad, convergentie, accepted hostcommit of brede herstart.
