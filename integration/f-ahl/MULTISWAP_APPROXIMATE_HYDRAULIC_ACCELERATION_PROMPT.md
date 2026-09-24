# Vervolgprompt: MultiSWAP approximate hydraulic acceleration

Ga verder binnen repository:

abhedwig-cell/SWAP5

Werk rechtstreeks met de GitHub-connector.

## Rol

Deze chat is exclusief eigenaar van een nieuwe onderzoekswerkstroom:

**MultiSWAP approximate hydraulic acceleration**

Deze lijn bouwt voort op de gesloten F-AHL researchfase, maar heeft bewust een andere doelstelling.

F-AHL onderzocht strikte versnelling van Richards-hydraulica zonder betekenisvolle verandering van de standaard SWAP-oplossing en met behoud van nonlinear convergence behaviour.

Deze nieuwe lijn mag expliciet onderzoeken hoeveel extra snelheid mogelijk is wanneer niet langer pointwise constitutieve of timestep-level equivalentie centraal staat, maar application-level hydrologische nauwkeurigheid over relevante simulatieperioden.

Dit is geen toestemming voor willekeurige approximatie.

Alle foutbudgetten moeten vooraf expliciet, fysisch interpreteerbaar en prospectief worden vastgelegd.

## Gebonden F-AHL evidence

Heropen de volgende F-AHL-resultaten niet zonder nieuwe evidence:

- auto-generated derivative-consistent retention/capacity lookup werkt in de gekwalificeerde prescribed-head B1.10 envelope;
- theta en C moeten uit dezelfde representation komen;
- near saturation h>-1 cm blijft analytisch;
- build once, freeze, run;
- geen runtime refinement tijdens Newton of timestep retries;
- interne immutable caching is technisch haalbaar;
- controlled complete-Richards speedup in de strikte prescribed-head matrix ligt rond 20-24%;
- prescribed-qbot is in de strikte architecture teruggevallen op volledig analytische hydraulica omdat kleine retention/C-fouten extra nonlinear werk kunnen veroorzaken;
- brute-force global densification is geen zinvolle algemene repairstrategie;
- extreme-dry representatie moet semantics-aware begrensd worden en niet automatisch steeds fijner worden.

## Centrale vraag

**How much additional computational speed can be obtained by relaxing hydraulic representation accuracy to application-relevant error budgets, while keeping long-term hydrological quantities demonstrably within predefined acceptable bounds?**

## Primaire observabelen

Gebruik niet alleen pointwise theta, C, K of pressure-head error.

Beoordeel minimaal:

- cumulatieve actuele evapotranspiratie;
- cumulatieve bodemverdamping;
- cumulatieve transpiratie;
- grondwateraanvulling / bottom flux;
- drainage;
- runoff waar relevant;
- profielopslag en waterbalanssluiting;
- seizoens- en droogte-respons;
- timing en duur van stressperioden;
- grondwaterstandsrespons wanneer die door de gekozen fixture wordt gedragen.

## Werkhypothesen

Test expliciet:

1. veel constitutieve pointwise nauwkeurigheid uit F-AHL is strenger dan nodig voor application-level hydrologische output;
2. foutbudgetten kunnen regime- en observable-afhankelijk zijn zonder dat systematische bias ontstaat;
3. extra snelheidswinst is mogelijk door representatieresolutie te reduceren in hydraulisch weinig invloedrijke domeinen;
4. fouten in storage/retention en conductivity hebben verschillende application-level effecten;
5. een purpose-aware foutbudget kan beter zijn dan één uniforme constitutieve tolerantie;
6. sommige boundary-sensitive situaties moeten analytisch blijven, zelfs in approximate mode.

## Eerste fase

Begin met de huidige F-AHL B1.10 research envelope.

Definieer prospectief een kleine set representation levels, bijvoorbeeld:

- STRICT: huidige F-AHL candidate;
- MODERATE;
- AGGRESSIVE;
- eventueel een relevance-bounded dry-tail variant.

Kies de toleranties vóór de application-level runs.

Gebruik voldoende lange hydrologische trajectories om cumulatieve effecten zichtbaar te maken. Een enkele Richards solve is hier niet voldoende.

## Foutbudgetten

Definieer vóór uitvoering expliciete application-level gates.

Werk met meerdere budgets in plaats van één willekeurige norm, bijvoorbeeld een zeer strakke researchklasse en een praktischere MultiSWAP-klasse.

De exacte percentages moeten prospectief en gemotiveerd worden vastgesteld. Neem niet automatisch 'enkele procenten' als waarheid over.

Rapporteer altijd absolute én relatieve fout waar relevant, zodat kleine noemers niet tot misleidende percentages leiden.

## Performance

Meet:

- constitutieve evaluatiekosten;
- complete Richards CPU;
- volledige trajectory CPU;
- build- en cachekosten;
- uiteindelijk waar mogelijk whole-column / MultiSWAP-relevante runtime.

Scheid cold-build, warm-cache en steady-state runtime.

## Vergelijkingskader

MetaSWAP of andere vereenvoudigde modellen mogen later als context voor foutorde worden gebruikt, maar niet als rechtvaardiging om een foutbudget achteraf ruimer te maken.

De eigen MultiSWAP budgets moeten vooraf zelfstandig worden gedefinieerd.

## Governance

Werk in grote zelfstandige blokken:

RECONCILE -> BIND AUTHORITY -> PREREGISTER -> EXECUTE -> QUALIFY -> ANALYZE -> FALSIFY/REPAIR -> PERSIST -> CLOSE

Geen gate-retuning na het zien van resultaten.

Negatieve resultaten worden behouden.

Geen production admission vanuit deze lijn.

## Closeout

Werk toe naar een evidence-based antwoord op:

1. hoeveel extra speedup boven F-AHL strict haalbaar is;
2. welke hydrologische observabelen als eerste gevoelig worden;
3. welke bodem- en vochtregimes de approximation begrenzen;
4. of uniforme of purpose-aware foutbudgetten beter werken;
5. welke biases cumuleren over lange simulaties;
6. welke approximate modes verantwoord onderscheiden kunnen worden;
7. welke resultaten later bruikbaar zijn voor MultiSWAP production design.

Stop pas bij inhoudelijke closure of een echte wetenschappelijke/architectuurblocker.
