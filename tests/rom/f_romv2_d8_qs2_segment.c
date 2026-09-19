#include <math.h>
static const double TR=0.02,TS=0.427494,ALPHA=0.021659;
static const double NPAR=1.734737,KS=31.225016,ELL=0.98087;
static const int NINT=512;
static const double DEPTH=80.0;

static int eval_h(double h,double *theta,double *k){
    if(!isfinite(h)||!(h<0.0)) return 1;
    const double m=1.0-1.0/NPAR;
    const double se=pow(1.0+pow(ALPHA*fabs(h),NPAR),-m);
    const double t=TR+(TS-TR)*se;
    if(!(t>TR&&t<TS)||!isfinite(t)) return 2;
    const double inner=1.0-pow(1.0-pow(se,1.0/m),m);
    const double kval=KS*pow(se,ELL)*inner*inner;
    if(!(kval>0.0)||!isfinite(kval)) return 3;
    *theta=t;*k=kval;return 0;
}

/* 80-cm steady segment, y positive upward from the segment bottom.
   out[0]=integrated storage [cm], out[1]=top pressure head [cm]. */
int qs2_integrate_segment(double hbottom,double q,double *out){
    const double dy=DEPTH/(double)NINT;
    double h=hbottom,storage=0.0;
    for(int j=0;j<NINT;j++){
        double t1,k1,t2,k2,t3,k3,t4,k4;
        if(eval_h(h,&t1,&k1)) return 1;
        const double r1=q/k1-1.0;
        const double h2=h+0.5*dy*r1;
        if(eval_h(h2,&t2,&k2)) return 2;
        const double r2=q/k2-1.0;
        const double h3=h+0.5*dy*r2;
        if(eval_h(h3,&t3,&k3)) return 3;
        const double r3=q/k3-1.0;
        const double h4=h+dy*r3;
        if(eval_h(h4,&t4,&k4)) return 4;
        const double r4=q/k4-1.0;
        h+=(dy/6.0)*(r1+2.0*r2+2.0*r3+r4);
        storage+=(dy/6.0)*(t1+2.0*t2+2.0*t3+t4);
        if(!isfinite(h)||!(h<0.0)) return 5;
    }
    out[0]=storage;out[1]=h;return 0;
}
