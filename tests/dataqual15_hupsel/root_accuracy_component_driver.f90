program root_accuracy_component_contract
 use iso_fortran_env,only:real64
 use ieee_arithmetic
 use mod_root_micro_matric_flux_table
 use mod_root_micro_de_willigen_process
 use mod_bartholomeus_waterfilm
 use mod_bartholomeus_waterfilm_independent
 use frozen_legacy_film,only:legacy_film
 use frozen_refined_film,only:refined_film
 use capped_current_film,only:capped_film
 implicit none
 type(micro_matric_flux_table_t)::tables(2)
 type(micro_de_willigen_parameters_t)::p
 type(micro_de_willigen_result_t)::r
 type(BartholomeusWaterfilmMvgInput)::film,saved
 real(real64)::samples(MICRO_TABLE_POINTS),heads(2),dz(2),density(2),stress(2),potential(2),pressure,first_pressure,first_sink(2)
 real(real64)::a,b,c,d,x(7),bad(2),value
 character(16)::mode
 logical::precise,ok,oa,ob,oc,od
 integer::i,j,k,code,u,io,n
 call get_command_argument(1,mode)
 if(trim(mode)/='legacy'.and.trim(mode)/='refined')error stop 'unknown component profile'
 precise=trim(mode)=='refined'
 samples=.01d0
 do i=1,2
  call build_micro_matric_flux_table(samples,.01d0,.01d0,tables(i),code)
  if(code/=MICRO_TABLE_OK)error stop 'table'
 end do
 p%root_radius_cm=.01d0;p%root_conductance_cm_per_day=.001d0
 p%stem_a0_per_day=.01d0;p%stem_a1_per_cm=.001d0;p%half_leaf_pressure_cm=10000d0;p%campbell_exponent=2d0
 heads=[-100d0,-200d0];dz=10d0;density=.5d0;stress=1d0;potential=[.006459780392d0,.1d0]
 do j=1,2
  do k=1,2
   p%residual_tolerance_cm_per_day=1d-4
   if(k==2)p%residual_tolerance_cm_per_day=1d-3
   call evaluate_micro_de_willigen(p,heads,dz,density,stress,2,potential(j),tables,r,precise_pressure_search=precise)
   if(r%status/=MICRO_DW_OK)error stop 'MICRO result'
   if(r%actual_uptake_total>potential(j).or.any(r%root_extraction_sink<0d0))error stop 'MICRO certificate'
   if(k==1)then
    first_pressure=r%root_pressure_cm;first_sink=r%root_extraction_sink
   else if(precise)then
    if(r%root_pressure_cm/=first_pressure.or.any(r%root_extraction_sink/=first_sink))error stop 'search depends on flux certificate'
   end if
   write(*,'(a,2(1x,i0),4(1x,es25.17e3))')'MICRO',j,k,r%root_pressure_cm,r%actual_uptake_total,r%root_extraction_sink
  end do
 end do
 open(newunit=u,file='film.dat',status='old');n=0
 do
  read(u,*,iostat=io)x
  if(io<0)exit
  if(io/=0)error stop 'film fixture'
  n=n+1;pressure=x(1);film=BartholomeusWaterfilmMvgInput(x(2),x(3),x(4),x(5),x(6),x(7))
  a=bartholomeus_waterfilm_mvg_independent(pressure,film,oa)
  b=legacy_film(pressure,film,ob)
  c=bartholomeus_waterfilm_mvg_independent(pressure,film,oc,require_two_refinements=.true.)
  d=refined_film(pressure,film,od)
  if(.not.(oa.and.ob.and.oc.and.od))error stop 'film validity'
  if(a/=b.or.c/=d)error stop 'public film differs from frozen algorithm'
  write(*,'(a,1x,i0,2(1x,es25.17e3))')'FILM',n,a,c
 end do
 close(u)
 if(n/=64)error stop 'film sample count'
 saved=film;bad=[ieee_value(0d0,ieee_quiet_nan),ieee_value(0d0,ieee_positive_inf)]
 do i=1,2
  value=bartholomeus_waterfilm_mvg_independent(bad(i),film,ok,require_two_refinements=.true.)
  if(ok)error stop 'nonfinite head accepted'
  film%alpha_per_pa=bad(i)
  value=bartholomeus_waterfilm_mvg_independent(pressure,film,ok,require_two_refinements=.true.)
  if(ok)error stop 'nonfinite parameter accepted'
  film=saved
 end do
 value=capped_film(pressure,film,ok,require_two_refinements=.true.)
 if(ok)error stop 'unconverged film accepted at cap'
 print '(a)','ROOT_PRESSURE_CERTIFICATE_AND_FROZEN_FILM_API_CONTRACT_PASS'
end program
