# SWAP 4.3.1 → SWAP5 volledige migratiekaart

## Doel

Deze kaart beschrijft de volledige omzetting van de SWAP 4.3.1-programmastroom naar
SWAP5. De bestaande B1.10-fysica blijft tijdens de overgang de gedragsreferentie;
de uiteindelijke SWAP5-productiecode mag geen monolithische legacy-eigenaar,
verborgen globale toestand of bestands-I/O in de kernel overhouden.

## Productie-eigenaren

| Legacy ingang | SWAP5-eigenaar | Migratiestap | Afsluitcriterium |
|---|---|---|---|
| `swap_main.f90` | runtime/application composition | dunne adapter met typed config, lifecycle en result sink | geen fysica of retrybeleid in entrypoint |
| `readswap.f90` | input adapter + typed configuration | parser isoleren, valideren en vertalen | kernel uitvoerbaar zonder bestanden |
| `timecontrol.f90` | interval/event scheduler + retry policy | scheduler, trial en acceptatie los trekken | geen dag-/kalenderaanname in kernel |
| `swap.f90` | kernel interval executor | lifecycle, forcing, solver en commit scheiden | één eigenaar voor committed state |
| `headcalc.f90` | Richards solver service | behouden als tijdelijke B1-owner, daarna typed solver contract | dezelfde acceptatie/massa/retry-transcripten |
| `swapoutput.f90` | typed result/diagnostic adapters | output formatteren buiten kernel | geen legacy output-side-effects in kernel |

## Volgorde

1. **Baseline en inventory** — alle legacy entrypoints, globals, side-effects en
   call-sites vastleggen; niets verwijderen.
2. **Typed runtime shell** — application/session/context en result sink compleet
   maken; standalone en coupling gebruiken dezelfde shell.
3. **Input/output firewall** — parser en legacy formatter adapters buiten de kernel
   plaatsen; typed in-memory execution als primaire route testen.
4. **Interval scheduler** — generic `[t0,t1]` events, kalenderprojectie en retry
   policy onafhankelijk maken van fysica.
5. **Transactional state** — committed state, trial capsule, rollback en restart
   ownership centraliseren; rejected trials mogen geen state muteren.
6. **Physics services** — Richards, root uptake, surface, drainage, irrigation,
   solute/heat en coupling achter typed service-contracten binden.
7. **Production cutover** — SWAP5 runtime als enige productie-ingang activeren;
   legacy route blijft uitsluitend als expliciete compatibility adapter.
8. **Legacy retirement** — pas na volledige equivalentie, massa-, restart-, O0/O2-
   en fail-closed-kwalificatie ongebruikte legacy control-flow verwijderen.

## Per subsystem verplichte gates

- numerieke equivalentie tegen de gecorrigeerde B1-reference;
- identieke O0/O2-transcripten waar determinisme vereist is;
- harde massabalans zonder tolerantieversoepeling;
- retry/backtracking met exacte gebruikte trial-state;
- restart midden in een interval;
- eigenaarstoewijzing zonder tweede verborgen state-owner;
- fail-closed gedrag bij ongeldige, niet-finite of incomplete input;
- standalone, MultiSWAP en coupling via dezelfde kernel;
- geen productie-admissie op basis van uitsluitend source-oracles.

## Eerste uitvoerbare checkpoint

Maak een machineleesbare inventory van `swap_main.f90`, `swap.f90`,
`timecontrol.f90`, `readswap.f90`, `swapoutput.f90` en hun directe call-sites.
Classificeer elke routine als `adapter`, `runtime`, `scheduler`, `transaction`,
`physics`, `coupling` of `result`. Leg per item de beoogde SWAP5-eigenaar en
verwijderingsvoorwaarde vast. Deze inventory is de ingang voor de eerste echte
extractie uit de monolithische runtime.

## Niet-doen

- geen brede tolerantie-, retry- of solverwijziging om een gate groen te maken;
- geen productie-admissie van source-only bewijs;
- geen gelijktijdige tweede state-owner;
- geen verwijdering van de B1-reference voordat equivalentie aantoonbaar is.
