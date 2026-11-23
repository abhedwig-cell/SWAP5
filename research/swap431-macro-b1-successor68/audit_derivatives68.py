"""Independent real-provider gradient and actually used correction audit; no models."""
from pathlib import Path
import json,math,hashlib,sys
R=Path(__file__).resolve().parent
W=Path('C:/Users/Veldh012/SWAP5-work/01a1f3ce-667e-7091-82ae-a62485d14eca-8c08570e/successor68-data/evidence/data')
if len(sys.argv)>2:W=Path(sys.argv[2])
def rows(p):return [list(map(float,s.split())) for s in p.read_text().splitlines() if s.strip()]
def sha(p):
    with p.open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
def audit(opt):
    bare=W/(opt+'_BARE');d=W/(opt+'_FD')
    names=[p.name for p in bare.glob('*.txt') if p.name not in ['cost_trace.txt','attempt_trace.txt','inactive51_trace.txt']]
    for n in names:assert (bare/n).read_bytes()==(d/n).read_bytes(),n
    assert (bare/'follow67.end').read_bytes()==(d/'follow67.end').read_bytes()
    assert [x[:-1] for x in rows(bare/'attempt_trace.txt')]==[x[:-1] for x in rows(d/'attempt_trace.txt')]
    # Inherited inactive observer can log additional rows during provider probes.
    old=(bare/'inactive51_trace.txt').read_text().splitlines();actual=(d/'inactive51_trace.txt').read_text().splitlines();ix=0
    for s in actual:
        if ix<len(old) and s==old[ix]:ix+=1
    assert ix==len(old)
    systems=rows(d/'jac63_systems.txt');points=[]
    for branch in [1,2]:
        a=rows(d/f'potential68_b{branch}_points.txt');assert len(a)==26*11
        a=[a[i:i+11] for i in range(0,len(a),11)];b=a[0];c=b[0][4:28];m=b[7];N=112
        assert a[0][0][1:]==a[-1][0][1:]
        assert all(a[0][i]==a[-1][i] for i in range(1,11) if i!=8)
        receipt=rows(d/f'potential68_b{branch}_restore.txt');assert len(receipt)==26 and all(x[3:]==[1,1,1] for x in receipt)
        assert sha(d/f'potential68_b{branch}_base.bin')==sha(d/f'potential68_b{branch}_restored.bin')
        assert sha(d/f'potential68_b{branch}_cache.bin')==sha(d/f'potential68_b{branch}_cache_restored.bin')
        assert m[12]==1 and m[14]==50 and m[10]==0 and m[15]==1 and c[19]==50
        volume=c[3]<c[0];assert volume==(branch==2)
        assert [i+1 for i,x in enumerate(b[1]) if x>0]==list(range(51,58))
        assert [i+1 for i,x in enumerate(b[2]) if x>0]==([50] if branch==2 else [])
        Hm=b[0][27];z=b[10];dz=b[4];h=b[6];C=m[0];theta=m[1];thetaS=m[2];thetaR=m[3];power=m[5];dt=c[20]
        deficit=thetaS-theta;assert deficit>1e-8
        raw=4*m[6]*m[7]*dz[49]/m[8]*m[9]*m[4]*(deficit/(thetaS-thetaR))**power*math.sqrt(dt)
        assert raw<1e3*dt*dz[49]
        span=min(z[49]+.5*dz[49],Hm)-(z[49]-.5*dz[49]);overlap=max(0,min(z[49]+.5*dz[49],Hm)-c[18]);assert 0<=overlap<span
        B=raw/span;Bp=-power*C/deficit*B
        assert abs(B*overlap-b[2][49])<1e-24
        den=h[50]-h[49];g0=(z[49]-z[50])*h[50]/den**2;g1=-(z[49]-z[50])*h[49]/den**2
        G=[[0.]*N for _ in range(N)]
        for i in range(50,57):
            assert h[i]>0 and Hm-z[i]-h[i]>1e-8
            assert abs(b[1][i]-dt*b[9][i]*(Hm-z[i]-h[i]))<1e-20
            G[i][i]=-dt*b[9][i]
        if overlap>0:G[49][49]=Bp*overlap-B*g0;G[49][50]=-B*g1
        # Independent full derivative of actual exchange, including limiter factor.
        dL=[0.]*N
        if volume:dL[49]=c[17]*g0;dL[50]=c[17]*g1
        df=[-(dL[j]+c[15]*math.fsum(G[i][j] for i in range(N)))/c[5] for j in range(N)]
        J=[[-c[15]*G[i][j]/dt-(b[1][i]+b[2][i])/dt*df[j] for j in range(N)] for i in range(N)]
        matching=[systems[k:k+10] for k in range(0,len(systems),10) if systems[k][1]==b[0][3] and systems[k][3]==branch and systems[k][5]==dt]
        assert len(matching)==1
        sy=matching[0];u1,v1,u2,v2=sy[6:10]
        matrix_error=max(abs(J[i][j]-((c[15]*b[9][j] if i==j and 50<=j<=56 else 0)+u1[i]*v1[j]+u2[i]*v2[j])) for i in range(N) for j in range(N))
        assert matrix_error<1e-10
        columns=[];maxerr=0;maxq=0
        def fs(cc):return ((cc[0]-cc[1])+cc[4])/cc[5]
        for node in range(49,58):
            for eps in ([1e-7,5e-8] if node in [50,51,52] else [1e-7]):
                lo=next(x for x in a if x[0][1]==node and x[0][2]==-eps);hi=next(x for x in a if x[0][1]==node and x[0][2]==eps)
                cm=lo[0][4:28];cp=hi[0][4:28]
                for x in [lo,hi]:
                    assert x[0][27]==Hm and x[3]==b[3] and x[9]==b[9]
                    assert (x[0][7]<x[0][4])==volume and (x[0][22]<Hm)==(overlap>0)
                    assert [i+1 for i,v in enumerate(x[1]) if v>0]==list(range(51,58))
                fd=[((s+u)-(t+v))/(2*eps) for s,u,t,v in zip(hi[1],hi[2],lo[1],lo[2])]
                error=max(abs(fd[i]-G[i][node-1]) for i in range(N));assert error<2e-14
                if node==49:assert all(x==0 for x in fd)
                dLfd=(cp[1]-cm[1])/(2*eps)
                gfd=(cp[18]-cm[18])/(2*eps)
                gpred=g0 if node==50 else (g1 if node==51 else 0.)
                vfd=(cp[3]-cm[3])/(2*eps)
                assert abs(gfd-gpred)<2e-7
                assert abs(vfd-c[17]*gpred)<1e-9
                assert max(abs(u-v) for u,v in zip(hi[3],lo[3]))==0
                qerr=[];bounds=[];stable_errors=[]
                for i in range(N):
                    dq=(hi[5][i]-lo[5][i])/(2*eps)
                    rounding=(abs((hi[1][i]+hi[2][i])/dt*(cp[15]-fs(cp)))+abs((lo[1][i]+lo[2][i])/dt*(cm[15]-fs(cm))))/(2*eps)
                    geometric=abs(dL[node-1]-dLfd)/c[5]*(b[1][i]+b[2][i])/dt
                    bound=rounding+geometric+2e-8
                    qe=abs(dq+J[i][node-1]);assert qe<=bound,(branch,node,i+1,qe,bound)
                    stable_dq=((hi[1][i]+hi[2][i])/dt*fs(cp)-(lo[1][i]+lo[2][i])/dt*fs(cm))/(2*eps)
                    stable_error=abs(stable_dq+J[i][node-1])
                    assert stable_error<=geometric+2e-8,(branch,node,i+1,stable_error,geometric)
                    stable_errors.append(stable_error)
                    qerr.append(qe);bounds.append(bound)
                columns.append(dict(node=node,epsilon=eps,potential_vector_error_amount_per_head=error,exchange_vector_error_rate_per_head=max(qerr),exchange_roundoff_geometry_bound_max=max(bounds),stable_equivalent_exchange_error_rate_per_head=max(stable_errors),gwl_gradient_error=abs(gfd-gpred),available_volume_gradient_error=abs(vfd-c[17]*gpred)))
                maxerr=max(maxerr,error);maxq=max(maxq,max(qerr))
        points.append(dict(branch='V' if volume else 'W',attempt=int(sy[0][0]),iteration=int(b[0][3]),dt=dt,provider_perturbations=24,base_provider_evaluations=2,restore_checks=26,snapshot_bytes=int(receipt[0][1]),cache_bytes=int(receipt[0][2]),max_potential_vector_error=maxerr,max_exchange_vector_error=maxq,actual_macro_J_vs_independent_full_derivative_error=matrix_error,columns=columns))
    # Independently verify every actual corrected linear system, all112 rows.
    maxlinear=0.;count=0
    for k in range(0,len(systems),10):
        hd,a,b,c,rhs,x,u1,v1,u2,v2=systems[k:k+10];assert len(x)==112
        d1=math.fsum(u*v for u,v in zip(v1,x));d2=math.fsum(u*v for u,v in zip(v2,x))
        res=[b[i]*x[i]-rhs[i]+(a[i]*x[i-1] if i else 0)+(c[i]*x[i+1] if i<111 else 0)+u1[i]*d1+u2[i]*d2 for i in range(112)]
        e=max(map(abs,res));assert e<1e-14;maxlinear=max(maxlinear,e);count+=1
    q=dict(opt=opt,points=points,full_actual_linear_systems_checked=count,max_linear_error=maxlinear,parent_exact_texts=names,parent_core_and_packet_exact=True,inactive_parent_is_exact_subsequence=True,scope='two first actual eligible W/V points, selected active columns50..57 plus control49; all112 rows, not all112 independent FD columns')
    save=R/(opt+'_DERIVATIVE_AUDIT.json');save.write_text(json.dumps(q,indent=2)+'\n')
    print(json.dumps(dict(opt=opt,points=[{k:v for k,v in p.items() if k!='columns'} for p in points],linear_count=count,max_linear_error=maxlinear),indent=2))
if __name__=='__main__':audit(sys.argv[1])
