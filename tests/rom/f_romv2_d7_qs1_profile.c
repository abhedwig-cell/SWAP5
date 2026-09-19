#include <math.h>
#include <stdint.h>

static const double TR=0.02, TS=0.427494, ALPHA=0.021659;
static const double NPAR=1.734737, KS=31.225016, ELL=0.98087;
static const int NINT=1024;
static const double DEPTH=160.0;

static double theta_h(double h, int *ok){
    if(!isfinite(h) || !(h<0.0)){*ok=0; return NAN;}
    const double m=1.0-1.0/NPAR;
    const double se=pow(1.0+pow(ALPHA*fabs(h),NPAR),-m);
    const double t=TR+(TS-TR)*se;
    if(!(t>TR && t<TS) || !isfinite(t)){*ok=0; return NAN;}
    return t;
}
static double k_h(double h, int *ok){
    const double m=1.0-1.0/NPAR;
    double t=theta_h(h,ok); if(!*ok) return NAN;
    double se=(t-TR)/(TS-TR);
    double inner=1.0-pow(1.0-pow(se,1.0/m),m);
    double k=KS*pow(se,ELL)*inner*inner;
    if(!(k>0.0) || !isfinite(k)){*ok=0; return NAN;}
    return k;
}
static double dhdy(double h,double q,int *ok){
    double k=k_h(h,ok); if(!*ok) return NAN;
    return q/k-1.0;
}

/* Returns 0 on success. out[0]=storage, out[1]=upper80, out[2]=lower80, out[3]=terminal top h. */
int qs1_integrate(double hb,double q,double *out){
    int ok=1;
    const double dy=DEPTH/(double)NINT;
    double h=hb, s=0.0, lower=0.0, upper=0.0;
    for(int j=0;j<NINT;j++){
        double k1h=dhdy(h,q,&ok); if(!ok) return 1;
        double k1s=theta_h(h,&ok); if(!ok) return 2;
        double h2=h+0.5*dy*k1h;
        double k2h=dhdy(h2,q,&ok); if(!ok) return 3;
        double k2s=theta_h(h2,&ok); if(!ok) return 4;
        double h3=h+0.5*dy*k2h;
        double k3h=dhdy(h3,q,&ok); if(!ok) return 5;
        double k3s=theta_h(h3,&ok); if(!ok) return 6;
        double h4=h+dy*k3h;
        double k4h=dhdy(h4,q,&ok); if(!ok) return 7;
        double k4s=theta_h(h4,&ok); if(!ok) return 8;
        h += (dy/6.0)*(k1h+2.0*k2h+2.0*k3h+k4h);
        double ds=(dy/6.0)*(k1s+2.0*k2s+2.0*k3s+k4s);
        s += ds;
        if(j<NINT/2) lower += ds; else upper += ds;
        if(!isfinite(h) || !(h<0.0)) return 9;
    }
    out[0]=s; out[1]=upper; out[2]=lower; out[3]=h;
    return 0;
}
