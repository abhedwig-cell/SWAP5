module mod_rfm_whole_column_candidate_ledger
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private
  type, public :: rfm_whole_column_candidate_request_t
    real(real64)::effective_input_cm=0.0_real64,matrix_input_cm=0.0_real64
    real(real64)::ic_input_cm=0.0_real64,mb_input_cm=0.0_real64
    real(real64)::endpoint_storage_start_cm=0.0_real64,endpoint_to_matrix_cm=0.0_real64
    real(real64)::endpoint_storage_end_cm=0.0_real64,mb_wall_to_matrix_cm=0.0_real64
    real(real64)::mb_deep_receipt_cm=0.0_real64,mb_storage_end_cm=0.0_real64
  end type
  type, public :: rfm_whole_column_candidate_result_t
    logical::valid=.false.
    real(real64)::surface_partition_residual_cm=0.0_real64
    real(real64)::ic_residual_cm=0.0_real64,mb_residual_cm=0.0_real64
    real(real64)::whole_column_residual_cm=0.0_real64
  end type
  public::evaluate_rfm_whole_column_candidate_ledger
contains
  pure subroutine evaluate_rfm_whole_column_candidate_ledger(req,tol,res)
    type(rfm_whole_column_candidate_request_t),intent(in)::req
    real(real64),intent(in)::tol
    type(rfm_whole_column_candidate_result_t),intent(out)::res
    real(real64)::v(10)
    res=rfm_whole_column_candidate_result_t()
    v=[req%effective_input_cm,req%matrix_input_cm,req%ic_input_cm,req%mb_input_cm, &
       req%endpoint_storage_start_cm,req%endpoint_to_matrix_cm,req%endpoint_storage_end_cm, &
       req%mb_wall_to_matrix_cm,req%mb_deep_receipt_cm,req%mb_storage_end_cm]
    if(.not.ieee_is_finite(tol).or.tol<0.0_real64)return
    if(any(.not.ieee_is_finite(v)).or.any(v<0.0_real64))return
    if(req%mb_storage_end_cm>tol)return
    res%surface_partition_residual_cm=req%effective_input_cm-req%matrix_input_cm-req%ic_input_cm-req%mb_input_cm
    res%ic_residual_cm=req%ic_input_cm+req%endpoint_storage_start_cm-req%endpoint_to_matrix_cm-req%endpoint_storage_end_cm
    res%mb_residual_cm=req%mb_input_cm-req%mb_wall_to_matrix_cm-req%mb_deep_receipt_cm
    res%whole_column_residual_cm=req%effective_input_cm+req%endpoint_storage_start_cm- &
      req%matrix_input_cm-req%endpoint_to_matrix_cm-req%mb_wall_to_matrix_cm- &
      req%mb_deep_receipt_cm-req%endpoint_storage_end_cm
    if(abs(res%surface_partition_residual_cm)>tol)return
    if(abs(res%ic_residual_cm)>tol)return
    if(abs(res%mb_residual_cm)>tol)return
    if(abs(res%whole_column_residual_cm)>tol)return
    res%valid=.true.
  end subroutine
end module mod_rfm_whole_column_candidate_ledger
