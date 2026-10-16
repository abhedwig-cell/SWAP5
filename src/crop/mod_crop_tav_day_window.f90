module mod_crop_tav_day_window
  use, intrinsic :: iso_fortran_env, only: int64,real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private
  integer, parameter, public :: TAV_DAY_OK=0,TAV_DAY_INVALID=1,TAV_DAY_MISMATCH=2, &
       TAV_DAY_GAP=3,TAV_DAY_DUPLICATE=4
  type, public :: crop_tav_day_window_t
    private
    integer(int64) :: lineage=0_int64, source=0_int64, next_revision=-1_int64
    real(real64) :: day_start=0.0_real64,day_end=0.0_real64
    real(real64) :: covered=0.0_real64,integral=0.0_real64
    integer :: intervals=0
    logical :: initialized=.false.
  contains
    procedure :: complete => crop_tav_complete
    procedure :: snapshot => crop_tav_snapshot
  end type
  public :: start_crop_tav_day, append_crop_tav_interval_candidate, read_crop_tav_day_candidate
contains
  ! This type only validates caller-declared interval data; it does NOT
  ! certify that weather was the forcing actually used by accepted F-KT trials.
  ! It carries NO publication authority. A meteorological owner must bind
  ! the actual atmosphere_interface:tav before crop events can be committed.
  subroutine start_crop_tav_day(window,lineage,source,revision,day_start,day_end,status)
    type(crop_tav_day_window_t), intent(out) :: window
    integer(int64),intent(in):: lineage,source,revision
    real(real64),intent(in):: day_start,day_end
    integer,intent(out):: status
    window=crop_tav_day_window_t();status=TAV_DAY_INVALID
    if(lineage<=0_int64.or.source<=0_int64.or.revision<0_int64) return
    if(.not.ieee_is_finite(day_start).or..not.ieee_is_finite(day_end)) return
    if(day_end-day_start/=1.0_real64) return
    window%lineage=lineage;window%source=source;window%next_revision=revision
    window%day_start=day_start;window%day_end=day_end;window%covered=day_start
    window%initialized=.true.;status=TAV_DAY_OK
  end subroutine
  subroutine append_crop_tav_interval_candidate(window,lineage,source,origin_revision, &
       interval_start,interval_end,air_temperature,status)
    type(crop_tav_day_window_t),intent(inout)::window
    integer(int64),intent(in)::lineage,source,origin_revision
    real(real64),intent(in)::interval_start,interval_end,air_temperature
    integer,intent(out)::status
    status=TAV_DAY_INVALID
    if(.not.window%initialized) return
    if(.not.ieee_is_finite(interval_start).or..not.ieee_is_finite(interval_end).or. &
       .not.ieee_is_finite(air_temperature)) return
    status=TAV_DAY_MISMATCH
    if(lineage/=window%lineage.or.source/=window%source.or. &
       origin_revision/=window%next_revision) return
    if(interval_end<=interval_start.or.interval_end>window%day_end) return
    status=TAV_DAY_DUPLICATE
    if(interval_start<window%covered) return
    status=TAV_DAY_GAP
    if(interval_start>window%covered) return
    window%integral=window%integral+air_temperature*(interval_end-interval_start)
    window%covered=interval_end
    window%next_revision=window%next_revision+1_int64
    window%intervals=window%intervals+1
    status=TAV_DAY_OK
  end subroutine
  pure logical function crop_tav_complete(self)
    class(crop_tav_day_window_t),intent(in)::self
    crop_tav_complete=self%initialized.and.self%intervals>0.and.self%covered==self%day_end
  end function
  subroutine read_crop_tav_day_candidate(window,tav,status)
    type(crop_tav_day_window_t),intent(in)::window
    real(real64),intent(out)::tav
    integer,intent(out)::status
    tav=0.0_real64;status=TAV_DAY_INVALID
    if(.not.window%complete()) return
    tav=window%integral/(window%day_end-window%day_start)
    if(.not.ieee_is_finite(tav)) then
      tav=0.0_real64;return
    end if
    status=TAV_DAY_OK
  end subroutine
  subroutine crop_tav_snapshot(self,lineage,source,revision,covered,count)
    class(crop_tav_day_window_t),intent(in)::self
    integer(int64),intent(out)::lineage,source,revision
    real(real64),intent(out)::covered
    integer,intent(out)::count
    lineage=self%lineage;source=self%source;revision=self%next_revision
    covered=self%covered;count=self%intervals
  end subroutine
end module
