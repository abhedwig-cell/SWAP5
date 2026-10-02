"""Conservative bounded nonlinear lateral profile, research diagnostic only."""
import csv,itertools,json,math,sys,time
from pathlib import Path
import numpy as np
import scipy
from scipy.integrate import solve_ivp
from scipy.sparse import diags,csc_matrix,hstack,vstack

L,TI,TS=10.,.20,.45
MESHES=[8,16,32,64,128,256,512,1024]

class Slab:
    def __init__(self,n,beta):
        self.n,self.beta=n,beta
        self.edges=L*(np.arange(n+1)/n)**2
        self.dx=np.diff(self.edges);self.x=(self.edges[:-1]+self.edges[1:])/2
        self.dist=np.diff(self.x)
        self.bands=np.array([np.maximum(0,np.minimum(self.edges[1:],hi)-np.maximum(self.edges[:-1],lo))/(hi-lo) for lo,hi in [(0,.1),(.1,1),(1,5),(5,10)]])
    def psi(self,theta):
        if self.beta==0:return 10*(theta-TI)
        return 10*.25/self.beta*np.expm1(self.beta*(theta-TI)/.25)
    def diffusion(self,theta):return 10*np.exp(self.beta*(theta-TI)/.25)
    def rhs(self,y,wet,evap):
        p=self.psi(y[:-1]);q=np.empty(self.n+1)
        q[0]=(self.psi(TS)-p[0])/self.x[0] if wet else -evap
        q[1:-1]=-np.diff(p)/self.dist;q[-1]=0
        return np.r_[-np.diff(q)/self.dx,q[0]]
    def jac(self,y,wet):
        d=self.diffusion(y[:-1]);main=np.zeros(self.n)
        main[:-1]-=d[:-1]/self.dist/self.dx[:-1]
        main[1:]-=d[1:]/self.dist/self.dx[1:]
        if wet:main[0]-=d[0]/self.x[0]/self.dx[0]
        j=diags([d[:-1]/self.dist/self.dx[1:],main,d[1:]/self.dist/self.dx[:-1]],[-1,0,1],format='csc')
        last=csc_matrix(([-d[0]/self.x[0]],([0],[0])),shape=(1,self.n)) if wet else csc_matrix((1,self.n))
        return vstack([hstack([j,csc_matrix((self.n,1))]),hstack([last,csc_matrix((1,1))])],format='csc')
    def trial(self,accepted,times,wet,evap=0,tight=False):
        frozen=accepted.copy()
        sol=solve_ivp(lambda t,y:self.rhs(y,wet,evap),(0,times[-1]),accepted.copy(),t_eval=times,method='BDF',jac=lambda t,y:self.jac(y,wet),rtol=1e-10 if tight else 1e-9,atol=1e-12 if tight else 1e-11)
        assert np.array_equal(accepted,frozen),'accepted state mutated'
        assert sol.success,sol.message
        assert sol.y[:-1].min()>=.05-1e-9 and sol.y[:-1].max()<=TS+1e-9,'state outside declared physical envelope'
        return sol.y.T,dict(nfev=sol.nfev,njev=sol.njev,nlu=sol.nlu)

def checks():
    s=Slab(16,2);y=np.r_[np.linspace(.40,.20,16),0.]
    j=s.jac(y,True).toarray();fd=np.empty_like(j)
    for k in range(17):
        a=y.copy();b=y.copy();a[k]+=1e-7;b[k]-=1e-7
        fd[:,k]=(s.rhs(a,True,0)-s.rhs(b,True,0))/2e-7
    assert np.max(np.abs(j-fd)/(1+np.abs(j)))<1e-7,'Jacobian check'
    accepted=y.copy();a,_=s.trial(accepted,[.001],True);b,_=s.trial(accepted,[.001],True)
    assert np.array_equal(a,b) and np.array_equal(accepted,y),'reject/replay check'
    assert abs(s.dx@s.rhs(y,True,0)[:-1]-s.rhs(y,True,0)[-1])<1e-9,'instantaneous conservative identity'
    return {'jacobian_finite_difference':'PASS','immutable_trial_and_discard_replay':'PASS','semantics_scope':'research arrays, not production restart'}

def write(p,name,rows):
    with (p/name).open('w',newline='') as f:
        w=csv.DictWriter(f,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)

def run_mesh(n,tight=False):
    rows=[];profiles=[];counters=[]
    for beta in [-2,0,2]:
        s=Slab(n,beta);initial=np.r_[np.full(n,TI),0.]
        start,ct=s.trial(initial,[.2],True,tight=tight);before=start[0]
        for pulse,evap,gap in itertools.product([0,1],[0.,.1],[.01,.5]):
            external=0.;y=before.copy()
            snapshots=[('initial_wet',.2,y.copy())]
            if pulse:
                delta=.25*(TS-y[:-1]);external=float(s.dx@delta);y[:-1]+=delta
            snapshots.append(('external_pulse',.2,y.copy()))
            dry,cd=s.trial(y,[gap],False,evap,tight);y=dry[0]
            snapshots.append(('dry_end',.2+gap,y.copy()))
            renew,cr=s.trial(y,[.00025,.001,.01],True,tight=tight)
            snapshots += [('rewet_'+str(t),.2+gap+t,z) for t,z in zip([.00025,.001,.01],renew)]
            for stage,t,z in snapshots:
                ext=0. if stage=='initial_wet' else external
                storage=float(s.dx@z[:-1]);receipt=float(z[-1]);ledger=storage-L*TI-receipt-ext
                assert abs(ledger)<=1e-9,'ledger failed'
                row=dict(n=n,tight=int(tight),beta=beta,pulse=pulse,evap_cm_day=evap,gap_day=gap,stage=stage,time_day=t,storage_cm=storage,wall_receipt_cm=receipt,external_receipt_cm=ext,evaporation_loss_cm=0. if stage in ['initial_wet','external_pulse'] else evap*gap,ledger_cm=ledger,theta_min=float(z[:-1].min()),theta_max=float(z[:-1].max()),packed_moisture_bytes=8*n)
                row.update({'theta_band'+str(k):float(v) for k,v in enumerate(s.bands@z[:-1])})
                rows.append(row)
                if not tight and n in [64,1024] and (beta,pulse,evap,gap)==(2,1,.1,.5):
                    profiles += [dict(n=n,stage=stage,x_lo_cm=float(lo),x_hi_cm=float(hi),theta=float(th)) for lo,hi,th in zip(s.edges[:-1],s.edges[1:],z[:-1])]
            counters.append(dict(n=n,tight=int(tight),beta=beta,pulse=pulse,evap_cm_day=evap,gap_day=gap,wet_nfev=ct['nfev'],dry_nfev=cd['nfev'],rewet_nfev=cr['nfev'],wet_nlu=ct['nlu'],dry_nlu=cd['nlu'],rewet_nlu=cr['nlu']))
    return rows,profiles,counters

def key(r):return tuple(r[k] for k in ['beta','pulse','evap_cm_day','gap_day','stage'])
def compare(rows,reference,label):
    ref={key(r):r for r in reference};out=[]
    for r in rows:
        a=ref[key(r)]
        out.append(dict(n=r['n'],reference_n=a['n'],comparison=label,beta=r['beta'],pulse=r['pulse'],evap_cm_day=r['evap_cm_day'],gap_day=r['gap_day'],stage=r['stage'],storage_error_cm=abs(r['storage_cm']-a['storage_cm']),receipt_error_cm=abs(r['wall_receipt_cm']-a['wall_receipt_cm']),max_band_theta_error=max(abs(r['theta_band'+str(k)]-a['theta_band'+str(k)]) for k in range(4))))
    return out

def main(out):
    out.mkdir(parents=True,exist_ok=True);statechecks=checks();rows=[];profiles=[];counts=[]
    for n in MESHES:
        a,b,c=run_mesh(n);rows+=a;profiles+=b;counts+=c
        write(out,'lateral_trajectories.csv',rows)
        print('mesh complete',n,len(a),flush=True)
    tight,_,ct=run_mesh(1024,True);counts+=ct
    write(out,'lateral_tight_trajectories.csv',tight);write(out,'lateral_profiles.csv',profiles);write(out,'lateral_solver_counters.csv',counts)
    at=lambda n:[r for r in rows if r['n']==n]
    reference=at(1024)
    comparisons=compare([r for r in rows if r['n']<=128],reference,'candidate')
    refinement=compare(at(256),at(512),'256_512')+compare(at(512),reference,'512_1024')+compare(reference,tight,'temporal')
    write(out,'lateral_comparison.csv',comparisons);write(out,'lateral_reference_refinement.csv',refinement)
    summary={'state_checks':statechecks,'reference_gates':{},'candidates':{},'production_qualified':False,'versions':{'numpy':np.__version__,'scipy':scipy.__version__}}
    for label in ['256_512','512_1024','temporal']:
        a=[r for r in refinement if r['comparison']==label]
        mass=max(max(r['storage_error_cm'],r['receipt_error_cm']) for r in a);th=max(r['max_band_theta_error'] for r in a)
        summary['reference_gates'][label]={'max_mass_error_cm':mass,'max_theta_error':th,'pass':mass<=.0001 and th<=.0001}
    kk=(np.arange(10000)+.5)*np.pi/L
    analytic=L*(TS-TI)*(1-np.sum(2/(L*kk)**2*np.exp(-10*kk*kk*.2)))
    numerical=next(r['wall_receipt_cm'] for r in reference if r['beta']==0 and r['stage']=='initial_wet')
    summary['constant_D_analytic_error_cm']=float(abs(numerical-analytic))
    summary['max_ledger_cm']=max(abs(r['ledger_cm']) for r in rows+tight)
    for n in [8,16,32,64,128]:
        a=[r for r in comparisons if r['n']==n];cases={}
        for r in a:
            k=tuple(r[x] for x in ['beta','pulse','evap_cm_day','gap_day']);cases.setdefault(k,[]).append(r)
        fail=[k for k,v in cases.items() if max(max(r['storage_error_cm'],r['receipt_error_cm']) for r in v)>.01 or max(r['max_band_theta_error'] for r in v)>.001]
        summary['candidates'][str(n)]={'pass_cases':24-len(fail),'total_cases':24,'max_mass_error_cm':max(max(r['storage_error_cm'],r['receipt_error_cm']) for r in a),'max_theta_error':max(r['max_band_theta_error'] for r in a),'failing_cases':fail,'packed_moisture_bytes':8*n}
    summary['reference_qualified']=bool(all(summary['reference_gates'][k]['pass'] for k in ['512_1024','temporal']) and summary['constant_D_analytic_error_cm']<=.0001)
    (out/'lateral_summary.json').write_text(json.dumps(summary,indent=2)+'\n')
    print(json.dumps(summary,indent=2),flush=True)
    assert summary['reference_qualified'],'reference gate failed; preserve output before prospective refinement'
    print('A27_LATERAL_REFERENCE_CHECKS=PASS')

if __name__=='__main__':main(Path(sys.argv[1]))
