# Maaiveld en rekentijd: vervolgonderzoek, 22 oktober 2026

Status: lokaal gemeten en gecontroleerd; canonical-integratie nog geblokkeerd.

De actuele integratietak `288ba1473c478b9a2a637f0b12d624fbcc63ca4a` is zonder
conflicten samengevoegd met de reparatie van PR #1361. Sinds de oorspronkelijke
reparatiebasis `95a3bd5` zijn op canonical geen `src`-bestanden gewijzigd.
De productiecode is in dit vervolgonderzoek niet aangepast. De tolerantie
10^-3 cm dient uitsluitend als vergelijkingspunt, niet als nieuw productiedefault.

## Wat de meting laat zien

De bestaande 97-daagse berekeningen met 227 en 908 mm neerslag zijn opnieuw
uitgevoerd met tellers in een gegenereerde, alleen voor onderzoek gekoppelde
HeadCalc. Alle dagelijkse fysieke waarden, solveraanroepen, geaccepteerde
stappen, temporele afwijzingen en gepubliceerde oppervlakte-/onderrandbedragen
zijn exact gelijk aan de oorspronkelijke berekeningen. Alleen de CPU-klokwaarden
zijn uitgesloten van die vergelijking.

| Werk over 97 dagen, tolerantie 10^-3 cm | 1× neerslag | 4× neerslag |
| --- | ---: | ---: |
| HeadCalc-aanroepen | 58.321 | 138.057 |
| Newton/Jacobiaanopbouwen | 185.167 | 673.078 |
| Backtrackingpogingen | 227.364 | 1.773.872 |
| Mislukte solveraanroepen | 423 | 12.371 |
| Aanroepen met interne wisseling flux/head | 0 | 450 |
| Geobserveerde interne flux/headwisselingen | 0 | 864 |
| Transactionele temporele afwijzingen | 8.048 | 22.752 |
| Geaccepteerde interne stappen | 11.202 | 18.135 |

In de uitgebreide 4×-trace gebruiken aanroepen met een interne flux/headwisseling
ongeveer 0,7% van de geobserveerde HeadCalc-CPU. Mislukte solveraanroepen gebruiken
ongeveer 62%. Van de mislukte aanroepen hebben 12.197 van 12.371 geen interne
flux/headwisseling, oftewel 98,6%. De specifieke begrensde corner-restart wordt
149 keer geprobeerd en gebruikt ongeveer 0,85% van de geobserveerde solvertijd.
Deze groepen overlappen en mogen niet bij elkaar worden opgeteld.

De instrumentatie omvat CPU-klokaanroepen en schrijven van tracegegevens.
Daarom zijn deze tijden een lokalisatie van werk, geen nieuwe snelheidsbenchmark
of voorspelling van besparing. De oorspronkelijke ongewijzigde CPU-metingen
blijven 1,653 en 5,460 seconden. Het verschil tussen een full/half-controle,
een afgewezen temporele stap en een mislukte Newton-aanroep blijft expliciet:
dit zijn verschillende tellers en geen optelbare aantallen tijdstappen.

Dag 84 is de zwaarste gemeten dag. De volledige verzameling kostbare dagen en
de begin-/einddrukhoogten van elke solverpoging blijven in de bewijsset staan.
Bij 6.491 mislukte aanroepen ligt de bovenste begindrukhoogte binnen 0,01 cm van
nul; bij 983 geldt dat voor de onderste begindrukhoogte. Nabijheid bij nul
bewijst niet dat dit de oorzaak is. Er is nog geen gecontroleerde verandering
van alleen de randvoorwaardewissel uitgevoerd.

## Aansluiting bij eerder TOP03-onderzoek

TOP03 is onderzoekswerk op branch
`work/sw-rib-top03-transactional-top-exchange`, pin
`f5063889e4a7ab1ad075509e1ce9f4c1955ee58d`, en PR #956 is nog draft en ongemerged.
Het is geen reeds toegelaten gezamenlijke maaiveldoplossing.

De exacte historische bronnen zijn:

- [Maaiveldbeoordeling van 2 oktober](https://github.com/abhedwig-cell/SWAP5/blob/f5063889e4a7ab1ad075509e1ce9f4c1955ee58d/integration/sw-rib-top03/TOP03_SURFACE_FORMULATION_REASSESSMENT.md):
  66 trajecten faalden zonder regimewisseling. Een bevroren stap toonde een
  residualsprong over nul bij de toenmalige nabij-verzadigde K-cutoff, begrensd
  tot de onderzochte tak en het onderzochte interval.
- [Gezamenlijke nabij-verzadigingsproef van 3 oktober](https://github.com/abhedwig-cell/SWAP5/blob/f5063889e4a7ab1ad075509e1ce9f4c1955ee58d/integration/sw-rib-top03/TOP03_JOINT_NEARSATURATION_SURFACE_DECISION.md):
  een consistente vrije-onderrandafgeleide samen met een testmatige gewijzigde
  hydraulische curve liet één stijg-/daalgeval alle zes verfijningen doorlopen.
  De onderzochte overgangsbreedten waren geen gekalibreerde productiekeuze.

De huidige wet4-reparatie neemt het mechanisme K-continuïteit plus consistente
afgeleiden mee, maar neemt de TOP03-wijzigingen van theta/capaciteit, microreliëf,
externe inundatie of Ribasim-eigenaarschap niet over. Die onderzoeksscope blijft
apart. De huidige dynamische provider houdt de flux/headregimes en de
`1e-6 cm` headclassificatiedrempel. Die drempel is iets anders dan de gevraagde
temporele nauwkeurigheid van de seizoenberekening.

De nieuwe waarnemingen ondersteunen daarom deze volgorde: eerst herhaalde
mislukte Newton-pogingen en de daaropvolgende tijdstapkeuze onderzoeken, daarna
met een geïsoleerde tegenproef vaststellen wat een andere bovenrandformulering
nog oplevert. Een universele winst door het afschaffen van de regimewisseling
is niet aangetoond.

## Behoudtests en resterende integratiegrens

De echte huidige stoftransportapplicatie is met GNU 13.3 op O0 en O2 opnieuw
gebouwd, elk met 190 productieproviders plus de oorspronkelijke invoerproviders,
boundschecks en FPE-traps. Ongewijzigde bestaande tests slagen:

- oorspronkelijke bestandsapplicatie: 86 proceswaarnemingen, inclusief onafhankelijke
  herstart, negatieve invoer en crashgrenzen;
- oorspronkelijke SWP-waterinvoer: 110 proceswaarnemingen, 12 mappinggevallen,
  12 onafhankelijke herstarts en 60 afwijzingen;
- dagelijkse meteorologie: 72 proceswaarnemingen, inclusief de oorspronkelijke
  meteorologische oracle en echte kolomberekeningen.

160 bestaande fysieke uitvoerbestanden zijn bytegelijk aan de oorspronkelijke
toegelaten bewijsset. Dit bewijs vervangt geen niet-uitgevoerde toelatingscontrole.

De broncontrole `integration/audits/verify_swp_daily.py:source` stopt nog met
`foreign daily scientific delta`. Deze authority laat alleen de oorspronkelijke
invoerwijziging en de onveranderde productiekern toe. Het acht bestanden grote
weather-opvolgbeeld is daarin nog niet geregistreerd. Ook de directe FSI35-freeze
van het solvercontract en de transitieve compilatie-identiteiten vereisen een
expliciete opvolgregistratie. Oude PASS-resultaten zijn niet als actueel herlabeld;
geen guard of fysieke assertie is verzwakt. De reparatie is daarom nog niet
canoniek toegelaten of gemerged.

De volgende integratiestap is een exact begrensde opvolg-authority met behoud van
de oorspronkelijke SOL/NUT/FSI35-controles en de werkelijk benodigde verse
fysieke dekking. Vervolgens pas de kandidaat als mergeklaar beoordelen.

Bewijs: `PERF01_SURFACE_FOLLOWUP_20261022_EVIDENCE.json`, het gelijknamige
`.tar.xz`-archief en `.index.json`. Controle:
`python benchmarks/performance/verify_perf01_surface_followup.py --self-test`.
