module mod_soil_water_solver_contract
  use, intrinsic :: iso_fortran_env, only: int64
  implicit none
  type :: soil_water_solver_workspace_base_t
     integer :: reserved = 0
  end type
  type :: soil_water_solver_diagnostics_t
     character(len=64) :: route = ''
  end type
end module mod_soil_water_solver_contract
