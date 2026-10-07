module mod_b111_soil_n_amendment_group
  use, intrinsic :: iso_fortran_env, only: real64,int64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_soil_n_pool_state, only: soil_n_transfer_t
  use mod_b111_soil_n_addition, only: b111_soil_n_material_t,b111_soil_n_split_parameters_t, &
       build_b111_amendment_transfer,B111_NADD_OK
  implicit none
  private

  integer,parameter,public::B111_AMEND_GROUP_OK=0
  integer,parameter,public::B111_AMEND_GROUP_INVALID=1
  integer,parameter,public::B111_AMEND_GROUP_NOT_DUE=2
  integer,parameter,public::B111_AMEND_GROUP_BUILD_FAILED=3

  type,public::b111_amendment_group_t
    integer(int64)::event_id=0_int64
    real(real64)::legacy_event_time=0.0_real64
    type(b111_soil_n_material_t),allocatable::materials(:)
  end type

  type,public::b111_amendment_group_receipt_t
    integer::status=B111_AMEND_GROUP_INVALID
    integer(int64)::event_id=0_int64
    integer::material_count=0
    real(real64)::delivery_time=0.0_real64
    real(real64)::gross_n_input_kg_m2=0.0_real64
    real(real64)::volatilized_n_output_kg_m2=0.0_real64
  end type

  public::build_b111_due_amendment_group

contains

  subroutine build_b111_due_amendment_group(group,current_time,depth_m,split,transfer,receipt)
    type(b111_amendment_group_t),intent(in)::group
    real(real64),intent(in)::current_time,depth_m
    type(b111_soil_n_split_parameters_t),intent(in)::split
    type(soil_n_transfer_t),intent(out)::transfer
    type(b111_amendment_group_receipt_t),intent(out)::receipt
    type(soil_n_transfer_t)::part
    integer::i,status

    transfer=soil_n_transfer_t()
    allocate(transfer%fom_delta_kg_m3(8))
    transfer%fom_delta_kg_m3=0.0_real64
    receipt=b111_amendment_group_receipt_t()
    receipt%event_id=group%event_id
    if(group%event_id<=0_int64.or..not.ieee_is_finite(group%legacy_event_time).or. &
       .not.ieee_is_finite(current_time).or.depth_m<=0.0_real64)return
    if(.not.allocated(group%materials).or.size(group%materials)<1)return

    ! Exact legacy management trigger: abs(TimeAmend + 1 - t1900) < 1e-3.
    receipt%delivery_time=group%legacy_event_time+1.0_real64
    if(abs(receipt%delivery_time-current_time)>=1.0e-3_real64)then
      receipt%status=B111_AMEND_GROUP_NOT_DUE
      return
    end if

    do i=1,size(group%materials)
      call build_b111_amendment_transfer(depth_m,group%materials(i),split,part,status)
      if(status/=B111_NADD_OK)then
        transfer=soil_n_transfer_t()
        receipt%status=B111_AMEND_GROUP_BUILD_FAILED
        return
      end if
      call accumulate_transfer(transfer,part)
    end do
    receipt%material_count=size(group%materials)
    receipt%gross_n_input_kg_m2=transfer%external_n_input_kg_m2
    receipt%volatilized_n_output_kg_m2=transfer%external_n_output_kg_m2
    receipt%status=B111_AMEND_GROUP_OK
  end subroutine

  subroutine accumulate_transfer(total,part)
    type(soil_n_transfer_t),intent(inout)::total
    type(soil_n_transfer_t),intent(in)::part
    total%fom_delta_kg_m3=total%fom_delta_kg_m3+part%fom_delta_kg_m3
    total%biomass_delta_kg_m3=total%biomass_delta_kg_m3+part%biomass_delta_kg_m3
    total%humus_delta_kg_m3=total%humus_delta_kg_m3+part%humus_delta_kg_m3
    total%ammonium_n_delta_kg_m2=total%ammonium_n_delta_kg_m2+part%ammonium_n_delta_kg_m2
    total%nitrate_n_delta_kg_m2=total%nitrate_n_delta_kg_m2+part%nitrate_n_delta_kg_m2
    total%external_n_input_kg_m2=total%external_n_input_kg_m2+part%external_n_input_kg_m2
    total%external_n_output_kg_m2=total%external_n_output_kg_m2+part%external_n_output_kg_m2
  end subroutine
end module
