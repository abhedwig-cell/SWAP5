module mod_ppa_wu04d_gash_forcing_adapter
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_b110_dynamic_top_boundary_provider, only: b110_dynamic_top_boundary_request_t
  use mod_vonhhbraden_interception, only: vonhhbraden_source_window_t, apportion_vonhhbraden_interception, &
       VONHHBRADEN_AVAILABLE
  implicit none
  private
  integer, parameter, public :: PPA_WU04D_BIND_OK=0, PPA_WU04D_BIND_REJECTED=1
  public :: bind_ppa_wu04d_gash_dynamic_top
contains
  subroutine bind_ppa_wu04d_gash_dynamic_top(base,source,aggregate,rain,irrigation,bound,interception,status)
    type(b110_dynamic_top_boundary_request_t),intent(in)::base
    type(vonhhbraden_source_window_t),intent(in)::source
    real(real64),intent(in)::aggregate,rain,irrigation
    type(b110_dynamic_top_boundary_request_t),intent(out)::bound
    real(real64),intent(out)::interception
    integer,intent(out)::status
    real(real64)::net_rain,net_irrigation
    integer::partition_status
    bound=b110_dynamic_top_boundary_request_t(); interception=0._real64; status=PPA_WU04D_BIND_REJECTED
    call apportion_vonhhbraden_interception(source,aggregate,rain,irrigation,interception,net_rain,net_irrigation,partition_status)
    if(partition_status/=VONHHBRADEN_AVAILABLE) return
    if(net_rain<0._real64 .or. net_irrigation<0._real64) return
    bound=base; bound%precipitation_rate_cm_per_day=net_rain; bound%irrigation_rate_cm_per_day=net_irrigation
    status=PPA_WU04D_BIND_OK
  end subroutine
end module
