program test_root_salinity_response
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_value,ieee_quiet_nan
  use mod_root_salinity_response
  implicit none
  real(real64),parameter :: threshold=5.0_real64,slope=0.2_real64,tol=2.0e-14_real64
  real(real64) :: alpha(6)
  real(real64),allocatable :: cml(:),sink(:),node_loss(:),alpha_view(:)
  real(real64) :: total_loss,potential(2)
  integer :: status

  call evaluate_maas_hoffman_response([0.0_real64,threshold,threshold+1.0e-8_real64, &
       threshold+1.25_real64,threshold+4.0_real64,threshold+20.0_real64],threshold,slope,alpha,status)
  call req(status==SALINITY_OK,'valid nodewise response')
  call req(maxval(abs(alpha-[1.0_real64,1.0_real64,1.0_real64-2.0e-9_real64,0.75_real64,0.2_real64,0.0_real64]))<tol, &
       'no, incipient, partial, strong and saturated stress oracles')
  call req(all(alpha>=0.0_real64).and.all(alpha<=1.0_real64),'response bounds')
  call req(all(alpha(2:)<=alpha(:5)),'monotone concentration response')
  call evaluate_maas_hoffman_response([threshold+1.25_real64,threshold+1.25_real64, &
       threshold+1.25_real64,threshold+1.25_real64],threshold,slope,alpha(1:4),status)
  call req(status==SALINITY_OK.and.maxval(abs(alpha(1:4)-0.75_real64))<tol, &
       'uniform concentration is independent of node count')
  call evaluate_maas_hoffman_response([0.0_real64,100.0_real64],threshold,0.0_real64,alpha(1:2),status)
  call req(status==SALINITY_OK.and.maxval(abs(alpha(1:2)-1.0_real64))<tol,'zero slope disables response')
  call evaluate_maas_hoffman_response([threshold,threshold+5.0_real64],threshold,slope,alpha(1:2),status)
  call req(status==SALINITY_OK.and.maxval(abs(alpha(1:2)-[1.0_real64,0.0_real64]))<tol,'threshold boundaries')
  call evaluate_maas_hoffman_response([-1.0_real64],threshold,slope,alpha(1:1),status)
  call req(status==SALINITY_INVALID,'negative concentration rejected')
  call evaluate_maas_hoffman_response([ieee_value(0.0_real64,ieee_quiet_nan)],threshold,slope,alpha(1:1),status)
  call req(status==SALINITY_INVALID,'nonfinite concentration rejected')
  call evaluate_maas_hoffman_response([1.0_real64],-1.0_real64,slope,alpha(1:1),status)
  call req(status==SALINITY_INVALID,'negative threshold rejected')
  call evaluate_maas_hoffman_response([1.0_real64],threshold,-slope,alpha(1:1),status)
  call req(status==SALINITY_INVALID,'negative slope rejected')
  call evaluate_maas_hoffman_response([1.0_real64],100.01_real64,slope,alpha(1:1),status)
  call req(status==SALINITY_INVALID,'threshold above B1.11 input range rejected')
  call evaluate_maas_hoffman_response([1.0_real64],threshold,1.01_real64,alpha(1:1),status)
  call req(status==SALINITY_INVALID,'slope above B1.11 input range rejected')
  ! Mass and water are supplied from one trial revision: CML is derived from
  ! mg/cm2 divided by theta*dz, then the exact same alpha scales the sink.
  potential=[0.1_real64,0.2_real64]
  call evaluate_mobile_root_salinity_sink([4.0_real64,20.0_real64],[0.2_real64,0.2_real64], &
       [2.0_real64,2.0_real64],threshold,slope,potential,cml,alpha_view,sink, &
       node_loss,total_loss,status)
  call req(status==SALINITY_OK.and.maxval(abs(cml-[10.0_real64,50.0_real64]))<tol, &
       'same-revision CML is derived from committed mass and matching water')
  call req(maxval(abs(alpha_view-[0.0_real64,0.0_real64]))<tol.and.maxval(abs(sink))<tol, &
       'Maas-Hoffman response scales the root sink')
  call req(maxval(abs(node_loss-[0.1_real64,0.2_real64]))<tol.and.abs(total_loss-0.3_real64)<tol, &
       'nodewise salinity loss closes to one scalar attribution')
  call req(maxval(abs(potential-[0.1_real64,0.2_real64]))<tol,'potential sink input remains value-stable')
  call evaluate_mobile_root_salinity_sink([1.0_real64],[0.0_real64],[2.0_real64],threshold,slope, &
       [0.1_real64],cml,alpha_view,sink,node_loss,total_loss,status)
  call req(status==SALINITY_INVALID,'positive salt inventory in dry water state is rejected')
  print *,'PPA_WU05E_ROOT_SALINITY_RESPONSE=PASS'
contains
  subroutine req(ok,label)
    logical,intent(in) :: ok
    character(*),intent(in) :: label
    if(.not.ok) then
      print *,'FAIL ',label
      error stop 1
    end if
  end subroutine
end program
