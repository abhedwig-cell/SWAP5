program test_b111_crop_n_fixation_policy
  use iso_fortran_env, only: real64
  use mod_b111_crop_n_fixation_policy
  implicit none
  type(b111_nfix_request_t) :: q
  type(b111_nfix_state_t) :: s, c
  type(b111_nfix_receipt_t) :: r
  real(real64), parameter :: eps=1e-12_real64

  call req(0.5_real64,1.0_real64,0.2_real64,q)
  call check(abs(q%fixation_request-10.2_real64)<eps,'literal base')
  call req(1.0_real64,1.0_real64,0.2_real64,q)
  call check(abs(q%fixation_request)<eps,'strict DVS cutoff')
  call req(0.5_real64,0.01_real64,0.2_real64,q)
  call check(abs(q%fixation_request)<eps,'strict RELTR cutoff')
  call req(0.5_real64,0.0100001_real64,0.2_real64,q)
  call check(abs(q%fixation_request-10.2_real64)<eps,'RELTR neighbour')
  call req(0.5_real64,1.0_real64,0.0_real64,q)
  call check(abs(q%fixation_request)<eps,'zero NFIXF')
  call req(0.5_real64,1.0_real64,1.0_real64,q)
  call check(abs(q%fixation_request-51.0_real64)<eps,'unit NFIXF')

  s%fixation_total=3.0_real64
  call req(0.5_real64,1.0_real64,0.2_real64,q)
  call apply_b111_nfixation(s,q,c,r)
  call check(r%status==B111_NFIX_OK,'receipt status')
  call check(abs(r%fixed_n-10.2_real64)<eps,'single fixation receipt')
  call check(abs(c%fixation_total-13.2_real64)<eps,'candidate total')
  call check(abs(s%fixation_total-3.0_real64)<eps,'committed unmutated')

  q%status=B111_NFIX_INVALID
  call apply_b111_nfixation(s,q,c,r)
  call check(r%status==B111_NFIX_INVALID,'rejected status')
  call check(abs(c%fixation_total-s%fixation_total)<eps,'rejected candidate identity')

  print '(A)','B111_NFIX_POLICY_PASS'
contains
  subroutine req(dvs,reltr,nfixf,q)
    real(real64),intent(in)::dvs,reltr,nfixf
    type(b111_nfix_request_t),intent(out)::q
    call prepare_b111_nfix_request(dvs,reltr,1.0_real64,nfixf, &
      1000.0_real64,800.0_real64,600.0_real64,0.03_real64,0.015_real64,0.015_real64, &
      0.0_real64,0.0_real64,0.0_real64,q)
  end subroutine
  subroutine check(ok,label)
    logical,intent(in)::ok
    character(len=*),intent(in)::label
    if(.not.ok) then
      print '(A)',trim(label)//' failed'
      error stop 1
    end if
  end subroutine
end program
