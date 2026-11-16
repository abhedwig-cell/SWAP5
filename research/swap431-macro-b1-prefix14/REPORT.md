# PREFIX14 — gerichte capture vanaf oorspronkelijk balansbegin

**Beide geselecteerde prefixroutes zijn op de oorspronkelijke twintigsecondenlimiet gecensureerd. De volledige periodebalans is niet gekwalificeerd.** O0 legt770 gecommitteerde stappen vast tot t1900=35796,419000005524; O2 legt787 vast tot35796,43600000658. Doel was dezelfde voltooide daggrens35797. Er bestaat geen volledig periodebestand en er zijn daarom geen verse eigen herstartroutes gestart.

De gemeenschappelijke770 staprecords en alle beginexports zijn bytegelijk tussen O0 en O2. Er zijn nu exacte oorspronkelijke beginvoorraden beschikbaar, maar geen onafhankelijk opgeslagen fysieke eindinventaris op het timeoutmoment. Uit de fluxrecords wordt dus ook geen gedeeltelijk balans-PASS afgeleid.

## Vastgelegde route en grens

Basis is HISTORY13 `7a1bba2bab466316cdf0ba5d5e4cae282ab78dc3`, met de bestaande LEDGER12-native closure. Canonical is gereconcilieerd op `f1883e6fae59658112f6b5750c395a1b54543ed2`; de gerichte macro-Fortran/swap431-delta is leeg. Alleen de nieuwe onderzoeksmap is gewijzigd. B0/B1.12/canonical/release en andere werkstromen blijven ongewijzigd.

Het oorspronkelijke balansbegin is TSTART1998-01-01/t1900=35795. Deze route gebruikt de bestaande V1 plus CONTRACT06-Darcycorrectie **vanaf de eerste headcalc**, met expliciete LEDGER12-uitvoerhistorie. De patch wordt vóór de eerste daglus ingeschakeld en blijft actief. Dat verschilt bewust van de eerdere staged proeven waarin de oorspronkelijke aanloop zonder patch werd doorlopen. De oude staged-prefixprestatie en balansen worden daarom niet als nieuw resultaat geërfd.

Per optimalisatie was één ononderbroken koude prefix tot35797 geselecteerd. Geen fysieke formules, solvercriteria, tijdstapgrenzen of reductiewet zijn veranderd. De oorspronkelijke invoerbestanden worden vooraf op identiteit gecontroleerd. TEND Jan3 blijft uitsluitend nodig voor een eventueel gekwalificeerde volgende-dagherstart; de capture stopt zodra de bedoelde daggrens en één aansluitende controle bereikt zouden zijn. SWBAL/SWBLC/SWBMA zijn ingeschakeld en DATEFIX is2januari, zodat het echte geplande periode-uitvoerevent Jan1–Jan2 zou plaatsvinden. Dit zijn uitvoerinstellingen, geen gewijzigde forcing of fysieke scenario's.

Er zijn precies twee modelprocessen uitgevoerd en geen herhalingen. De ingestelde deadline is20seconden; gemeten totale aanroeptijden inclusief beëindigen en verzamelen zijn20,3465s voor O0 en20,0944s voor O2. Deze worden als gecensureerd bewaard, niet als toegelaten overschrijding of PASS. De route is niet opgesplitst, niet met ruimere timeout herhaald en niet door een oudere snellere variant vervangen. Geen481-daagse campagne.

## Capture en oorspronkelijke beginvoorraden

De instrumentatie legt de exacte begininventaris, oorspronkelijke uitvoerbeginwaarden en uitgebreide context vast. Na iedere echte geaccepteerde hostcommit wordt een primitive-budgetregel geschreven: werkelijke dt, bruto/netto regen en irrigatie, canopy-/bodem-/pondverdamping, wortelonttrekking, bodemflux, drainage, SSDI, snelle macrodrainage, runoff, werkelijke reductiefactor en domeininstroom/-uitwisseling. Er is geen reconstructie uit afgeronde dagelijkse CSV en geen handmatige beginvoorraadcorrectie.

Exacte gemeenschappelijke beginwaarden:

- Matrixwater: **153,08077642218285cm**.
- Macro MB: **1,5819999999999999cm**.
- Macro IC, som van de oorspronkelijke subdomeinen: **0,04949324324324319cm**.
- Macro totaal: **1,6314932432432430cm**.

Deze waarden vervangen niet stil de oude nulbeginwaarden in reeds uitgevoerde restartproeven. Zij horen bij de nieuwe ononderbroken koude route. De afgeronde oorspronkelijke HISTORY13-dagregel is ermee verenigbaar en blijft afzonderlijk historisch bewijs.

Alle vastgelegde regels hebben FrReduQ=1. Dat beschrijft alleen de bereikte prefix; het bewijst geen ongereduceerde acceptatie tot het ontbrekende eindpunt. Er zijn geen volledige verse residuvectors voor alle prefixstappen geëxporteerd. De oorspronkelijke V1-headcriteria zijn behouden; er wordt geen aanvullende numerieke of volledige wetenschappelijke kwalificatie geclaimd.

## Wat niet is bereikt

Geen van beide processen bereikt35797. Het native completed-day-schrijfpad, volledige periode-uitvoer en verse herstart van dat bestand zijn daarom niet uitgevoerd. Een voorlopige V4-uitbreiding voor ledger-oorsprong, gedekte eindtijd, volledigheid en `PATCH_FROM_BALANCE_ORIGIN` is geïmplementeerd en gecompileerd. Zij is **niet gekwalificeerd**: zonder een bereikt eindpunt is geen complete V4-capture ontstaan en geen V4-readback uitgevoerd.

Er is evenmin een eindinventaris van de laatst gecommitteerde prefixstap opgeslagen; alleen de primitieve fluxrecords en gedeeltelijke normale uitvoer zijn beschikbaar. Een voorraad afleiden door diezelfde fluxen op te tellen en daarna als onafhankelijke balanscontrole presenteren zou circulair zijn. `RESULT.json` maakt dit expliciet.

De verschillende laatste tijden zijn het gevolg van dezelfde deadline bij verschillende optimalisaties. Zij bewijzen op zichzelf geen numerieke divergentie: de770 gemeenschappelijke regels zijn exact. Andersom bewijst dit geen afwezigheid van een latere numerieke moeilijkheid. De huidige capture stelt geen stagnatiepunt of solverfout vast.

Een kleine bestands-I/O-proef zonder model vergelijkt50 append/open/close-acties met één open bestand. Zij toont enig verschil, maar onderbouwt niet dat logging de twintigsecondenuitkomst domineert. Er is op die onbewezen aanname geen extra modelroute gestart. De gegevens staan in `IO_CHECK.json`.

## Besluit en herstelpad

Status: **PREFIX_CAPTURE_CENSORED_FULL_PERIOD_NOT_QUALIFIED**. Eerdere lokale native/herstart-/uitvoercontinuïteits-PASS'en worden niet ingetrokken, maar gelden nog steeds uitsluitend voor hun oorspronkelijke contexten. Er is geen nieuwe volledige periodekwalificatie of promotie.

Een vervolgstap vergt eerst een afzonderlijk geselecteerde, begrensde diagnose van de rekentijd/iteratiegeschiedenis van de vaste kandidaatprefix. Deze opdracht geeft geen reden de timeout stil te verhogen, dezelfde route in stukken verder te laten lopen, beginsaldi te verzinnen of een solvervariantcampagne te starten. De exacte begininventaris en gecensureerde prefixes zijn wel een concreet herstelpunt voor die eventuele diagnose.

Lees STATUS.json, RESULT.json, prefix_capture.patch en de bewaarde budgetrecords. `assess_prefix14.py` controleert bronidentiteit, timeouts, ontbreken van complete bestanden en de gemeenschappelijke O0/O2-prefix zonder modellen. De bewijscapsule bewaart ook de complete native compile/link-closure en beide onvoltooide routes.
