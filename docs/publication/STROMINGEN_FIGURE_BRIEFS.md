# Stromingen figure briefs

## Doel

Deze briefs vertalen het figurenplan naar vier concrete, publicatie-veilige overzichtsfiguren. Het zijn uitlegfiguren, geen Results-figuren. De uiteindelijke grafische vormgeving kan later worden uitgewerkt in de huisstijl van Stromingen.

## Figuur 1. Eén watersysteem, verschillende modeldomeinen

**Doel voor de lezer**

In één oogopslag laten zien waarom een gekoppeld instrumentarium nodig is: atmosfeer, vegetatie, onverzadigde zone, grondwater en oppervlaktewater vormen één hydrologisch systeem, maar worden met verschillende gespecialiseerde modelcomponenten beschreven.

**Beeldopbouw**

Een eenvoudige landschapsdoorsnede van links naar rechts, zonder realistische locatie of specifieke Nederlandse casus.

Boven:
- neerslag;
- potentiële/actuele verdamping;
- vegetatie.

Midden:
- bodemprofiel / onverzadigde zone;
- wortelzone;
- verticale waterbeweging.

Onder:
- grondwater;
- grondwaterstroming.

Aan de zijkant:
- sloot, beek of kanaal;
- oppervlaktewaternetwerk / waterverdeling.

Modelnamen klein en secundair:
- bij onverzadigde zone: SWAP / SWAP5;
- bij grondwater: MODFLOW 6;
- bij oppervlaktewater: Ribasim.

Pijlen alleen voor generieke fysieke uitwisseling:
- neerslag naar bodem;
- verdamping omhoog;
- uitwisseling onverzadigde zone en grondwater;
- uitwisseling grondwater en oppervlaktewater.

**Niet opnemen**

Geen q_bot, q_u, u, coupling window, response coefficient, numerieke solvernamen, N:1-relaties, foutmaten of tijdstapschema.

**Voorgestelde caption**

*Figuur 1. De hydrologische domeinen die in een gekoppeld instrumentarium samenkomen. SWAP/SWAP5 beschrijft de onverzadigde zone en vegetatiewaterhuishouding, MODFLOW 6 het grondwater en Ribasim het oppervlaktewatersysteem en de waterverdeling. De figuur is conceptueel; de feitelijke koppeling en ruimtelijke discretisatie verschillen per toepassing.*

## Figuur 2. Van zelfstandig modelprogramma naar modulair instrumentarium

**Doel voor de lezer**

Uitleggen wat er op hoofdlijnen verandert zonder de P1-architectuur of PUB-GC-koppelmethode te publiceren.

**Linkerhelft: historische uitvoeringsvorm**

Eén groot blok: SWAP.

Met drie eenvoudige elementen:
- invoer;
- modelberekening;
- uitvoer.

Pijl van invoer naar SWAP, pijl van SWAP naar uitvoer.

Label erboven: zelfstandige modeluitvoering.

**Rechterhelft: modulaire modelomgeving**

Drie gelijkwaardige hoofdblokken:
- SWAP5 / onverzadigde zone;
- MODFLOW 6 / grondwater;
- Ribasim / oppervlaktewater en waterverdeling.

Rond of onder de blokken alleen generieke voorzieningen:
- modelconfiguratie;
- gegevensbeheer;
- koppeling;
- versie/provenance.

Pijlen tussen componenten zijn tweezijdig en ongelabeld, of alleen gelabeld als hydrologische informatie.

Label erboven: gekoppelde modelcomponenten.

**Visuele boodschap**

Niet: SWAP5 is een totaal nieuw fysisch model.

Wel: dezelfde hydrologische modelbasis krijgt een andere rol en uitvoeringsomgeving.

**Niet opnemen**

Geen transaction lifecycle, state ownership, commit, rollback, retry, trial/accepted states, coupling iteration, API-methoden of interne moduleklassen.

**Voorgestelde caption**

*Figuur 2. Schematische verschuiving van een zelfstandige modeluitvoering naar een modulaire modelomgeving. De modernisering maakt de SWAP-modelbasis beter afzonderlijk aanstuurbaar en koppelbaar, zonder dat deze figuur een specifieke productiearchitectuur voorschrijft.*

## Figuur 3. Terminologie tijdens de overgang

**Doel voor de lezer**

Voorkomen dat MetaSWAP, MultiSWAP en SWAP5 in het artikel of bij de lezer op één hoop terechtkomen.

**Vorm**

Geen architectuurdiagram, maar een rustige contextkaart met drie kolommen.

Kolom 1: Bestaande / huidige praktijk
- SWAP;
- MetaSWAP;
- MODFLOW 6;
- iMOD / iMOD Coupler;
- Ribasim.

Kolom 2: Ontwikkeling
- SWAP5: modernisering van de SWAP-modelbasis;
- MultiSWAP: publiek door NHI gepositioneerd als opvolger van MetaSWAP.

Kolom 3: Toepassing
- regionale modellen;
- landelijke/NHI-achtige toepassingen;
- gekoppelde grondwater-, onverzadigde-zone- en oppervlaktewatersimulaties.

Gebruik gestippelde relaties in plaats van harde pijlen waar formele productrelaties nog niet definitief zijn.

Bij MultiSWAP kleine voetnoot: terminologie en formele inbedding controleren vlak voor publicatie.

**Belangrijk**

Deze figuur moet vlak voor indiening opnieuw worden gemaakt vanuit de dan actuele NHI-, Deltares- en WENR-communicatie.

**Niet opnemen**

Geen pijl SWAP5 = MultiSWAP.
Geen claim SWAP5 vervangt MetaSWAP.
Geen definitieve NHI-productarchitectuur zolang die niet formeel is vastgesteld.

**Voorgestelde caption**

*Figuur 3. Context van enkele modelnamen tijdens de huidige overgang. MetaSWAP blijft onderdeel van bestaande gekoppelde toepassingen, terwijl MultiSWAP publiek als opvolger wordt ontwikkeld. SWAP5 verwijst in dit artikel naar de modernisering van de SWAP-modelbasis. De precieze product- en projectinbedding moet bij publicatie worden afgestemd op de dan actuele programma-authority.*

## Figuur 4. Van code naar gekwalificeerde toepassing

**Doel voor de lezer**

Een kernboodschap uit het artikel visueel maken zonder P1- of TRACE-resultaten te publiceren: technische aanwezigheid is niet hetzelfde als gekwalificeerde toepassing.

**Vorm**

Een horizontale voortgangsbalk of vier naast elkaar staande vlakken:

1. Geïmplementeerd: functionaliteit bestaat technisch.
2. In kwalificatie: controles en referentiecases lopen.
3. Gekwalificeerd voor omschreven gebruik: evidence ondersteunt de betreffende toepassing.
4. Toegepast / beheerd: onderdeel van een concrete modelworkflow of instrumentariumtoepassing.

Onder de balk een tweede, apart vlak:
Onderzoek / toekomstige optie, met de expliciete boodschap dat onderzoek niet automatisch doorstroomt naar productie.

**Waarom deze volgorde**

De figuur laat het onderscheid tussen softwarevoortgang en toepassingsgereedheid zien, zonder te zeggen welke SWAP5-capabilities momenteel in welk vak staan.

Een aparte kleine tabel of callout naast de figuur kan vlak voor indiening worden gevuld met de actuele SWAP5-status. Die tabel hoort niet structureel in deze generieke figuur.

**Niet opnemen**

Geen aantallen tests, equivalence-percentages, foutklassen, pass/fail-resultaten, P1-evidence of TRACE-taxonomie.

**Voorgestelde caption**

*Figuur 4. In dit artikel wordt onderscheid gemaakt tussen technische implementatie, lopende kwalificatie en gekwalificeerd gebruik. Onderzoek en toekomstige opties vormen een aparte categorie. De actuele positie van afzonderlijke SWAP5-capabilities moet worden ontleend aan de geldende qualification baseline op het moment van publicatie.*

## Redactionele plaatsing

Aanbevolen volgorde in het artikel:

- Figuur 1 direct na de opening;
- Figuur 2 na de sectie over vijftig jaar SWAP en de veranderde modelomgeving;
- Figuur 3 in of direct na de passage over MODFLOW 6, Ribasim, MetaSWAP en MultiSWAP;
- Figuur 4 bij de sectie 'Implementeren is nog niet kwalificeren'.

Geen vijfde figuur toevoegen tenzij tijdens de redactie blijkt dat het schaalvraagstuk zonder illustratie onvoldoende begrijpelijk is. Een schaalfiguur heeft een groter risico om naar PUB-SG/SCALE door te schuiven en is daarom geen standaardonderdeel van deze versie.