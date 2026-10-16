program oxygen_source_contract
  use iso_fortran_env,only:real64
  use mod_root_water_uptake_process
  use mod_process_hydraulic_view,only:process_hydraulic_view_t
  implicit none
  type(root_water_uptake_parameters_t)::p
  type(root_water_uptake_request_t)::q
  type(root_water_uptake_flux_result_t)::f
  type(root_water_uptake_diagnostics_t)::d
  type(process_hydraulic_view_t)::h
  real(real64)::expected(4),limits(8),heads(12),demands(6),before(4)
  integer::i,j,k,layer,count
  interface
    subroutine b111_root_sink(n,noddrz,upper,enabled,h,ptra,cumdens_top,limits,qrot)
      import real64
      integer,intent(in)::n,noddrz,upper
      logical,intent(in)::enabled
      real(real64),intent(in)::h(n),ptra,cumdens_top(noddrz+1),limits(8)
      real(real64),intent(out)::qrot(n)
    end subroutine
  end interface
  p%active_nodes=4;p%hlim3l=-500;p%hlim3h=-800;p%hlim4=-16000
  p%adcrl=.1_real64;p%adcrh=.5_real64;p%empirical_oxygen_enabled=.true.
  p%hlim1=-10;p%hlim2u=-50;p%hlim2l=-100
  limits=[p%hlim3l,p%hlim3h,p%hlim4,p%adcrl,p%adcrh,p%hlim1,p%hlim2u,p%hlim2l]
  heads=[-16001._real64,-16000._real64,-800._real64,-500._real64,-101._real64,-100._real64, &
    -75._real64,-50._real64,-30._real64,-10._real64,-5._real64,0._real64]
  demands=[0._real64,1.e-11_real64,1.e-10_real64,.1_real64,.5_real64,1._real64]
  h%active_nodes=4;h%pressure_head=[0._real64,0._real64,0._real64,0._real64]
  q%rooted_nodes=4;q%cumulative_root_fraction=[0._real64,.1_real64,.3_real64,.6_real64,1._real64]
  count=0
  do layer=0,4
    p%upper_layer_bottom_node=layer
    do i=1,size(heads)
      do j=1,size(demands)
        h%pressure_head=[heads(i),heads(mod(i,12)+1),heads(mod(i+2,12)+1),heads(mod(i+5,12)+1)]
        before=h%pressure_head;q%potential_transpiration=demands(j)
        call b111_root_sink(4,4,layer,.true.,h%pressure_head,q%potential_transpiration,q%cumulative_root_fraction,limits,expected)
        call evaluate_macro_feddes_drought_uptake(p,h,q,f,d)
        if(d%status/=ROOT_UPTAKE_OK)error stop 'valid source case'
        if(maxval(abs(expected-f%root_extraction_sink))>1.e-14_real64)error stop 'literal source sink'
        if(abs(sum(f%root_extraction_sink)+d%drought_reduction_total+d%oxygen_reduction_total- &
          d%potential_uptake_total)>1.e-14_real64)error stop 'one stress sink accounting'
        if(any(before/=h%pressure_head))error stop 'input mutation'
        count=count+1
      end do
    end do
  end do
  print '(a,i0)','OXYGEN_LITERAL_SOURCE_CASES=',count
  print '(a)','CROP_CYCLE_OXYGEN_LITERAL_CONTRACT=PASS'
end program
