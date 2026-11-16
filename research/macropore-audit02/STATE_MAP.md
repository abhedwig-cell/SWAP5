# Original route state map

Source authority: original qualified O2/build in original-macro-481-evidence.zip;
provider generic-reference/build/swap-selected in
../hybrid-water01/hybrid-hupsel-linux-20261111.tar.xz. Generated checkpoint and
mass-guard adaptations are distinguished from unchanged original freeze logic.

| Routine/phase | Inputs and owned history | Mutation/cache | Subsequent consumer |
| --- | --- | --- | --- |
| SoilWater(2), StateVar(1) | h,theta,gwl,pond,domain volumes/unsaturated stores | hm1,thetm1,gwlm1,pondm1; ICpBtDmM1,VlMpDmCpM1,WaUnMpDmCpM1 | HeadCalc; rejected-step rollback |
| HeadCalc entry | accepted hydraulic/macro origin,dt,drain/root rates | k,kmean; sink/source; flunsatok reset FALSE; local F/gradient | nonlinear iteration |
| vector_F(1/2) | theta,h,hgrad,kmean,old theta,dt,source/sinks,top/bottom BC,Qmacro | boundary/pond caches; task1 always macro rate; task2 skips macro if flag3 TRUE; F subtracts QExcMpMtx | merit and convergence |
| MACROPORE(2), MACRORATE(1) | current h/theta,old volume/stores,geometry,wet wall,event duration,dt,forcing,drainage | calcgwl/classification,MPVOLUME(1),rates,absorption reference fields,QExcMpMtx,QMaPo,QRapDra | residual; later storage integration |
| MACROPORE(3), MACRORATE(2) | same current pressure-dependent rate inputs | reruns rates then derivative tasks; dFdhMp; local saved potential rates | Jacobian diagonal |
| SATFLOW | h,GWL classification,macro level/wet contact,geometry | SAVE DelHDmCp,FlwMtxSatDmCp; task4 derivative reads saved quantities | MACRORATE rate/derivative |
| ABSORPTION | theta,sorptivity parameters,wet contact,TimAbsCumDmCp,ThtSrpRefDmCp | SAVE DelHDmCp,Diffusivity,FlSorp; Time near zero rewrites SorpDmCp/ThtSrpRefDmCp | rates/derivatives; MACROSTATE |
| jacobian_F | dimoca,kmean,gradient,BC and flag3 | macro derivative subtracted only while flag3 FALSE; task3 may mutate exchange | tridiagonal direction |
| nonlinear criterion | local cached F,pressure increment,pond,total residual | flunsatok progresses; third flag may remain TRUE despite subsequent pressure movement | next iteration freeze; acceptance |
| rejection | fldecdt/FlDecMpRat | restores matrix four fields and only macro three arrays; TimeControl(5) changes retry controls | retry entry |
| acceptance in HeadCalc | cached F and pressure/pond criteria; mass guard | records counters; possible reduction-control update; no final fresh coupled check | SoilWater(3) |
| SoilWater(3), MACROSTATE | accepted h,retained exchange vectors,old stores,dt | conductivity/GWL/fluxes; domain storage via retained exchange; wet walls,contacts,event history,MPVOLUME(2) | MACROINTEGRAL; next step |
| MACROINTEGRAL | rates,wet walls,new storage,dt | cumulative/interval ledgers; separate historical quadrature wall endpoint | daily water balance/native checkpoint |

HeadCalc local SAVEs include dkdh,flwarn and original iwarn/NStep (latter
explicitly checkpointed by the research adapter). MACRORATE has many local
SAVE potential flow,deficit,interface and iteration arrays. They are included
in the executable static symbol inventory, not assumed absent from names.
The complete240-field restoration list and byte snapshots accompany the retry.
No COMMON is required by this selected module route. Static symbol snapshots
capture allocatable descriptors, not arbitrary heap targets; no universal whole
process rollback proof is claimed. Relevant selected macro arrays are static.
Source-backed read/overwrite-before-use plus the actual retry counterfactual
support only the bounded result documented in CAUSAL_DISPOSITION.md.
