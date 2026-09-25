program test_fahl43_policy_identity
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, initialize_b110_default_mvg_parameters
  use mod_b110_adaptive_hydraulic_cache, only: b110_adaptive_hydraulic_cache_key_t, &
       make_b110_adaptive_hydraulic_key, b110_adaptive_hydraulic_keys_equal
  implicit none

  type(b110_default_mvg_parameters_t) :: p
  type(b110_adaptive_hydraulic_cache_key_t) :: k3,k4
  real(real64) :: cofgen(42,1)

  cofgen=0.0_real64
  cofgen(1,1)=0.0_real64
  cofgen(2,1)=0.458246_real64
  cofgen(3,1)=3.766627_real64
  cofgen(4,1)=0.009715_real64
  cofgen(5,1)=-1.013083_real64
  cofgen(6,1)=1.375784_real64
  cofgen(7,1)=1.0_real64-1.0_real64/cofgen(6,1)
  cofgen(8,1)=cofgen(4,1)
  cofgen(9,1)=0.0_real64
  cofgen(10,1)=cofgen(3,1)
  cofgen(11,1)=0.999_real64
  cofgen(12,1)=0.99_real64*cofgen(3,1)
  cofgen(22,1)=-1.0e6_real64
  cofgen(23,1)=1.0e-12_real64

  call initialize_b110_default_mvg_parameters(p,cofgen)
  k3=make_b110_adaptive_hydraulic_key(p,'B110_DEFAULT_MVG',3,1)
  k4=make_b110_adaptive_hydraulic_key(p,'B110_DEFAULT_MVG',4,1)

  if(k3%policy_version /= 3) error stop 'policy-3 key not bound'
  if(k4%policy_version /= 4) error stop 'policy-4 key not bound'
  if(b110_adaptive_hydraulic_keys_equal(k3,k4)) error stop 'policy versions collide under exact equality'
  if(k3%fingerprint == k4%fingerprint) error stop 'policy versions collide in fingerprint'

  write(*,'(A)') 'FAHL43_POLICY_IDENTITY_3_VS_4=PASS'
end program test_fahl43_policy_identity
