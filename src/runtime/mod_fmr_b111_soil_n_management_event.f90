module mod_fmr_b111_soil_n_management_event
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use mod_soil_n_pool_state, only: soil_n_transfer_t, soil_n_receipt_t
  use mod_b111_soil_n_addition, only: b111_soil_n_material_t, b111_soil_n_split_parameters_t, &
       build_b111_amendment_transfer, build_b111_residue_transfer, B111_NADD_OK
  use mod_fmr_b111_soil_n_transaction, only: fmr_b111_soil_n_state_t, &
       apply_fmr_b111_soil_n_management_event, FMR_SOIL_N_OK
  implicit none
  private

  integer,parameter,public::FMR_B111_N_EVENT_OK=0
  integer,parameter,public::FMR_B111_N_EVENT_INVALID=1
  integer,parameter,public::FMR_B111_N_EVENT_BUILD_FAILED=2
  integer,parameter,public::FMR_B111_N_EVENT_APPLY_FAILED=3
  integer,parameter,public::FMR_B111_N_EVENT_AMENDMENT=1
  integer,parameter,public::FMR_B111_N_EVENT_RESIDUE=2

  type,public::fmr_b111_soil_n_management_event_t
    integer(int64)::event_id=0_int64
    integer::event_kind=0
    real(real64)::depth_m=0.0_real64
    type(b111_soil_n_material_t)::material
    type(b111_soil_n_split_parameters_t)::split
  end type

  type,public::fmr_b111_soil_n_management_event_receipt_t
    integer::status=FMR_B111_N_EVENT_INVALID
    integer(int64)::event_id=0_int64
    integer::event_kind=0
    type(soil_n_receipt_t)::nitrogen
  end type

  public::apply_fmr_b111_soil_n_management_material_event

contains

  subroutine apply_fmr_b111_soil_n_management_material_event(state,event,receipt)
    type(fmr_b111_soil_n_state_t),intent(inout)::state
    type(fmr_b111_soil_n_management_event_t),intent(in)::event
    type(fmr_b111_soil_n_management_event_receipt_t),intent(out)::receipt
    type(soil_n_transfer_t)::transfer
    integer::build_status,apply_status

    receipt=fmr_b111_soil_n_management_event_receipt_t()
    receipt%event_id=event%event_id
    receipt%event_kind=event%event_kind
    if(event%event_id<=0_int64.or.event%depth_m<=0.0_real64)return

    select case(event%event_kind)
    case(FMR_B111_N_EVENT_AMENDMENT)
      call build_b111_amendment_transfer(event%depth_m,event%material,event%split,transfer,build_status)
    case(FMR_B111_N_EVENT_RESIDUE)
      call build_b111_residue_transfer(event%depth_m,event%material,event%split,transfer,build_status)
    case default
      return
    end select
    if(build_status/=B111_NADD_OK)then
      receipt%status=FMR_B111_N_EVENT_BUILD_FAILED
      return
    end if

    call apply_fmr_b111_soil_n_management_event(state,event%event_id,transfer,apply_status,receipt%nitrogen)
    if(apply_status/=FMR_SOIL_N_OK)then
      receipt%status=FMR_B111_N_EVENT_APPLY_FAILED
      return
    end if
    receipt%status=FMR_B111_N_EVENT_OK
  end subroutine
end module
