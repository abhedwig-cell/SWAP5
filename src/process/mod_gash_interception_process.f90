module mod_gash_interception_process
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private
  integer, parameter, public :: GASH_OK=0, GASH_INVALID_INPUT=1, GASH_INVALID_TABLE=2, GASH_INVALID_RESULT=3
  type, public :: gash_table_t
    real(real64), allocatable :: time(:)
    real(real64), allocatable :: value(:)
  end type
  type, public :: gash_source_window_input_t
    real(real64) :: source_time=0.0_real64
    real(real64) :: gross_rain_cm=0.0_real64
    real(real64) :: surface_irrigation_cm=0.0_real64
    logical :: surface_irrigation_is_intercepted=.true.
    type(gash_table_t) :: free_throughfall
    type(gash_table_t) :: stemflow
    type(gash_table_t) :: canopy_storage_cm
    type(gash_table_t) :: average_precipitation
    type(gash_table_t) :: average_evaporation
  end type
  type, public :: gash_source_window_result_t
    real(real64) :: interception_cm=0.0_real64
    real(real64) :: canopy_fraction=0.0_real64
    real(real64) :: saturation_precipitation_cm=0.0_real64
  end type
  public :: evaluate_gash_source_window
contains
  pure subroutine evaluate_gash_source_window(input,result,status)
    type(gash_source_window_input_t),intent(in)::input
    type(gash_source_window_result_t),intent(out)::result
    integer,intent(out)::status
    real(real64)::pfree,pstem,cgash,scanopy,avprec,avevap,psatcan,rpd,ratio
    result=gash_source_window_result_t(); status=GASH_INVALID_INPUT
    if(.not.ieee_is_finite(input%source_time).or.input%gross_rain_cm<0.0_real64.or.input%surface_irrigation_cm<0.0_real64)return
    if(.not.valid_table(input%free_throughfall).or..not.valid_table(input%stemflow).or. &
       .not.valid_table(input%canopy_storage_cm).or..not.valid_table(input%average_precipitation).or. &
       .not.valid_table(input%average_evaporation))then
      status=GASH_INVALID_TABLE; return
    end if
    pfree=afgen(input%free_throughfall,input%source_time)
    pstem=afgen(input%stemflow,input%source_time)
    cgash=1.0_real64-pfree-pstem
    if(cgash<=0.0_real64)return
    scanopy=afgen(input%canopy_storage_cm,input%source_time)/cgash
    avprec=afgen(input%average_precipitation,input%source_time)
    avevap=afgen(input%average_evaporation,input%source_time)/cgash
    if(avprec<=0.0_real64.or.avevap<=0.0_real64)return
    rpd=input%gross_rain_cm
    if(input%surface_irrigation_is_intercepted)rpd=rpd+input%surface_irrigation_cm
    ratio=avevap/avprec
    if((1.0_real64-ratio)>1.0e-4_real64)then
      if(ratio>=1.0_real64)return
      psatcan=-avprec*scanopy/avevap*log(1.0_real64-ratio)
    else
      psatcan=avprec*scanopy/avevap
    end if
    if(input%gross_rain_cm<psatcan)then
      result%interception_cm=cgash*rpd
    else
      result%interception_cm=cgash*(psatcan+avevap*cgash/avprec*(rpd-psatcan))
    end if
    result%canopy_fraction=cgash; result%saturation_precipitation_cm=psatcan
    if(.not.ieee_is_finite(result%interception_cm).or.result%interception_cm<0.0_real64)then
      result=gash_source_window_result_t(); status=GASH_INVALID_RESULT; return
    end if
    status=GASH_OK
  end subroutine
  pure logical function valid_table(tab)
    type(gash_table_t),intent(in)::tab
    integer::i
    valid_table=allocated(tab%time).and.allocated(tab%value)
    if(.not.valid_table)return
    valid_table=size(tab%time)>0.and.size(tab%time)==size(tab%value)
    if(.not.valid_table)return
    valid_table=all(ieee_is_finite(tab%time)).and.all(ieee_is_finite(tab%value))
    if(.not.valid_table)return
    do i=2,size(tab%time)
      if(tab%time(i)<=tab%time(i-1))then; valid_table=.false.; return; end if
    end do
  end function
  pure real(real64) function afgen(tab,x) result(v)
    type(gash_table_t),intent(in)::tab
    real(real64),intent(in)::x
    integer::i
    if(x<=tab%time(1).or.size(tab%time)==1)then; v=tab%value(1); return; end if
    do i=2,size(tab%time)
      if(x<=tab%time(i))then
        v=tab%value(i-1)+(x-tab%time(i-1))*(tab%value(i)-tab%value(i-1))/(tab%time(i)-tab%time(i-1)); return
      end if
    end do
    v=tab%value(size(tab%value))
  end function
end module mod_gash_interception_process
