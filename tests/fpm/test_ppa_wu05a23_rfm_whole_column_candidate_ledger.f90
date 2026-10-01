program test_ppa_wu05a23_rfm_whole_column_candidate_ledger
 use, intrinsic::iso_fortran_env,only:real64
 use mod_rfm_whole_column_candidate_ledger
 implicit none
 real(real64),parameter::T=1e-12_real64
 type(rfm_whole_column_candidate_request_t)::q
 type(rfm_whole_column_candidate_result_t)::r,r2
 q%effective_input_cm=0.8_real64
 q%matrix_input_cm=0.3_real64
 q%ic_input_cm=0.35_real64
 q%mb_input_cm=0.15_real64
 q%endpoint_storage_start_cm=0.10_real64
 q%endpoint_to_matrix_cm=0.25_real64
 q%endpoint_storage_end_cm=0.20_real64
 q%mb_wall_to_matrix_cm=0.05_real64
 q%mb_deep_receipt_cm=0.10_real64
 call evaluate_rfm_whole_column_candidate_ledger(q,T,r)
 call need(r%valid,'valid')
 call need(abs(r%whole_column_residual_cm)<=T,'whole closure')
 call evaluate_rfm_whole_column_candidate_ledger(q,T,r2)
 call need(r2%valid.and.r2%whole_column_residual_cm==r%whole_column_residual_cm,'replay')
 q%mb_deep_receipt_cm=0.09_real64
 call evaluate_rfm_whole_column_candidate_ledger(q,T,r)
 call need(.not.r%valid,'MB mismatch')
 q%mb_deep_receipt_cm=0.10_real64;q%mb_storage_end_cm=0.01_real64
 call evaluate_rfm_whole_column_candidate_ledger(q,T,r)
 call need(.not.r%valid,'MB storage accepted')
 print '(a)','PPA_WU05A23_RFM_WHOLE_COLUMN_LEDGER=PASS'
contains
 subroutine need(ok,msg)
 logical,intent(in)::ok;character(*),intent(in)::msg
 if(.not.ok)then;write(*,'(a,1x,a)')'A23_FAIL',trim(msg);error stop 1;end if
 end subroutine
end program
