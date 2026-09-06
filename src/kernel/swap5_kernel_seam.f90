module swap5_kernel_seam
   !! KRS-1: production-facing contract for one SWAP5 kernel trial.
   !!
   !! This module deliberately contains no SWAP physics and no concrete solver.
   !! It defines the typed boundary that the future production kernel must
   !! satisfy before a full-accuracy reference policy can be admitted as B2.
   !!
   !! Governing semantics:
   !! - one kernel seam for reference/balanced/throughput numerical policies;
   !! - generic positive interval [t0,t1] on a caller-defined time origin;
   !! - time coordinates are seconds, not calendar days/months/years;
   !! - parameters, committed state, forcing, numerics and scratch are separate;
   !! - committed state is input-only during a trial;
   !! - scratch is worker/job owned and mutable;
   !! - result storage is caller/runtime owned and mutable;
   !! - commit/rollback remains outside the kernel trial;
   !! - no file, path, calendar-day or MODFLOW-composition inputs exist here.
   use, intrinsic :: iso_fortran_env, only : real64
   implicit none
   private

   character(len=*), parameter, public :: SWAP5_KERNEL_SEAM_ID = &
      'SWAP5-KERNEL-SEAM-v1'
   character(len=*), parameter, public :: SWAP5_KERNEL_IMPLEMENTATION_STATUS = &
      'DEFERRED_NO_KERNEL_IMPLEMENTATION'

   type, public :: swap5_interval_t
      real(real64) :: t0_seconds = 0.0_real64
      real(real64) :: t1_seconds = 0.0_real64
   contains
      procedure, public :: is_forward => interval_is_forward
   end type swap5_interval_t

   type, abstract, public :: swap5_parameters_t
   end type swap5_parameters_t

   type, abstract, public :: swap5_committed_state_t
   end type swap5_committed_state_t

   type, abstract, public :: swap5_forcing_t
   end type swap5_forcing_t

   type, abstract, public :: swap5_numerical_config_t
   end type swap5_numerical_config_t

   type, abstract, public :: swap5_worker_scratch_t
   end type swap5_worker_scratch_t

   type, abstract, public :: swap5_trial_result_t
   end type swap5_trial_result_t

   abstract interface
      subroutine swap5_kernel_trial_ifc(interval, parameters, committed_state, forcing, numerics, scratch, result)
         import :: swap5_interval_t
         import :: swap5_parameters_t
         import :: swap5_committed_state_t
         import :: swap5_forcing_t
         import :: swap5_numerical_config_t
         import :: swap5_worker_scratch_t
         import :: swap5_trial_result_t
         type(swap5_interval_t), intent(in) :: interval
         class(swap5_parameters_t), intent(in) :: parameters
         class(swap5_committed_state_t), intent(in) :: committed_state
         class(swap5_forcing_t), intent(in) :: forcing
         class(swap5_numerical_config_t), intent(in) :: numerics
         class(swap5_worker_scratch_t), intent(inout) :: scratch
         class(swap5_trial_result_t), intent(inout) :: result
      end subroutine swap5_kernel_trial_ifc
   end interface

   type, abstract, public :: swap5_kernel_t
   contains
      procedure(swap5_kernel_trial_ifc), deferred, nopass, public :: trial
   end type swap5_kernel_t

contains

   pure logical function interval_is_forward(self)
      class(swap5_interval_t), intent(in) :: self
      interval_is_forward = self%t1_seconds > self%t0_seconds
   end function interval_is_forward

end module swap5_kernel_seam
