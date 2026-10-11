program test_fvq_int12d_gash_independent
 use, intrinsic::iso_fortran_env,only:real64
 use mod_gash_interception_process
 implicit none
 type(gash_source_window_input_t)::x
 type(gash_source_window_result_t)::r
 integer::s
 real(real64)::cg,sc,p,e,ps,oracle
 call tab(x%free_throughfall,[0d0,10d0],[0.2d0,0.4d0]);call tab(x%stemflow,[0d0,10d0],[0.1d0,0.1d0])
 call tab(x%canopy_storage_cm,[0d0,10d0],[0.14d0,0.21d0]);call tab(x%average_precipitation,[0d0,10d0],[2d0,4d0])
 call tab(x%average_evaporation,[0d0,10d0],[0.2d0,0.4d0]);x%source_time=5d0
 cg=1d0-0.3d0-0.1d0;sc=0.175d0/cg;p=3d0;e=0.3d0/cg;ps=-p*sc/e*log(1d0-e/p)
 x%gross_rain_cm=2d0;call evaluate_gash_source_window(x,r,s);oracle=cg*(ps+e*cg/p*(2d0-ps))
 call req(s==GASH_OK.and.abs(r%interception_cm-oracle)<1d-14,'independent saturated oracle')
 call req(abs(r%saturation_precipitation_cm-ps)<1d-14,'psat oracle')
 x%source_time=-1d0;x%gross_rain_cm=0.05d0;call evaluate_gash_source_window(x,r,s);call req(s==GASH_OK,'left clamp')
 call req(abs(r%canopy_fraction-0.7d0)<1d-14,'left AFGEN clamp')
 x%source_time=11d0;call evaluate_gash_source_window(x,r,s);call req(s==GASH_OK,'right clamp');call req(abs(r%canopy_fraction-0.5d0)<1d-14,'right AFGEN clamp')
 print *,'F-VQ INT12-D INDEPENDENT GASH ORACLE PASS'
contains
 subroutine tab(t,a,b);type(gash_table_t),intent(out)::t;real(real64),intent(in)::a(:),b(:);allocate(t%time(size(a)),t%value(size(b)));t%time=a;t%value=b;end subroutine
 subroutine req(q,m);logical,intent(in)::q;character(*),intent(in)::m;if(.not.q)then;print *,m;error stop 1;end if;end subroutine
end program
