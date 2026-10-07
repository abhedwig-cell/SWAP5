program test_swap431_frost_rootdrain
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_frost_drainage_effect, only: frost_drainage_result_t, compose_legacy_normal_frost_drainage, FROST_DRAIN_OK
  use mod_root_water_uptake_process, only: root_water_uptake_flux_result_t
  use mod_root_frost_stress, only: root_frost_config_t, compose_legacy_zero_root_frost, ROOT_FROST_OK
  implicit none
  integer,parameter :: n=4,levels=2
  real(real64) :: temperature(n),theta(n),sat(n),dz(n),factor(n),proposal(levels,n),final_drain(levels,n),loss
  real(real64),allocatable :: root_factor(:)
  type(frost_drainage_result_t) :: drain
  type(root_water_uptake_flux_result_t) :: root_base,root_final
  type(root_frost_config_t) :: root_cfg
  integer :: root_status
  real(real64),parameter :: tol=512.0_real64*epsilon(1.0_real64)

  temperature=[-1._real64,-.5_real64,1._real64,2._real64]
  theta=.2_real64;sat=.45_real64;dz=1._real64
  factor=[.2_real64,.5_real64,1._real64,1._real64]
  proposal=0._real64
  proposal(1,:)=[.01_real64,.02_real64,.03_real64,.04_real64]
  proposal(2,:)=[-.01_real64,-.02_real64,-.01_real64,0._real64]

  root_cfg%active=.true.;root_cfg%rooted_nodes=3
  allocate(root_base%root_extraction_sink(n))
  root_base%root_extraction_sink=[.03_real64,.02_real64,.01_real64,0._real64]
  root_base%actual_uptake_total=sum(root_base%root_extraction_sink)

  call compose_legacy_normal_frost_drainage(.true.,temperature,-2._real64,theta,sat,dz,factor,proposal,final_drain,drain)
  call require(drain%status==FROST_DRAIN_OK.and.drain%available,'frost drainage available')
  call compose_legacy_zero_root_frost(root_cfg,temperature,root_base,root_final,root_factor,loss,root_status)
  call require(root_status==ROOT_FROST_OK,'root frost available')
  call require(all(abs(final_drain-proposal*spread(factor,1,levels))<=tol),'drain owner nodewise frost')
  call require(all(abs(root_final%root_extraction_sink-[0._real64,0._real64,.01_real64,0._real64])<=tol), &
       'root owner empirical zeroing')
  call require(abs(sum(final_drain)-drain%total_rate)<=tol,'drain mass owner')
  call require(abs(sum(root_final%root_extraction_sink)-root_final%actual_uptake_total)<=tol,'root mass owner')
  call require(abs(loss-(root_base%actual_uptake_total-root_final%actual_uptake_total))<=tol,'root loss accounting')

  print '(a)','SW431_FROST_ROOTDRAIN_DRAIN_OWNER=PASS'
  print '(a)','SW431_FROST_ROOTDRAIN_ROOT_OWNER=PASS'
  print '(a)','SW431_FROST_ROOTDRAIN_MASS_SEPARATION=PASS'
  print '(a)','SW431_FROST_ROOTDRAIN=PASS'
contains
  subroutine require(ok,label)
    logical,intent(in)::ok
    character(len=*),intent(in)::label
    if(.not.ok)then
      write(*,'(a,1x,a)')'SW431_FROST_ROOTDRAIN_FAIL',trim(label)
      error stop 431
    end if
  end subroutine
end program
