"""Independent constant-D profile and linear exchange diagnostics, research only."""
import csv, json, math, sys
from pathlib import Path
import numpy as np
from scipy.fft import dct,idct,dst,idst
L,D,TI,TS=10.,10.,.20,.45
S0=2*(TS-TI)*math.sqrt(D/math.pi)
OUT=Path(sys.argv[1]);OUT.mkdir(parents=True,exist_ok=True)
def evolve(theta,t,wet):
    n=len(theta);dx=L/n
    if wet:
        lam=-4*D/dx**2*np.sin((np.arange(n)+.5)*np.pi/(2*n))**2
        return TS+idst(dst(theta-TS,type=4,norm='ortho')*np.exp(lam*t),type=4,norm='ortho')
    lam=-4*D/dx**2*np.sin(np.arange(n)*np.pi/(2*n))**2
    return idct(dct(theta,type=2,norm='ortho')*np.exp(lam*t),type=2,norm='ortho')
def amount(a,b):return float((b-a).sum()*L/len(a))
def analytic(t):
    k=(np.arange(10000)+.5)*np.pi/L
    return L*(TS-TI)*(1-np.sum(2/(L*k)**2*np.exp(-D*k*k*t)))
validation=[];interruption=[];wetting=[];profiles=[]
for n in [128,256,512]:
    initial=np.full(n,TI)
    for t in [.05,.2,1.]:
        p=evolve(initial,t,True);u=amount(initial,p)
        validation.append(dict(n=n,time_day=t,uptake_cm=u,analytic_cm=analytic(t),error_cm=abs(u-analytic(t))))
        assert p.min()>=TI-1e-12 and p.max()<=TS+1e-12
    before=evolve(initial,.2,True)
    for delta in [.00025,.001,.01]:
        pulse=before+.25*(TS-before)
        after=evolve(pulse,delta,True);control=evolve(before,delta,True)
        exact_u=amount(pulse,after);base_u=amount(before,control)
        assert abs(exact_u-.75*base_u)<1e-12
        frozen=S0*(math.sqrt(.2+delta)-math.sqrt(.2))
        theoretical_mean=TI+S0*math.sqrt(.2)/L
        theta_ref=TS+(theoretical_mean-TI)
        active=2*math.sqrt(D/math.pi)*max(0,theta_ref-float(pulse.mean()))
        corrected=active*(math.sqrt(.2+delta)-math.sqrt(.2))
        wetting.append(dict(n=n,interval_day=delta,external_receipt_cm=amount(before,pulse),control_uptake_cm=base_u,pulsed_uptake_cm=exact_u,frozen_uptake_cm=frozen,mean_corrected_uptake_cm=corrected,mean_after_pulse=float(pulse.mean()),ratio_to_control=exact_u/base_u))
    for gap in [.001,.01,.1,.5]:
        dry=evolve(before,gap,False)
        assert abs(amount(before,dry))<1e-10
        erased=np.full(n,float(dry.mean()))
        reset_seed=2*(TS-float(dry.mean()))*math.sqrt(D/math.pi)
        for renew in [.00025,.001,.01]:
            actual=amount(dry,evolve(dry,renew,True))
            erased_u=amount(erased,evolve(erased,renew,True))
            reset=reset_seed*math.sqrt(renew)
            retained=S0*(math.sqrt(.2+renew)-math.sqrt(.2))
            interruption.append(dict(n=n,gap_day=gap,renewed_day=renew,matrix_mean=float(dry.mean()),dry_mass_change_cm=amount(before,dry),retained_profile_uptake_cm=actual,same_mean_homogenized_uptake_cm=erased_u,reset_seed_uptake_cm=reset,retained_clock_uptake_cm=retained,reset_over_reference=reset/actual))
        if n==512:
            after=evolve(dry,.001,True)
            for j in range(n):profiles.append(dict(n=n,gap_day=gap,x_cm=(j+.5)*L/n,theta_before_dry=float(before[j]),theta_after_dry=float(dry[j]),theta_after_rewet=float(after[j]),theta_homogenized=float(erased[j])))
assert max(r['error_cm'] for r in validation if r['n']==512)<=.0001
fine={(r['gap_day'],r['renewed_day']):r for r in interruption if r['n']==512}
mesh_error=max(abs(r['retained_profile_uptake_cm']-fine[(r['gap_day'],r['renewed_day'])]['retained_profile_uptake_cm']) for r in interruption if r['n']==256)
assert mesh_error<=.0001
coupling=[];cm,cp=.5,.05
for ks in [.025,1.,5.]:
    g=8*ks/100;kap=g*(1/cm+1/cp)
    for dt in [.5,.25,.125,.0625]:
        for mode in ['exact','explicit','backward','subcycle','one_sided']:
            hm,hp=2.,4.;external=0.;cum=0.;initial=cm*hm+cp*hp;overshoots=0;negative=0
            for step in range(round(1/dt)):
                t=step*dt
                if abs(t-.5)<1e-12:hm+=4.;external+=4*cm
                olddiff=hp-hm
                if mode=='exact':u=olddiff*(1-math.exp(-kap*dt))/(1/cm+1/cp)
                elif mode=='backward':u=g*dt*olddiff/(1+kap*dt)
                elif mode=='subcycle':
                    nsub=max(1,math.ceil(kap*dt/.1));u=olddiff*(1-(1-kap*dt/nsub)**nsub)/(1/cm+1/cp)
                else:u=g*dt*(max(0.,olddiff) if mode=='one_sided' else olddiff)
                hm+=u/cm;hp-=u/cp;cum+=u
                overshoots+=int(olddiff*(hp-hm)<-1e-12)
                negative+=int(min(hm,hp)<0.)
                residual=cm*hm+cp*hp-initial-external
                assert abs(residual)<1e-10
                coupling.append(dict(Ks=ks,g=g,kappa=kap,dt_day=dt,mode=mode,time_day=(step+1)*dt,matrix_head_cm=hm,macro_head_cm=hp,cum_macro_to_matrix_cm=cum,interval_macro_to_matrix_cm=u,external_matrix_receipt_cm=external,mass_residual_cm=residual,equilibrium_overshoots=overshoots,negative_head_steps=negative))
# Compare at matching sample times against exact integrated exchange.
exact={(r['Ks'],r['dt_day'],r['time_day']):r for r in coupling if r['mode']=='exact'}
for r in coupling:
    x=exact[(r['Ks'],r['dt_day'],r['time_day'])]
    r['macro_head_error_cm']=abs(r['macro_head_cm']-x['macro_head_cm'])
    r['cum_exchange_error_cm']=abs(r['cum_macro_to_matrix_cm']-x['cum_macro_to_matrix_cm'])
for name,rows in [('slab_validation.csv',validation),('wetting_feedback.csv',wetting),('interrupted_contact.csv',interruption),('interrupted_profiles.csv',profiles),('signed_coupling.csv',coupling)]:
    with (OUT/name).open('w',newline='') as f:
        w=csv.DictWriter(f,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)
summary={'slab_finest_analytic_error_cm':max(r['error_cm'] for r in validation if r['n']==512),'rewet_256_512_max_difference_cm':mesh_error,'dry_max_mass_change_cm':max(abs(r['dry_mass_change_cm']) for r in interruption),'wetting_ratio_exact':.75,'reset_ratio_range_finest':[min(r['reset_over_reference'] for r in interruption if r['n']==512),max(r['reset_over_reference'] for r in interruption if r['n']==512)],'coupling':{mode:{'max_macro_head_error_cm':max(r['macro_head_error_cm'] for r in coupling if r['mode']==mode),'max_exchange_error_cm':max(r['cum_exchange_error_cm'] for r in coupling if r['mode']==mode),'max_equilibrium_overshoots':max(r['equilibrium_overshoots'] for r in coupling if r['mode']==mode),'max_negative_head_steps':max(r['negative_head_steps'] for r in coupling if r['mode']==mode)} for mode in ['explicit','backward','subcycle','one_sided']},'production_qualified':False}
(OUT/'physical_mechanisms_summary.json').write_text(json.dumps(summary,indent=2)+'\n')
print(json.dumps(summary,indent=2))
print('A27_INDEPENDENT_MECHANISM_REFERENCE_CHECKS=PASS')
