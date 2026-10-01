program test_ppa_wu05a9_top_input
  use, intrinsic :: iso_fortran_env, only: real64, error_unit
  use mod_ppa_wu05a5_multi_domain_process, only: macropore_geometry_config_t, macropore_geometry_result_t, &
       evaluate_macropore_geometry
  use mod_fmr_macropore_top_input, only: fmr_macropore_top_input_forcing_t, prepare_fmr_macropore_top_input
  implicit none

  type(macropore_geometry_config_t) :: config
  type(macropore_geometry_result_t) :: geometry
  type(fmr_macropore_top_input_forcing_t) :: forcing
  real(real64), allocatable :: vertical(:), lateral(:)
  real(real64) :: dynamic(2)
  logical :: ok

  config%num_domains=2
  config%num_nodes=2
  config%top_node=1
  allocate(config%static_volume_cp(2),config%domain_fraction(2,2), &
       config%potential_bottom_domain(2),config%dz(2),config%characteristic_diameter(2))
  config%static_volume_cp=[0.40_real64,0.40_real64]
  config%domain_fraction(:,1)=[0.25_real64,0.75_real64]
  config%domain_fraction(:,2)=[0.25_real64,0.75_real64]
  config%potential_bottom_domain=[2,2]
  config%dz=[2.0_real64,2.0_real64]
  config%characteristic_diameter=[4.0_real64,4.0_real64]
  dynamic=[0.20_real64,0.0_real64]

  call evaluate_macropore_geometry(config,dynamic,geometry)
  call require(geometry%valid,'geometry valid')

  forcing%supplied=.true.
  forcing%net_rain_rate_cm_per_day=2.0_real64
  forcing%net_irrigation_rate_cm_per_day=1.0_real64
  forcing%melt_rate_cm_per_day=0.5_real64
  forcing%lateral_overland_rate_cm_per_day=0.4_real64

  call prepare_fmr_macropore_top_input(forcing,config,geometry,0.1_real64,vertical,lateral,ok)
  call require(ok,'source-faithful forcing prepared')
  call require(abs(vertical(1)-0.02625_real64)<=1.0e-14_real64,'domain1 vertical')
  call require(abs(vertical(2)-0.07875_real64)<=1.0e-14_real64,'domain2 vertical')
  call require(abs(lateral(1)-0.010_real64)<=1.0e-14_real64,'domain1 lateral')
  call require(abs(lateral(2)-0.030_real64)<=1.0e-14_real64,'domain2 lateral')
  call require(abs(sum(vertical)-0.105_real64)<=1.0e-14_real64,'vertical source identity')
  call require(abs(sum(lateral)-0.040_real64)<=1.0e-14_real64,'lateral source identity')

  forcing=fmr_macropore_top_input_forcing_t()
  call prepare_fmr_macropore_top_input(forcing,config,geometry,0.1_real64,vertical,lateral,ok)
  call require(ok,'A8 zero-forcing preservation')
  call require(all(vertical==0.0_real64) .and. all(lateral==0.0_real64),'zero forcing remains zero')

  forcing%supplied=.false.
  forcing%net_rain_rate_cm_per_day=1.0_real64
  call require(.not.forcing%valid(),'unsupplied nonzero fails closed')

  forcing=fmr_macropore_top_input_forcing_t()
  forcing%supplied=.true.
  forcing%net_rain_rate_cm_per_day=-1.0_real64
  call require(.not.forcing%valid(),'negative rain fails closed')

  forcing=fmr_macropore_top_input_forcing_t()
  forcing%supplied=.true.
  forcing%net_rain_rate_cm_per_day=1.0_real64
  config%top_node=2
  call prepare_fmr_macropore_top_input(forcing,config,geometry,0.1_real64,vertical,lateral,ok)
  call require(.not.ok,'covering-layer route fails closed')

  print '(a)', 'PPA_WU05A9_TOP_INPUT=PASS'

contains

  subroutine require(condition,label)
    logical,intent(in)::condition
    character(len=*),intent(in)::label
    if(.not.condition)then
      write(error_unit,'(a,1x,a)') 'PPA_WU05A9_TOP_INPUT_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_ppa_wu05a9_top_input
