program test_mc_irr01_allocation_guards
  use, intrinsic :: iso_fortran_env, only: int64,real64
  use, intrinsic :: ieee_arithmetic, only: ieee_value,ieee_quiet_nan
  use mod_fmr_irrigation_allocation_binding
  use mod_irrigation_process, only: IRRIGATION_EVENT_SCHEDULED
  implicit none
  type(fmr_irrigation_allocation_t) :: delivery
  type(fmr_allocated_irrigation_state_t) :: state,restored,before
  type(fmr_allocated_irrigation_restart_t) :: record,bad
  integer :: status
  delivery%source_id=41_int64;delivery%revision=7_int64
  delivery%valid_t0=0.0_real64;delivery%valid_t1=1.0_real64;delivery%fraction=.5_real64
  call require(delivery%valid(.375_real64),'valid provider')
  call require(.not.delivery%valid(1.0_real64),'exclusive window end')
  delivery%fraction=ieee_value(0.0_real64,ieee_quiet_nan)
  call require(.not.delivery%valid(.375_real64),'nonfinite fraction')
  delivery%fraction=.5_real64;delivery%revision=-1_int64
  call require(.not.delivery%valid(.375_real64),'missing revision')
  delivery%revision=7_int64;delivery%source_id=0_int64
  call require(.not.delivery%valid(.375_real64),'missing provider')
  delivery%source_id=41_int64
  state%management%event%active_event=.true.
  state%management%event%active_event_origin=IRRIGATION_EVENT_SCHEDULED
  state%management%event%active_event_index=0
  state%management%event%active_event_start=.375_real64
  state%management%event%active_event_end=.385_real64
  state%management%event%active_event_rate_cm_per_day=48.0_real64
  state%receipt%present=.true.;state%receipt%active_event=.true.
  state%receipt%allocation=delivery;state%receipt%selection_time=.375_real64
  state%receipt%event_origin=IRRIGATION_EVENT_SCHEDULED;state%receipt%event_index=0
  state%receipt%event_start=.375_real64;state%receipt%event_end=.385_real64;state%receipt%event_rate=48.0_real64
  call fmr_export_allocated_irrigation_restart(state,record,status)
  call require(status==FMR_IRR_ALLOCATION_OK,'valid receipt export')
  call fmr_restore_allocated_irrigation_restart(record,restored,status)
  call require(status==FMR_IRR_ALLOCATION_OK,'valid receipt restore')
  before=restored;bad=record;bad%receipt%event_end=.395_real64
  call fmr_restore_allocated_irrigation_restart(bad,restored,status)
  call require(status/=FMR_IRR_ALLOCATION_OK,'mismatching event identity')
  call unchanged()
  bad=record;bad%receipt%allocation%fraction=1.5_real64
  call fmr_restore_allocated_irrigation_restart(bad,restored,status)
  call require(status/=FMR_IRR_ALLOCATION_OK,'corrupt provider fraction')
  call unchanged()
  bad=record;bad%schema=2
  call fmr_restore_allocated_irrigation_restart(bad,restored,status)
  call require(status/=FMR_IRR_ALLOCATION_OK,'wrong schema')
  call unchanged()
  print '(A)','MC_IRR01_ALLOCATION_GUARDS=PASS'
contains
  subroutine unchanged()
    call require(restored%receipt%allocation%source_id==before%receipt%allocation%source_id,'failed restore provider preserved')
    call require(restored%receipt%event_end==before%receipt%event_end,'failed restore event preserved')
    call require(restored%management%event%active_event_end==before%management%event%active_event_end,'failed restore management preserved')
  end subroutine
  subroutine require(ok,why)
    logical,intent(in)::ok
    character(*),intent(in)::why
    if(.not.ok)then
      print '(A)','MC_IRR01_ALLOCATION_GUARDS_FAIL '//why
      error stop 1
    end if
  end subroutine
end program
