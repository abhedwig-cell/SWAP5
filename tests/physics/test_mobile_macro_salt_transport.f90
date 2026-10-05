program test_mobile_macro_salt_transport
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_solute_macropore_exchange, only: mobile_macro_salt_state_t
  use mod_solute_mobile_macro_salt_transport, only: mobile_macro_salt_receipt_t, &
       mobile_macro_salt_substep_t, advance_mobile_macro_salt_trace, &
       initialize_mobile_macro_salt_state, derive_mobile_macro_salt_concentration, &
       advance_mobile_macro_salt_trial, MACRO_SALT_OK, MACRO_SALT_INVALID, MACRO_SALT_WATER_CLOSURE
  implicit none
  type(mobile_macro_salt_state_t) :: accepted,candidate,rejected,initialized
  type(mobile_macro_salt_receipt_t) :: receipt,trace_receipt,failed_trace_receipt
  type(mobile_macro_salt_substep_t), allocatable :: salt_trace(:)
  type(mobile_macro_salt_state_t) :: trace_candidate,failed_trace_candidate
  real(real64) :: dz(2),theta0(2),theta1(2),macro0(1,2),macro1(1,2)
  real(real64) :: matrix_faces(3),macro_faces(1,3),exchange(1,2),root_sink(2)
  real(real64) :: macro_top(1),macro_bottom(1),total_before
  real(real64) :: matrix_concentration(2),macro_concentration(1,2)
  real(real64), allocatable :: derived_matrix_concentration(:),derived_macro_concentration(:,:)
  integer :: status,i

  dz=[10.0_real64,20.0_real64]
  theta0=[0.2_real64,0.25_real64]
  macro0(1,:)=[1.0_real64,2.0_real64]
  matrix_concentration=[0.5_real64,0.4_real64]
  macro_concentration(1,:)=[0.5_real64,0.5_real64]
  call initialize_mobile_macro_salt_state(dz,theta0,macro0,matrix_concentration,macro_concentration, &
       initialized,status)
  call require(status==MACRO_SALT_OK,'separate matrix/macro profile initialization')
  call close_to(initialized%matrix_mass_mg_cm2(1),1.0_real64,'matrix profile inventory')
  call close_to(initialized%macro_mass_mg_cm2(1,2),1.0_real64,'domain profile inventory')
  call derive_mobile_macro_salt_concentration(initialized,dz,theta0,macro0,derived_matrix_concentration, &
       derived_macro_concentration,status)
  call require(status==MACRO_SALT_OK,'derive concentration view from mass and water')
  call require(maxval(abs(derived_matrix_concentration-matrix_concentration))<=1.0e-14_real64, &
       'matrix concentration view identity')
  call require(maxval(abs(derived_macro_concentration-macro_concentration))<=1.0e-14_real64, &
       'domain concentration view identity')
  accepted=initialized
  matrix_faces=0.0_real64
  macro_faces(1,:)=[0.0_real64,0.1_real64,0.0_real64]
  exchange(1,:)=[0.1_real64,-0.02_real64]
  root_sink=0.0_real64
  macro_top=0.0_real64;macro_bottom=0.0_real64
  macro1(1,1)=0.98_real64
  macro1(1,2)=2.012_real64
  theta1(1)=(theta0(1)*dz(1)+0.01_real64)/dz(1)
  theta1(2)=(theta0(2)*dz(2)-0.002_real64)/dz(2)
  total_before=sum(accepted%matrix_mass_mg_cm2)+sum(accepted%macro_mass_mg_cm2)

  ! Nonzero vertical macro advection and opposite-sign exchange happen in one
  ! conservative step using only committed donor concentrations.
  call advance_mobile_macro_salt_trial(accepted,dz,theta0,theta1,macro0,macro1,matrix_faces,macro_faces, &
       exchange,root_sink,0.0_real64,0.0_real64,macro_top,macro_bottom,1.0_real64,0.1_real64, &
       candidate,receipt,status)
  call require(status==MACRO_SALT_OK,'coupled transport accepted')
  call close_to(candidate%matrix_mass_mg_cm2(1),1.005_real64,'macro to matrix exchange')
  call close_to(candidate%matrix_mass_mg_cm2(2),1.9992_real64,'matrix to macro exchange')
  call close_to(candidate%macro_mass_mg_cm2(1,1),0.49_real64,'macro face and exchange outflow')
  call close_to(candidate%macro_mass_mg_cm2(1,2),1.0058_real64,'macro face and exchange inflow')
  call close_to(sum(candidate%matrix_mass_mg_cm2)+sum(candidate%macro_mass_mg_cm2),total_before, &
       'internal transport salt conservation')
  call close_to(receipt%closure_error_mg_cm2,0.0_real64,'internal ledger closure')

  ! Ordered trace reversal must use the first candidate's donor concentration.
  allocate(salt_trace(2))
  do i=1,2
    allocate(salt_trace(i)%matrix_water_start(2),salt_trace(i)%matrix_water_end(2), &
         salt_trace(i)%macro_water_start(1,2),salt_trace(i)%macro_water_end(1,2), &
         salt_trace(i)%matrix_face_rate(3),salt_trace(i)%macro_face_rate(1,3), &
         salt_trace(i)%exchange_rate(1,2),salt_trace(i)%root_water_sink(2), &
         salt_trace(i)%macro_top_concentration_mg_cm3(1),salt_trace(i)%macro_bottom_concentration_mg_cm3(1))
    salt_trace(i)%root_water_sink=0.0_real64
    salt_trace(i)%macro_top_concentration_mg_cm3=0.0_real64
    salt_trace(i)%macro_bottom_concentration_mg_cm3=0.0_real64
    salt_trace(i)%matrix_top_concentration_mg_cm3=0.0_real64
    salt_trace(i)%matrix_bottom_concentration_mg_cm3=0.0_real64
  end do
  salt_trace(1)%t0=0.0_real64;salt_trace(1)%t1=0.1_real64
  salt_trace(1)%matrix_water_start=theta0;salt_trace(1)%matrix_water_end=theta1
  salt_trace(1)%macro_water_start=macro0;salt_trace(1)%macro_water_end=macro1
  salt_trace(1)%matrix_face_rate=0.0_real64
  salt_trace(1)%macro_face_rate=macro_faces
  salt_trace(1)%exchange_rate=exchange
  salt_trace(2)%t0=0.1_real64;salt_trace(2)%t1=0.2_real64
  salt_trace(2)%matrix_water_start=theta1
  salt_trace(2)%matrix_water_end(1)=(theta1(1)*dz(1)-0.005_real64)/dz(1)
  salt_trace(2)%matrix_water_end(2)=(theta1(2)*dz(2)+0.001_real64)/dz(2)
  salt_trace(2)%macro_water_start=macro1
  salt_trace(2)%macro_water_end(1,:)=[0.985_real64,2.011_real64]
  salt_trace(2)%matrix_face_rate=0.0_real64;salt_trace(2)%macro_face_rate=0.0_real64
  salt_trace(2)%exchange_rate(1,:)=[-0.05_real64,0.01_real64]
  call advance_mobile_macro_salt_trace(accepted,dz,salt_trace,1.0_real64,trace_candidate,trace_receipt,status)
  call require(status==MACRO_SALT_OK,'ordered coupled trace accepted')
  call close_to(trace_receipt%matrix_to_macro_mg_cm2(1,1),0.0025_real64, &
       'reversal uses updated matrix donor concentration')
  call close_to(trace_receipt%macro_to_matrix_mg_cm2(1,2),0.001_real64*1.0058_real64/2.012_real64, &
       'reversal uses updated macro donor concentration')
  call close_to(trace_receipt%closure_error_mg_cm2,0.0_real64,'ordered trace cumulative closure')
  salt_trace(2)%macro_water_end(1,2)=salt_trace(2)%macro_water_end(1,2)+0.01_real64
  call advance_mobile_macro_salt_trace(accepted,dz,salt_trace,1.0_real64, &
       failed_trace_candidate,failed_trace_receipt,status)
  call require(status==MACRO_SALT_WATER_CLOSURE,'late trace failure rejects full candidate')
  call require(.not.allocated(failed_trace_candidate%matrix_mass_mg_cm2).and. &
       .not.allocated(failed_trace_receipt%macro_to_matrix_mg_cm2), &
       'late trace failure returns no candidate or internal receipt')

  ! Explicit matrix boundary receipts and a source-valid root solute fraction are
  ! accounted separately from internal exchange and macro vertical transport.
  matrix_faces=[0.2_real64,0.0_real64,0.1_real64]
  macro_faces=0.0_real64
  theta1(1)=(theta0(1)*dz(1)+0.02_real64+0.01_real64-0.0001_real64)/dz(1)
  theta1(2)=(theta0(2)*dz(2)-0.01_real64-0.002_real64)/dz(2)
  macro1(1,:)=[0.99_real64,2.002_real64]
  root_sink=[0.001_real64,0.0_real64]
  call advance_mobile_macro_salt_trial(accepted,dz,theta0,theta1,macro0,macro1,matrix_faces,macro_faces, &
       exchange,root_sink,3.0_real64,0.0_real64,macro_top,macro_bottom,2.0_real64,0.1_real64, &
       candidate,receipt,status)
  call require(status==MACRO_SALT_OK,'boundary and root receipts accepted')
  call close_to(receipt%matrix_top_input_mg_cm2,0.06_real64,'matrix top salt input')
  call close_to(receipt%matrix_bottom_output_mg_cm2,0.004_real64,'matrix bottom salt output')
  call close_to(receipt%root_solute_uptake_mg_cm2(1),0.0001_real64,'TSCF above unity root salt receipt')
  call close_to(sum(candidate%matrix_mass_mg_cm2)+sum(candidate%macro_mass_mg_cm2), &
       total_before+0.06_real64-0.004_real64-0.0001_real64,'external salt ledger')
  call close_to(receipt%closure_error_mg_cm2,0.0_real64,'external ledger closure')
  call advance_mobile_macro_salt_trial(accepted,dz,theta0,theta1,macro0,macro1,matrix_faces,macro_faces, &
       exchange,root_sink,3.0_real64,0.0_real64,macro_top,macro_bottom,10.01_real64,0.1_real64, &
       rejected,receipt,status)
  call require(status==MACRO_SALT_INVALID.and..not.allocated(rejected%matrix_mass_mg_cm2), &
       'TSCF above B1.11 bound rejects candidate')

  ! Bad Richards water closure rejects the complete candidate with no state.
  matrix_faces=0.0_real64
  macro_faces(1,:)=[0.0_real64,0.1_real64,0.0_real64]
  root_sink=0.0_real64
  macro1(1,:)=[0.98_real64,2.012_real64]
  theta1(1)=(theta0(1)*dz(1)+0.01_real64)/dz(1)
  theta1(2)=(theta0(2)*dz(2)-0.002_real64)/dz(2)
  theta1(1)=theta1(1)+1.0e-4_real64
  call advance_mobile_macro_salt_trial(accepted,dz,theta0,theta1,macro0,macro1,matrix_faces,macro_faces, &
       exchange,root_sink,0.0_real64,0.0_real64,macro_top,macro_bottom,1.0_real64,0.1_real64, &
       rejected,receipt,status)
  call require(status==MACRO_SALT_WATER_CLOSURE,'matrix water closure rejection')
  call require(.not.allocated(rejected%matrix_mass_mg_cm2),'closure failure publishes no salt candidate')

  ! Nonfinite accepted flow is invalid and does not leak a partial receipt.
  theta1(1)=(theta0(1)*dz(1)+0.01_real64)/dz(1)
  matrix_faces(2)=ieee_value(0.0_real64,ieee_quiet_nan)
  call advance_mobile_macro_salt_trial(accepted,dz,theta0,theta1,macro0,macro1,matrix_faces,macro_faces, &
       exchange,root_sink,0.0_real64,0.0_real64,macro_top,macro_bottom,1.0_real64,0.1_real64, &
       rejected,receipt,status)
  call require(status==MACRO_SALT_INVALID,'nonfinite face rate rejection')
  call require(.not.allocated(rejected%macro_mass_mg_cm2),'invalid flow publishes no macro candidate')

  ! Positive salt mass cannot be paired with dry water during concentration
  ! derivation; concentration itself is not an independent authority.
  macro0(1,1)=0.0_real64
  call derive_mobile_macro_salt_concentration(initialized,dz,theta0,macro0,derived_matrix_concentration, &
       derived_macro_concentration,status)
  call require(status==MACRO_SALT_INVALID,'dry positive macro inventory rejected')
  call require(.not.allocated(derived_macro_concentration),'dry state publishes no concentration view')

  write(*,'(a)') 'PPA_WU05E_MOBILE_MACRO_SALT_TRANSPORT=PASS'

contains
  subroutine require(ok,message)
    logical,intent(in)::ok
    character(*),intent(in)::message
    if(.not.ok)then
      write(*,'(a)') 'FAIL: '//message
      error stop 1
    end if
  end subroutine

  subroutine close_to(actual,expected,message)
    real(real64),intent(in)::actual,expected
    character(*),intent(in)::message
    call require(abs(actual-expected)<=1.0e-12_real64,message)
  end subroutine
end program test_mobile_macro_salt_transport
