program fgc24_export_probe
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t
  use mod_kernel_transactions, only: kernel_executor_t, kernel_committed_state_t
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_groundwater_coupling_contract, only: groundwater_coupling_window_t, groundwater_head_datum_t
  use mod_groundwater_coupling_policy, only: groundwater_head_convergence_policy_t
  use mod_groundwater_interface_mass_ledger, only: groundwater_interface_mass_ledger_t
  use mod_groundwater_predictor_corrector_window, only: groundwater_coupling_origin_t, groundwater_pc_result_t, run_restricted_groundwater_coupling_window
  use mod_groundwater_coupled_restart, only: groundwater_restart_state_t, groundwater_restart_adapter_t, groundwater_coupled_restart_record_t, export_groundwater_coupled_restart
  use mod_fgc21_restricted_predictor_corrector_owner_test, only: dummy_parameters_t, dummy_model_t, dummy_materializer_t, dummy_groundwater_service_t, setup_common
  implicit none
  type, extends(groundwater_restart_state_t) :: s_t
    integer(int64) :: sid=1_int64, lid=1_int64, rev=0_int64
    real(real64) :: t=0.0_real64
  contains
    procedure :: clone => s_clone
    procedure :: valid => s_valid
  end type
  type, extends(groundwater_restart_adapter_t) :: a_t
    type(dummy_groundwater_service_t), pointer :: p=>null()
  contains
    procedure :: export_committed => a_export
    procedure :: restore_committed => a_restore
  end type
  type(kernel_executor_t) :: ex
  type(kernel_committed_state_t) :: cs
  type(dummy_model_t), target :: model
  type(dummy_parameters_t) :: par
  type(dummy_materializer_t) :: mat
  type(dummy_groundwater_service_t), target :: gw
  type(a_t) :: a
  type(groundwater_interface_mass_ledger_t) :: led
  type(groundwater_head_datum_t) :: dat
  type(groundwater_head_convergence_policy_t) :: pol
  type(groundwater_coupling_window_t) :: win
  type(groundwater_coupling_origin_t) :: org
  type(canonical_numerical_config_t) :: num
  type(groundwater_pc_result_t) :: res
  type(groundwater_coupled_restart_record_t) :: rec
  class(transaction_state_t), allocatable :: init
  logical :: ok, exported
  integer :: st
  call setup_common(ex,model,par,gw,led,dat,pol,win,org,num,cs,init,ok,st)
  call run_restricted_groundwater_coupling_window(ex,par,cs,mat,num,gw,led,dat,pol,win,org,res)
  a%p=>gw
  call export_groundwater_coupled_restart(cs,2401_int64,gw,a,led,org,rec,exported,st)
  write(*,'(A,I0,A,L1)') 'FGC24_PROBE_STATUS=',st,' EXPORTED=',exported
contains
  subroutine s_clone(self,copy)
    class(s_t), intent(in) :: self
    class(groundwater_restart_state_t), allocatable, intent(out) :: copy
    allocate(s_t::copy)
    select type(x=>copy); type is(s_t); x=self; end select
  end subroutine
  logical function s_valid(self)
    class(s_t), intent(in) :: self
    s_valid=self%sid>0_int64 .and. self%lid>0_int64 .and. self%rev>=0_int64
  end function
  subroutine a_export(self,sid,lid,rev,t,state,status)
    class(a_t),intent(inout)::self
    integer(int64),intent(out)::sid,lid,rev
    real(real64),intent(out)::t
    class(groundwater_restart_state_t),allocatable,intent(out)::state
    integer,intent(out)::status
    allocate(s_t::state)
    select type(x=>state); type is(s_t)
      sid=self%p%service_id_value; lid=self%p%lineage_id_value; rev=self%p%revision; t=self%p%current_time
      x%sid=sid; x%lid=lid; x%rev=rev; x%t=t; status=0
    end select
  end subroutine
  subroutine a_restore(self,sid,lid,rev,t,state,status)
    class(a_t),intent(inout)::self
    integer(int64),intent(in)::sid,lid,rev
    real(real64),intent(in)::t
    class(groundwater_restart_state_t),intent(in)::state
    integer,intent(out)::status
    status=1
  end subroutine
end program
