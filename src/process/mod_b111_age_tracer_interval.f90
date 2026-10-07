module mod_b111_age_tracer_interval
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_solute_compartment_state, only: solute_compartment_state_t
  use mod_b111_age_pond_exchange, only: b111_age_pond_result_t,evaluate_b111_age_pond_exchange,B111_AGE_POND_OK
  use mod_b111_age_tracer_matrix_substep, only: b111_age_matrix_physics_t,b111_age_matrix_receipt_t, &
       advance_b111_age_matrix_substep,B111_AGE_MATRIX_OK
  implicit none
  private

  integer,parameter,public::B111_AGE_INTERVAL_OK=0
  integer,parameter,public::B111_AGE_INTERVAL_INVALID=1
  integer,parameter,public::B111_AGE_INTERVAL_SURFACE_FAILED=2
  integer,parameter,public::B111_AGE_INTERVAL_MATRIX_FAILED=3
  integer,parameter,public::B111_AGE_INTERVAL_BALANCE=4
  integer,parameter,public::B111_AGE_INTERVAL_UNSUPPORTED=5

  type,public::b111_age_interval_receipt_t
    integer::status=B111_AGE_INTERVAL_INVALID
    type(b111_age_pond_result_t)::surface
    type(b111_age_matrix_receipt_t)::matrix
    real(real64)::age_before=0.0_real64
    real(real64)::age_after=0.0_real64
    real(real64)::external_age_input=0.0_real64
    real(real64)::external_age_output=0.0_real64
    real(real64)::age_production=0.0_real64
    real(real64)::balance_residual=0.0_real64
  end type

  public::advance_b111_age_tracer_matrix_interval

contains

  subroutine advance_b111_age_tracer_matrix_interval(committed,dz,theta_start,theta_end,q,root,qdra, &
       rain_rate,rain_age,irrigation_rate,irrigation_age,pond_end,bottom_age,drain_age,dt,physics, &
       candidate,receipt)
    type(solute_compartment_state_t),intent(in)::committed
    real(real64),intent(in)::dz(:),theta_start(:),theta_end(:),q(:),root(:),qdra(:,:)
    real(real64),intent(in)::rain_rate,rain_age,irrigation_rate,irrigation_age,pond_end,bottom_age,drain_age,dt
    type(b111_age_matrix_physics_t),intent(in)::physics
    type(solute_compartment_state_t),intent(out)::candidate
    type(b111_age_interval_receipt_t),intent(out)::receipt
    type(solute_compartment_state_t)::surface_state,matrix_state
    real(real64)::expected,scale,tol

    candidate=committed
    receipt=b111_age_interval_receipt_t()
    if(.not.committed%valid().or.size(q)/=size(committed%age_amount)+1)return
    if(.not.all(ieee_is_finite([rain_rate,rain_age,irrigation_rate,irrigation_age,pond_end,bottom_age,drain_age,dt])))return
    ! First bounded production envelope: matrix-only and an infiltrating top boundary.
    ! Macropore age partitioning and non-infiltrating pond/runoff are separate work.
    if(q(1)>=-1.0e-6_real64)then
      receipt%status=B111_AGE_INTERVAL_UNSUPPORTED
      return
    end if

    receipt%age_before=sum(committed%age_amount)+committed%pond_age_amount
    call evaluate_b111_age_pond_exchange(committed%pond_age_amount,rain_rate,rain_age, &
         irrigation_rate,irrigation_age,q(1),0.0_real64,pond_end,dt,receipt%surface)
    if(receipt%surface%status/=B111_AGE_POND_OK)then
      receipt%status=B111_AGE_INTERVAL_SURFACE_FAILED
      return
    end if

    surface_state=committed
    surface_state%pond_age_amount=receipt%surface%pond_age_amount_after
    call advance_b111_age_matrix_substep(surface_state,dz,theta_start,theta_end,q,root,qdra, &
         receipt%surface%pond_age_concentration,bottom_age,drain_age,dt,physics,matrix_state,receipt%matrix)
    if(receipt%matrix%status/=B111_AGE_MATRIX_OK)then
      receipt%status=B111_AGE_INTERVAL_MATRIX_FAILED
      return
    end if

    tol=4096.0_real64*epsilon(1.0_real64)*max(1.0_real64,abs(receipt%surface%soil_age_transfer), &
         abs(receipt%matrix%top_input))
    if(abs(receipt%surface%soil_age_transfer-receipt%matrix%top_input)>tol)then
      receipt%status=B111_AGE_INTERVAL_BALANCE
      return
    end if

    candidate=matrix_state
    receipt%age_after=sum(candidate%age_amount)+candidate%pond_age_amount
    receipt%external_age_input=receipt%surface%rain_age_input+receipt%surface%irrigation_age_input+ &
         receipt%matrix%bottom_input+receipt%matrix%drainage_input
    receipt%external_age_output=receipt%matrix%top_output+receipt%matrix%bottom_output+ &
         receipt%matrix%root_output+receipt%matrix%drainage_output
    receipt%age_production=receipt%matrix%age_production
    expected=receipt%age_before+receipt%external_age_input-receipt%external_age_output+receipt%age_production
    receipt%balance_residual=receipt%age_after-expected
    scale=max(1.0_real64,abs(receipt%age_before),abs(receipt%age_after),abs(expected))
    tol=8192.0_real64*epsilon(1.0_real64)*scale
    if(abs(receipt%balance_residual)>tol)then
      candidate=committed
      receipt%status=B111_AGE_INTERVAL_BALANCE
      return
    end if
    receipt%status=B111_AGE_INTERVAL_OK
  end subroutine
end module
