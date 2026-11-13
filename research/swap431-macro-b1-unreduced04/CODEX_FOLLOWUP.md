# Na UNREDUCED04

Lees `STATUS.json`, `RESULT.json` en `REPORT.md`. Dit is een afgeronde negatieve kwalificatie voor de **ongereduceerde fysische referentie-eis**: V1 faalt op vier originele dt-groottes, met zestig oorspronkelijke iteraties per poging, en vraagt bij dtmin fluxreductie. Reproduceer eerst alleen de bewaarde vectors met `assess_unreduced04.py`; herhaal de prefix of de twee dagen niet zonder gewijzigde afhankelijkheid of nieuwe concrete vraag.

De twee voorlopige routes met gewiste retryflag hebben slechts dertig iteraties op grotere stappen en zijn geen eindkwalificatie. Gebruik uitsluitend `data/O0/preserved` en `data/O2/preserved` voor de definitieve uitspraak. De begincontext komt exact overeen met INVENTORY03. Alle definitieve vectors zijn bytegelijk O0/O2.

Geen stap geaccepteerd, geen commit van fysische toestand en geen opgeschaalde fallback uitgevoerd. Gemeten voorraden, theta, geometrie en klok zijn na elke rollback exact hersteld; na de vierde ook de gemeten sorptie-/eventvelden. Er is geen noodzakelijke geheugenpatch aangetoond. Een volledige restart/droge-eventkwalificatie ontbreekt nog.

Vervolg uitsluitend na een afzonderlijke concrete onderzoeksselectie: diagnoseer stagnatie op deze ene oorspronkelijke toestand uit de oorspronkelijke freeze-/lijnzoek-/actieve-procesroute. Als dat een gerichte vergelijking rechtvaardigt, vergelijk hoogstens de reeds bestaande V2 op **dezelfde V1-prefix/begintoestand**, zonder algemene derde solvervariant en zonder historische campagne. Geen tolerantie-, dtmin- of reductiewetwijziging om een PASS te verkrijgen.

Bewaar B0, B1.12, canonical, actieve werkstromen en releasebasis. Geen migratie, 481-daagse run of referentiepromotie. Houd twintig seconden per route. Het feit dat een ongereduceerde wiskundige oplossing mogelijk bestaat is niet door deze V1-afwijzingen weerlegd; kwalificeer conclusies alleen voor de werkelijk geteste numerieke route.
