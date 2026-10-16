program test_f_mig431_int12_d_gash
 use, intrinsic::iso_fortran_env,only:real64
 use mod_gash_interception_process
 implicit none
 type(gash_source_window_input_t)::x
 type(gash_source_window_result_t)::r
 integer::s
 call table(x%free_throughfall,[0d0,10d0],[0.2d0,0.4d0])
 call table(x%stemflow,[0d0,10d0],[0.1d0,0.1d0])
 call table(x%canopy_storage_cm,[0d0,10d0],[0.14d0,0.21d0])
 call table(x%average_precipitation,[0d0,10d0],[2d0,4d0])
 call table(x%average_evaporation,[0d0,10d0],[0.2d0,0.4d0])
 x%source_time=5d0;x%gross_rain_cm=0.1d0
 call evaluate_gash_source_window(x,r,s);call req(s==GASH_OK,'small');call req(abs(r%interception_cm-r%canopy_fraction*0.1d0)<1d-14,'small formula')
 x%gross_rain_cm=2d0
 call evaluate_gash_source_window(x,r,s);call req(s==GASH_OK,'large');call req(r%saturation_precipitation_cm>0d0.and.r%interception_cm>0d0,'large formula')
 x%gross_rain_cm=0.1d0;x%surface_irrigation_cm=0.2d0;x%surface_irrigation_is_intercepted=.true.
 call evaluate_gash_source_window(x,r,s);call req(abs(r%interception_cm-r%canopy_fraction*0.3d0)<1d-14,'irrigation rpd')
 x%surface_irrigation_is_intercepted=.false.
 call evaluate_gash_source_window(x,r,s);call req(abs(r%interception_cm-r%canopy_fraction*0.1d0)<1d-14,'irrigation excluded')
 print *,'F-MIG431-INT12-D GASH PROCESS PASS'
contains
 subroutine table(t,a,b);type(gash_table_t),intent(out)::t;real(real64),intent(in)::a(:),b(:);allocate(t%time(size(a)),t%value(size(b)));t%time=a;t%value=b;end subroutine
 subroutine req(ok,m);logical,intent(in)::ok;character(*),intent(in)::m;if(.not.ok)then;print *,m;error stop 1;end if;end subroutine
end program
