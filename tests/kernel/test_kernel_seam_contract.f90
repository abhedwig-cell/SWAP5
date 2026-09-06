module test_kernel_seam_fixture
   use, intrinsic :: iso_fortran_env, only : real64
   use swap5_kernel_seam
   implicit none

   type, extends(swap5_parameters_t) :: test_parameters_t
      real(real64) :: value = 0.0_real64
   end type
   type, extends(swap5_committed_state_t) :: test_state_t
      real(real64) :: storage = 0.0_real64
   end type
   type, extends(swap5_forcing_t) :: test_forcing_t
      real(real64) :: amount = 0.0_real64
   end type
   type, extends(swap5_numerical_config_t) :: test_numerics_t
      real(real64) :: tolerance = 0.0_real64
   end type
   type, extends(swap5_worker_scratch_t) :: test_scratch_t
      integer :: calls = 0
   end type
   type, extends(swap5_trial_result_t) :: test_result_t
      real(real64) :: endpoint_storage = 0.0_real64
   end type
   type, extends(swap5_kernel_t) :: test_kernel_t
   contains
      procedure, nopass :: trial => test_trial
   end type

contains

   subroutine test_trial(interval, parameters, committed_state, forcing, numerics, scratch, result)
      type(swap5_interval_t), intent(in) :: interval
      class(swap5_parameters_t), intent(in) :: parameters
      class(swap5_committed_state_t), intent(in) :: committed_state
      class(swap5_forcing_t), intent(in) :: forcing
      class(swap5_numerical_config_t), intent(in) :: numerics
      class(swap5_worker_scratch_t), intent(inout) :: scratch
      class(swap5_trial_result_t), intent(inout) :: result
      real(real64) :: endpoint

      if (.not. interval%is_forward()) error stop 'invalid interval reached trial'

      select type (p => parameters)
      type is (test_parameters_t)
         endpoint = p%value
      class default
         error stop 'unexpected parameters type'
      end select

      select type (s => committed_state)
      type is (test_state_t)
         endpoint = endpoint + s%storage
      class default
         error stop 'unexpected state type'
      end select

      select type (f => forcing)
      type is (test_forcing_t)
         endpoint = endpoint + f%amount - 2.0_real64
      class default
         error stop 'unexpected forcing type'
      end select

      select type (n => numerics)
      type is (test_numerics_t)
         if (n%tolerance <= 0.0_real64) error stop 'invalid numerical config'
      class default
         error stop 'unexpected numerics type'
      end select

      select type (w => scratch)
      type is (test_scratch_t)
         w%calls = w%calls + 1
      class default
         error stop 'unexpected scratch type'
      end select

      select type (r => result)
      type is (test_result_t)
         r%endpoint_storage = endpoint
      class default
         error stop 'unexpected result type'
      end select
   end subroutine test_trial

end module test_kernel_seam_fixture

program test_kernel_seam_contract
   use, intrinsic :: iso_fortran_env, only : real64
   use swap5_kernel_seam
   use test_kernel_seam_fixture
   implicit none

   type(test_kernel_t) :: kernel
   type(test_parameters_t) :: parameters
   type(test_state_t) :: committed_state
   type(test_forcing_t) :: forcing
   type(test_numerics_t) :: numerics
   type(test_scratch_t) :: scratch
   type(test_result_t) :: result
   type(swap5_interval_t) :: interval

   interval = swap5_interval_t(t0_seconds=900.0_real64, t1_seconds=6300.0_real64)
   if (.not. interval%is_forward()) error stop 'forward interval rejected'

   parameters%value = 2.0_real64
   committed_state%storage = 3.0_real64
   forcing%amount = 4.0_real64
   numerics%tolerance = 1.0e-8_real64

   call kernel%trial(interval, parameters, committed_state, forcing, numerics, scratch, result)

   if (abs(committed_state%storage - 3.0_real64) > epsilon(1.0_real64)) error stop 'committed state mutated'
   if (scratch%calls /= 1) error stop 'scratch was not worker mutable'
   if (abs(result%endpoint_storage - 7.0_real64) > epsilon(1.0_real64)) error stop 'unexpected endpoint'

   interval = swap5_interval_t(t0_seconds=7200.0_real64, t1_seconds=7200.0_real64)
   if (interval%is_forward()) error stop 'zero interval accepted'

   print '(a)', 'KRS-1_KERNEL_SEAM_CONTRACT PASS'
end program test_kernel_seam_contract
