# Na RESTART08

Lees STATUS.json, RESULT.json, CONTRACT.json en REPORT.md op de definitieve commit. SOURCE_MAP.json bindt 24 bronfragmenten aan oorspronkelijke bronhashes. contract08.py voert alleen bron-/bestaande-evidencecontrole uit; geen nieuw model of Fortranwijziging en geen restart-PASS.

Ontbrekend zijn domeinwater, lopende sorptieklok/referentie/beginsorptiviteit en geaccepteerde scheurgeometrie/historie. Casus heeft krimpende klei; H/theta alleen zijn niet genoeg. Coherente wet-wall/niveau/volume- en oppervlaktecaches moeten vóór eerste gebruik hersteld of zuiver gereconstrueerd zijn. MACROSTATE is geen restorehelper: hij integreert debieten en klok. M1-trialbasis wordt door de volgende SoilWater2/MacroStateVar1 opnieuw uit actuele toestand gemaakt. FlEndSrpEvt en rates worden opnieuw geëvalueerd; maak niet iedere gemeten mismatch persistent.

Native eigen DT was aanwezig, maar TimeControl1 forceert dagstart en TimeControl2 verhoogt dt naar sqrt(dtmin*dtmax), exact de gemeten .0001414213562. Alleen macroblok schrijven/lezen is onvoldoende. Ook subdagfase, exacte real8-tijd/volgende dt en dagelijkse forcing-/cropcontext moeten fasegetrouw hervatten. Alleen dagstart uitzetten zonder daily context is evenmin correct.

Minimale begrensde implementatie: versioned native macrotrailer + lokaal staged lezen, restart-aware macroinit zonder koude voorraadseed/tijdintegratie, en expliciete accepted-subday hostresume. Ondersteun eerst alleen huidige B-checkpoint SWMBF1/SWABS1/IDec0/FlDecfalse/SWDRA1/SWFROST0/SWHYST0/SWSOLU0 met bestaande warmte/crop. Gereduceerde historie vraagt ook verborgen headcalc::NStep; reset die niet stil. Geen algemene statearchitectuur of nieuwe physics.

Vervolgproef: dezelfde own checkpoint en continue stap, exacte initialisatietoestand en pre-head-forcing/dt/rollbackbasis, één volledige gelijktijdige hoststap, onafhankelijke inventaris O0/O2, maximaal20s/route. Alleen nieuwe echte-retrytest wanneer de rollback-seam verandert. Geen tweedaagse/481 of nieuwe scenariozoektocht. Geen promotie.

Cumulatieve uitvoer is apart open. MacroIntegral shadowt module-FrMpWalWetOld lokaal zonder expliciete SAVE; huidige dump ziet dat niet. Geen claim dat dit reeds een bewezen fysieke fout is. Exacte output/PEARLcontinuïteit vereist een aparte gerichte gate; physicalrestart-PASS mag niet als full-output-PASS worden verkocht. Andere modi/droge event/h0 blijven expliciet uitgesloten.
