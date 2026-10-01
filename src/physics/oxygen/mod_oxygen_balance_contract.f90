module mod_oxygen_balance_contract
   use iso_fortran_env, only : real64
   implicit none
   private

   public :: OxygenBalancePoint
   public :: oxygen_balance_residual

   type :: OxygenBalancePoint
      real(real64) :: c_macro = 0.0_real64
      real(real64) :: c_min_micro = 0.0_real64
   end type OxygenBalancePoint

contains

   pure function oxygen_balance_residual(point) result(residual)
      type(OxygenBalancePoint), intent(in) :: point
      real(real64) :: residual

      ! Source-bound legacy SOLVE/myfunc semantics:
      ! positive means macro-scale oxygen supply/concentration is sufficient
      ! for the microscopic/root requirement at the requested respiration factor.
      residual = point%c_macro - point%c_min_micro
   end function oxygen_balance_residual

end module mod_oxygen_balance_contract
