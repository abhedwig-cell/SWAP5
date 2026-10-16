program signed_divdra_contract
  use iso_fortran_env, only: real64
  use ieee_arithmetic, only: ieee_value,ieee_quiet_nan,ieee_positive_inf,ieee_negative_inf
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_drainage_spatial_distribution
  use mod_fmr_divdra_runtime_binding
  use mod_frost_divdra_drainage_effect, only: frost_divdra_parameters_t,frost_divdra_result_t, &
       compose_single_level_signed_frost_divdra,FROST_DIVDRA_OK
  implicit none
  type(drainage_distribution_parameters_t) :: p
  type(process_hydraulic_view_t) :: h
  type(drainage_node_transfer_t) :: pos,neg
  type(drainage_distribution_diagnostics_t) :: pd,nd
  type(fmr_divdra_binding_diagnostics_t) :: bd
  type(frost_divdra_parameters_t) :: fp
  type(frost_divdra_result_t) :: fr
  real(real64),allocatable :: q(:,:)
  real(real64) :: invalid(5),scalar,expected(4),before(4)
  integer :: i,j
  p%active_nodes=4
  p%dz=[10._real64,10._real64,10._real64,10._real64]
  p%zbotcp=[-10._real64,-20._real64,-30._real64,-40._real64]
  p%saturated_conductivity=[1._real64,1._real64,1._real64,1._real64]
  p%horizontal_anisotropy_factor=[1._real64,1._real64,1._real64,1._real64]
  p%drain_spacing=80._real64
  h%active_nodes=4;h%pressure_head=[-1._real64,-1._real64,-1._real64,-1._real64]
  h%water_content=[.3_real64,.3_real64,.3_real64,.3_real64];h%groundwater_level=-15._real64
  ! Independent geometry: uniform K gives 20 cm discharge depth below GWL.
  ! Wet overlaps are 0,5,10,5 cm, hence these literal weights.
  expected=[0._real64,.25_real64,.5_real64,.25_real64]
  do i=-1,1
    scalar=real(i,real64)*.75_real64
    call distribute_single_level_signed_divdra(p,h,scalar,neg,nd)
    call require(nd%status==DRAIN_DIST_OK,'literal oracle status')
    call require(maxval(abs(neg%soil_to_drain_rate-scalar*expected))<1.e-14_real64,'literal overlap oracle')
    call fmr_bind_single_level_signed_divdra(p,h,scalar,q,bd)
    call require(bd%published.and.bd%status==FMR_DIVDRA_BIND_OK,'binder')
    call require(all(q(1,:)==neg%soil_to_drain_rate),'process/binder identity')
    call require(abs(sum(q)-scalar)<1.e-14_real64,'scalar exactly once nodal sum')
    deallocate(q)
  end do
  ! Compare the new orientation adapter with the already admitted B19 warm,
  ! unmodified conductivity partition on heterogeneous profiles and wet fronts.
  do j=1,3
    h%groundwater_level=-real(5*j,real64)
    p%saturated_conductivity=[1._real64,2._real64,3._real64,4._real64]
    p%horizontal_anisotropy_factor=[1._real64,1.25_real64,.75_real64,2._real64]
    before=p%saturated_conductivity
    fp%distribution=p;fp%drain_bottom_cm=-30._real64
    do i=-1,1
      scalar=real(i,real64)*.125_real64
      call distribute_single_level_signed_divdra(p,h,scalar,neg,nd)
      call compose_single_level_signed_frost_divdra(fp,h,[1._real64,1._real64,1._real64,1._real64], &
           -1,0._real64,h%water_content,[.4_real64,.4_real64,.4_real64,.4_real64],scalar,0._real64,fr)
      call require(nd%status==DRAIN_DIST_OK.and.fr%status==FROST_DIVDRA_OK,'admitted donor domain')
      call require(maxval(abs(neg%soil_to_drain_rate-fr%final_nodal_sink))<1.e-14_real64,'B19 warm donor')
      call require(all(p%saturated_conductivity==before),'immutable parameters')
    end do
    call distribute_single_level_positive_divdra(p,h,.125_real64,pos,pd)
    call distribute_single_level_signed_divdra(p,h,-.125_real64,neg,nd)
    call require(all(pos%soil_to_drain_rate==-neg%soil_to_drain_rate),'positive bitwise sign preservation')
  end do
  call fmr_bind_single_level_positive_divdra(p,h,-.75_real64,q,bd)
  call require(bd%status==FMR_DIVDRA_BIND_PROCESS_REJECTED.and..not.allocated(q),'positive-only remains closed')
  invalid=[1.e-10_real64,-1.e-10_real64,ieee_value(0._real64,ieee_quiet_nan), &
       ieee_value(0._real64,ieee_positive_inf),ieee_value(0._real64,ieee_negative_inf)]
  do i=1,size(invalid)
    call fmr_bind_single_level_signed_divdra(p,h,invalid(i),q,bd)
    call require(bd%status==FMR_DIVDRA_BIND_PROCESS_REJECTED.and..not.allocated(q),'invalid unpublished')
  end do
  allocate(q(1,4));q=99._real64
  call fmr_bind_single_level_signed_divdra(p,h,-.75_real64,q,bd)
  call require(bd%status==FMR_DIVDRA_BIND_TARGET_ALREADY_BOUND.and.all(q==99._real64),'target owner guard')
  print '(a)','SIGNED_DIVDRA_LITERAL_B19_SIGNS_NEGATIVES_NONMUTATION=PASS'
contains
  subroutine require(ok,label)
    logical,intent(in)::ok
    character(*),intent(in)::label
    if(.not.ok)then
      print *,label
      error stop 1
    end if
  end subroutine
end program
