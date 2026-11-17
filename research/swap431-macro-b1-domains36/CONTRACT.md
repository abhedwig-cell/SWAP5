# DOMAINS36 — afgebakend analytisch correctiecontract, nog niet geïmplementeerd

## Status en anker

Dit contract is afgeleid en getoetst op de vaste toestand van de eigen kandidaattraj­ectie: poging 293, iteratie 30, na de bestaande Jacobiaanopbouw en vóór TRIDAG. Basis INACTIVE35 `7bc419d2d27696e0125ee2767e3d45326dca3c82`. De geserialiseerde geselecteerde procestoestand is bytegelijk aan INACTIVE35. De echte provider, kandidaat, fluxformules, MAXIT, toleranties, dt, reductieregels en native formaten blijven ongewijzigd.

Gekwalificeerd: de analytische verklaring van vier gemeten headkolommen 50, 51, 52 en 57 voor alle 112 macroresidurijen, bij twee eps-waarden en O0/O2. Niet gekwalificeerd: een toegepaste solvercorrectie, alle 112 inputkolommen, overige fysieke takken, het oplossen van de volledige grote head, herstart of periodebalans.

## GWL- en zonedefinitie

Noem G de actuele matrix-GWL. De gemeten hoofdinterpolatie gebruikt j=50 en j+1=51:

    D = h51 - h50
    G = z51 + h51 / D * (z50 - z51)
    g50 = (z50 - z51) * h51 / D^2
    g51 = -(z50 - z51) * h50 / D^2
    gk = 0 buiten die twee kolommen

Het native compartiment dat de GWL bevat is s=51; dat is niet de linker interpolatienode. De huidige interne/perched zone heeft eveneens top en bodem 51 en dezelfde waterstand G. Deze velden zijn uit de bestaande SENSE23-snapshot gelezen en gecontroleerd tegen klok/dt/procesvolgnummer en beide optimalisaties. Zij mogen bij een latere implementatie niet uit historische bestandsnamen of vaste verwachte waarden worden aangenomen.

## Twee actieve minimumvoorraadbegrenzingen

Domeinen d=2 en d=3 hebben FrIn=1, alleen topinstroom en geen verzadigde matrix-/interne instroom, geen onverzadigde uitstroom en geen rapid drainage. Op de gemeten tak zijn beide minimumvoorraadbegrenzingen strikt gedeeltelijk actief:

    Ld = VonderGWL_d < Wd
    0 < fd = (Wd + Id - Ld) / Od < 1
    qi,d = fd * oi,d / dt

Id is voor de getoetste headvariaties constant. Topinstroom zonder afdekkende laag volgt in de bestaande bron rechtstreeks uit vaste actuele forcing, domeinoppervlak en dt; laterale instroom en topoverschot zijn hier nul. De actuele geometrie en forcing moeten bij elke provider/Jacobiaanevaluatie worden gebruikt, niet waarden uit dit rapport.

Voor de relevante verzadigde/GWL-kolommen blijft de volumetrische geometrie bij differentiatie gelijk. Met rhod = VlMpDmCp(d,s)/dz(s) geldt:

    dLd/dhk = rhod * gk
    ak,d = dOd/dhk = -ok,d / (max(0, Zwater_d - zk) - hk) als ok,d > 0
    ak,d = 0 anders
    vk,d = dfd/dhk = (-rhod*gk - fd*ak,d) / Od
    ui,d = -oi,d / dt

Omdat F de macro-uitwisseling aftrekt, is de ontbrekende voorraadbijdrage aan de residu-Jacobiaan:

    R = u2 v2^T + u3 v3^T

De bestaande lokale afgeleide bevat al de term met fd maal de lokale potentiaalafgeleide. Die mag niet opnieuw worden toegevoegd. De som over alle domeinen, inclusief de bestaande lokale termen, moet behouden blijven.

Dit zijn twee werkelijk onafhankelijke voorraadtermen op dit punt. Een 2×2-minor van R, rijen 52/57 en kolommen 50/57, is −1,514568503534415e-5; één rang-één-term is hier niet equivalent. De potentiaalvectoren hebben cosinus 0,592434550441705.

## Aanvulling binnen de bestaande tridiagonaal voor domein 1

Domein 1 heeft hier geen actieve in- of uitstroombegrenzing: FrIn=FrOut=1. Er is dus geen extra voorraadnormalisatie voor dit domein nodig. Wel hangt de inkomende SATFLOW-potentiaal in de gedeeltelijk verzadigde matrixcel s=51 af van de verzadigde celfractie:

    depth = G - (zs - dzs/2)
    sigma = depth / dzs

De provider bevat op die cel zowel verzadigde matrixinstroom qm als interne verzadigde instroom qint. In deze gemeten toestand delen ze dezelfde waterstand/interpolatie en is de macrodruk HMp1=0. De bestaande SATFLOW(4)-afgeleide neemt de lokale matrixinstroom mee, maar niet de lokale bijdrage van qint en niet de afgeleide van sigma.

Daarom zijn aanvullend nodig:

    cG = (qm + qint) / depth
    cint = qint / (hs - HMp1)
    B(s,j)   += cG * gj
    B(s,j+1) += cG * gj+1 + cint

Hier zijn s=j+1=51. B verandert dus alleen de reeds bestaande onderdiagonaal op rij 51 en de diagonaal op rij 51:

    B51,50 = +0,0037105477280693863
    B51,51 = +0,013166512395977319 + 0,027629440630022564
           = +0,04079595302599988

De tweede diagonale component is essentieel: zonder haar blijft op de vierkolomsschaduw een fout van ongeveer 0,02762944 over. Domeinen 4 en 5 hebben op dit punt onbegrensde onverzadigde uitstroom; zij worden behouden via de bestaande provider/lokale afgeleiden, niet verwijderd of als lege fysieke domeinen beschouwd. Hun respons in de vier getoetste kolommen is nul.

## Voorgestelde lineaire vorm

Het afgebakende ontwerp is:

    Jnieuw = (Jbestaand_tridiagonaal + B) + u2 v2^T + u3 v3^T

De huidige rang-één-correctie mag niet bovendien dezelfde domein-3-term toevoegen. Nieuwe en bestaande toepassingsguards moeten expliciet worden gescheiden; eerdere gekwalificeerde nulinstroomgevallen blijven behouden.

Een passende minimale uitvoeringsvorm gebruikt de bestaande TRIDAG voor de aangepaste tridiagonaal: eenmaal voor F en tweemaal voor de twee u-vectoren, daarna een 2×2-Woodbury-correctie. Dit vereist geen dichte 112×112-Jacobiaan, geen finite-difference-Jacobiaan in de solver en geen wijziging van fysische rates. Deze uitvoeringsvorm is hier alleen beschreven, niet geïmplementeerd of op singulariteit/lineaire-residukwaliteit getoetst.

De gegevens horen via een afgebakende alleen-lezen interface uit de actuele provider te komen. Diagnosebestanden en de in deze ronde gebruikte observatiecache zijn geen runtime-afhankelijkheid van een nieuwe solver. De actuele trial/Jacobiaanevaluatie en het verversen na rollback moeten herkenbaar zijn; geen stale cache of nieuwe persistente fysieke toestand invoeren.

## Guards, grenzen en eerstvolgende kwalificatie

Voor het puntgetoetste blok zijn onder meer nodig: dezelfde volumetak, vaste compartiment-/interpolatie-indexen, passende stroomrichtingen, FrIn=1, topoverschot=0, alleen constante topinstroom in domeinen 2/3, strikt actieve gedeeltelijke minimumgrenzen daar, en onbegrensde domein-1-instroom met de hier genoemde geometrie-/zonecondities. Gebruik de werkelijke actuele parameters en grenzen; hardcode geen gemeten numerieke coëfficiënten.

Buiten de gemeten strikte tak is aanvullend onderscheid nodig. Bij L=min(VonderGWL,W) is dL=rho*dG in de volumetak en dL=0 in de voorraadcap. Bij onbegrensde uitstroom is df=0. Exacte cap-/takovergangen zijn niet met deze achttien proeven gekwalificeerd. Een eenzijdige/generaliseerde afgeleide op een tie is een te toetsen numerieke keuze, geen reeds bewezen resultaat. De echte grote head doorloopt ook andere actieve sets; een puntgetoetste formule alleen bewijst nog geen headconvergentie.

Het profiel heeft dynamisch krimpbare bovenlagen. De vier gemeten kolommen liggen in het GWL-/verzadigde blok waar de gebruikte geometrie tijdens deze variaties gelijk blijft. Er is geen bewijs geleverd voor ontbrekende krimp-/oppervlaktekoppelingen door de overige, vooral bovenste heads. Dit ontwerp corrigeert het vastgestelde blok en claimt geen exacte globale 112×112-Jacobiaan.

De kleinste volgende uitvoering is een gerichte implementatie en proef op dezelfde grote poging 293 vanuit dezelfde kandidaataanloop, met O0/O2 en twintig seconden per route. Behoud verse V1, oorspronkelijke lokale/totale residucriteria, hostcommit en onafhankelijke voorraadcontrole; toets rollback/directe kleinere retry als de kandidaat werkelijk afwijst, zonder weigering af te dwingen. Behoud eerder gekwalificeerde toepassingsgevallen. Een periode- of herstartcampagne volgt hier niet automatisch uit.
