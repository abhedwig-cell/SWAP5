# F-ROM-LARE BC2-C4G closeout

C4G tested metric sensitivity only. It did not replace the historical unweighted mass-neutral theta RMS used by C2, C3 and C4E.

Formal decision: WIDTH_EFFECT_ROBUST_TO_DEPTH_WEIGHTING.

The secondary metric weights each mass-neutral theta-shape component by its instantaneous physical thickness. This reduces the leverage of the thin terminal coordinate but keeps the 2.5-versus-5 cm response direction unchanged in both internal-dt routes.

For 2.5 cm WT_RISE, QI removal worsens pooled shape error under both metrics. The ratio falls from about 3.855 under the historical norm to about 2.141 under depth weighting, but all 512 intervals still worsen in both routes.

For 5 cm WT_RISE, QI removal improves pooled shape error under both metrics. The ratio changes only from about 0.2972 to about 0.2945; only one of 512 intervals changes removal direction under reweighting.

The FALL cases retain the same pooled direction as well: 2.5 cm worsens and 5 cm improves. The 2.5 cm full-history weighted FALL metric remains algebraic diagnostic evidence only because C4F established that the QI-removal state is physically inadmissible on 499 intervals.

Therefore the width-dependent QI behavior cannot be dismissed as an artifact of giving every reduced control volume equal weight. Together C4F and C4G point to the representation/closure geometry itself.

A new terminal reconstruction hypothesis may now be preregistered. It must remain physically admissible, conservative and diagnostic first. No free-running corrected LARE, groundwater-feedback test, application acceptance, speed claim or production ROM is authorized by C4G.
