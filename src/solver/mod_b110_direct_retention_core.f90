module mod_b110_direct_retention_core
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_soil_water_solver_contract, only: CONSTITUTIVE_DEMAND_WATER_CONTENT, CONSTITUTIVE_DEMAND_CAPACITY
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  implicit none
  private

  integer, parameter, public :: B110_DIRECT_RETENTION_INTERVALS_PER_DECADE = 64

  type :: direct_retention_representation_t
    integer(int64) :: authority_bits(42)=0_int64
    logical :: ksatexm=.false.
    real(real64) :: theta(0:B110_DIRECT_RETENTION_INTERVALS_PER_DECADE,0:5)=0.0_real64
    real(real64) :: capacity(0:B110_DIRECT_RETENTION_INTERVALS_PER_DECADE,0:5)=0.0_real64
  end type direct_retention_representation_t

  type(direct_retention_representation_t), allocatable, save :: pool(:)
  logical, save :: frozen=.false.
  integer, save :: build_count=0, hit_count=0

  public :: acquire_b110_direct_retention_slot
  public :: sample_b110_direct_retention
  public :: freeze_b110_direct_retention_pool
  public :: reset_b110_direct_retention_pool
  public :: b110_direct_retention_pool_stats

contains
end module mod_b110_direct_retention_core
