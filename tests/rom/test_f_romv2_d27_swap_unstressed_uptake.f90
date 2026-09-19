program test_f_romv2_d27_swap_unstressed_uptake
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use MOD_grid, only: numnod
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t, fmr_new_b110_committed_state
  use mod_root_water_uptake_process, only: root_water_uptake_parameters_t, root_water_uptake_flux_result_t, &
       root_water_uptake_diagnostics_t, ROOT_UPTAKE_OK
  use mod_fmr_root_uptake_process_binding, only: fmr_root_uptake_crop_input_t, &
       fmr_root_uptake_binding_diagnostics_t, fmr_evaluate_committed_root_uptake, FMR_ROOT_UPTAKE_BINDING_OK
  implicit none

  real(real64), parameter :: H_WET=-29.793709016906483_real64
  real(real64), parameter :: THETA_WET=0.3663699_real64
  real(real64), parameter :: PTRA=0.4_real64
  real(real64), parameter :: DT_DAY=10.0_real64/86400.0_real64
  real(real64), parameter :: TOL=512.0_real64*epsilon(1.0_real64)

  type(kernel_committed_state_t) :: committed
  type(fmr_b110_physical_state_t) :: physical
  type(root_water_uptake_parameters_t) :: params
  type(fmr_root_uptake_crop_input_t) :: crop
  type(root_water_uptake_flux_result_t) :: flux
  type(root_water_uptake_diagnostics_t) :: proc
  type(fmr_root_uptake_binding_diagnostics_t) :: bind
  real(real64) :: expected(3), uptake_depth, sink_depth_sum
  logical :: ok

  call require(numnod==16,'D27 requires R16 16-node geometry')

  physical%active_nodes=numnod
  allocate(physical%pressure_head(numnod),physical%water_content(numnod))
  physical%pressure_head=H_WET
  physical%water_content=THETA_WET
  physical%ponding_depth=0.0_real64
  physical%groundwater_level=-2.0_real64
  call fmr_new_b110_committed_state(committed,270001_int64,physical,0.0_real64,ok)
  call require(ok,'committed wet state initialization')

  params%active_nodes=numnod
  params%hlim3l=-800.0_real64
  params%hlim3h=-400.0_real64
  params%hlim4=-16000.0_real64
  params%adcrl=0.1_real64
  params%adcrh=0.5_real64

  crop%crop_emerged=.true.
  crop%potential_transpiration=PTRA
  crop%rooted_nodes=3
  allocate(crop%cumulative_root_fraction(4))
  crop%cumulative_root_fraction=[0.0_real64,0.1_real64,0.55_real64,1.0_real64]

  call fmr_evaluate_committed_root_uptake(committed,params,crop,flux,proc,bind)

  call require(bind%status==FMR_ROOT_UPTAKE_BINDING_OK,'root binding status')
  call require(proc%status==ROOT_UPTAKE_OK.and.proc%evaluated,'root process status')
  call require(allocated(flux%root_extraction_sink),'sink allocation')
  call require(size(flux%root_extraction_sink)==numnod,'sink size')
  call require(all(ieee_is_finite(flux%root_extraction_sink)).and.all(flux%root_extraction_sink>=0.0_real64), &
       'finite nonnegative sink')

  expected=[0.04_real64,0.18_real64,0.18_real64]
  call require(all_close_vec(flux%root_extraction_sink(1:3),expected),'rooted sink rate identity')
  call require(all_close(flux%root_extraction_sink(4:numnod),0.0_real64),'unrooted sink zero')
  call require(close(flux%actual_uptake_total,PTRA),'actual uptake equals potential')
  call require(close(sum(flux%root_extraction_sink),PTRA),'sink sum equals potential')
  call require(close(proc%critical_pressure_head,-500.0_real64),'critical hlim3 identity')
  call require(H_WET>proc%critical_pressure_head,'wet state is outside drought stress')

  uptake_depth=flux%actual_uptake_total*DT_DAY
  sink_depth_sum=sum(flux%root_extraction_sink)*DT_DAY
  call require(close(uptake_depth,sink_depth_sum),'integrated sink depth identity')

  write(*,'(*(g0))') 'F_ROMV2_D27_SWAP|STATUS=PASS|N=',numnod, &
       '|H_CM=',H_WET,'|THETA=',THETA_WET,'|HLIM3_CM=',proc%critical_pressure_head, &
       '|PTRA_CM_PER_DAY=',PTRA,'|ACTUAL_UPTAKE_CM_PER_DAY=',flux%actual_uptake_total, &
       '|SINK1=',flux%root_extraction_sink(1),'|SINK2=',flux%root_extraction_sink(2), &
       '|SINK3=',flux%root_extraction_sink(3),'|SINK_SUM=',sum(flux%root_extraction_sink), &
       '|DT_DAY=',DT_DAY,'|UPTAKE_DEPTH_CM=',uptake_depth,'|SINK_DEPTH_SUM_CM=',sink_depth_sum
  write(*,'(a)') 'F_ROMV2_D27_SWAP_UPTAKE=PASS'

contains

  pure logical function close(a,b) result(equal)
    real(real64),intent(in) :: a,b
    real(real64) :: scale
    scale=max(1.0_real64,abs(a),abs(b))
    equal=abs(a-b)<=TOL*scale
  end function close

  pure logical function all_close(a,b) result(equal)
    real(real64),intent(in) :: a(:)
    real(real64),intent(in) :: b
    equal=all(abs(a-b)<=TOL*max(1.0_real64,maxval(abs(a)),abs(b)))
  end function all_close

  pure logical function all_close_vec(a,b) result(equal)
    real(real64),intent(in) :: a(:),b(:)
    equal=size(a)==size(b)
    if(equal) equal=all(abs(a-b)<=TOL*max(1.0_real64,maxval(abs(a)),maxval(abs(b))))
  end function all_close_vec

  subroutine require(condition,message)
    logical,intent(in) :: condition
    character(len=*),intent(in) :: message
    if(.not.condition)then
      write(*,'(a,1x,a)') 'F_ROMV2_D27_SWAP_FAIL',trim(message)
      error stop 1
    end if
  end subroutine require

end program test_f_romv2_d27_swap_unstressed_uptake
