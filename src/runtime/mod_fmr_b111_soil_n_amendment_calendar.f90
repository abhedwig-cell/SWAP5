module mod_fmr_b111_soil_n_amendment_calendar
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_soil_n_pool_state, only: soil_n_transfer_t,soil_n_receipt_t
  use mod_b111_soil_n_addition, only: b111_soil_n_material_t,b111_soil_n_split_parameters_t, &
       build_b111_amendment_transfer,B111_NADD_OK
  use mod_fmr_b111_soil_n_transaction, only: fmr_b111_soil_n_state_t, &
       apply_fmr_b111_soil_n_management_event,FMR_SOIL_N_OK,FMR_SOIL_N_EVENT_ALREADY_CONSUMED
  implicit none
  private

  integer,parameter,public::FMR_B111_AMCAL_OK=0
  integer,parameter,public::FMR_B111_AMCAL_NOT_DUE=1
  integer,parameter,public::FMR_B111_AMCAL_INVALID=2
  integer,parameter,public::FMR_B111_AMCAL_BUILD_FAILED=3
  integer,parameter,public::FMR_B111_AMCAL_APPLY_FAILED=4
  integer,parameter,public::FMR_B111_AMCAL_DUPLICATE=5
  integer,parameter,public::FMR_B111_AMCAL_OUT_OF_ORDER=6

  type,public::b111_amendment_calendar_group_t
    integer(int64)::event_id=0_int64
    real(real64)::source_time=0.0_real64
    type(b111_soil_n_material_t),allocatable::materials(:)
  end type

  type,public::b111_amendment_calendar_receipt_t
    integer::status=FMR_B111_AMCAL_INVALID
    integer(int64)::event_id=0_int64
    integer::material_count=0
    real(real64)::effective_time=0.0_real64
    type(soil_n_receipt_t)::nitrogen
  end type

  public::apply_b111_amendment_calendar_group

contains

  subroutine apply_b111_amendment_calendar_group(committed,evaluation_time,depth_m,split,group,candidate,receipt)
    type(fmr_b111_soil_n_state_t),intent(in)::committed
    real(real64),intent(in)::evaluation_time,depth_m
    type(b111_soil_n_split_parameters_t),intent(in)::split
    type(b111_amendment_calendar_group_t),intent(in)::group
    type(fmr_b111_soil_n_state_t),intent(out)::candidate
    type(b111_amendment_calendar_receipt_t),intent(out)::receipt
    type(soil_n_transfer_t)::total,part
    integer(int64)::last_event_id
    logical::consumed,available
    integer::i,build_status,apply_status

    candidate=committed
    receipt=b111_amendment_calendar_receipt_t()
    receipt%event_id=group%event_id
    receipt%effective_time=group%source_time+1.0_real64

    if(.not.committed%ready().or..not.ieee_is_finite(evaluation_time).or..not.ieee_is_finite(depth_m).or. &
       depth_m<=0.0_real64.or.group%event_id<=0_int64.or..not.ieee_is_finite(group%source_time).or. &
       .not.allocated(group%materials).or.size(group%materials)<1)return

    call committed%snapshot_management_event(last_event_id,consumed,available)
    if(.not.available)return
    if(consumed)then
      if(group%event_id<=last_event_id)then
        if(group%event_id==last_event_id)then
          receipt%status=FMR_B111_AMCAL_DUPLICATE
        else
          receipt%status=FMR_B111_AMCAL_OUT_OF_ORDER
        end if
        return
      end if
      if(group%event_id/=last_event_id+1_int64)then
        receipt%status=FMR_B111_AMCAL_OUT_OF_ORDER
        return
      end if
    else if(group%event_id/=1_int64)then
      receipt%status=FMR_B111_AMCAL_OUT_OF_ORDER
      return
    end if

    if(abs(receipt%effective_time-evaluation_time)>=1.0e-3_real64)then
      receipt%status=FMR_B111_AMCAL_NOT_DUE
      return
    end if

    total=soil_n_transfer_t()
    do i=1,size(group%materials)
      call build_b111_amendment_transfer(depth_m,group%materials(i),split,part,build_status)
      if(build_status/=B111_NADD_OK)then
        receipt%status=FMR_B111_AMCAL_BUILD_FAILED
        return
      end if
      call accumulate_transfer(total,part)
    end do

    call apply_fmr_b111_soil_n_management_event(committed,group%event_id,total,candidate,apply_status,receipt%nitrogen)
    if(apply_status==FMR_SOIL_N_EVENT_ALREADY_CONSUMED)then
      candidate=committed
      receipt%status=FMR_B111_AMCAL_DUPLICATE
      return
    end if
    if(apply_status/=FMR_SOIL_N_OK)then
      candidate=committed
      receipt%status=FMR_B111_AMCAL_APPLY_FAILED
      return
    end if
    receipt%material_count=size(group%materials)
    receipt%status=FMR_B111_AMCAL_OK
  end subroutine

  subroutine accumulate_transfer(total,part)
    type(soil_n_transfer_t),intent(inout)::total
    type(soil_n_transfer_t),intent(in)::part
    if(.not.allocated(total%fom_delta_kg_m3))then
      allocate(total%fom_delta_kg_m3(size(part%fom_delta_kg_m3)))
      total%fom_delta_kg_m3=0.0_real64
    end if
    total%fom_delta_kg_m3=total%fom_delta_kg_m3+part%fom_delta_kg_m3
    total%biomass_delta_kg_m3=total%biomass_delta_kg_m3+part%biomass_delta_kg_m3
    total%humus_delta_kg_m3=total%humus_delta_kg_m3+part%humus_delta_kg_m3
    total%ammonium_n_delta_kg_m2=total%ammonium_n_delta_kg_m2+part%ammonium_n_delta_kg_m2
    total%nitrate_n_delta_kg_m2=total%nitrate_n_delta_kg_m2+part%nitrate_n_delta_kg_m2
    total%external_n_input_kg_m2=total%external_n_input_kg_m2+part%external_n_input_kg_m2
    total%external_n_output_kg_m2=total%external_n_output_kg_m2+part%external_n_output_kg_m2
  end subroutine
end module
