program test_subsurface_solute_source
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_subsurface_solute_source
  implicit none
  real(real64) :: q(3), dz(3), mass(3), bulk(3), total, original_q(3), original_dz(3), nan
  integer :: status

  q=[1.0_real64,0.0_real64,2.0_real64];dz=[2.0_real64,1.0_real64,4.0_real64]
  original_q=q;original_dz=dz
  call accepted_a()
  ! A different accepted source, then A again: no hidden per-node or total carry.
  q=[0.0_real64,1.0_real64,0.0_real64]
  call evaluate_subsurface_solute_source(q,2.0_real64,dz,0.5_real64,mass,bulk,total,status)
  if(status/=SUBSOL_OK.or.any(mass/=[0.0_real64,1.0_real64,0.0_real64]))error stop 'source B'
  if(total/=1.0_real64.or.any(bulk/=[0.0_real64,1.0_real64,0.0_real64]))error stop 'source B units'
  q=original_q;call accepted_a()
  call evaluate_subsurface_solute_source(q,0.0_real64,dz,0.25_real64,mass,bulk,total,status)
  if(status/=SUBSOL_OK.or.any(mass/=0.0_real64).or.any(bulk/=0.0_real64).or.total/=0.0_real64) &
    error stop 'fresh water manufactured solute'

  ! The original interval allocation already supplies each node. It must not
  ! be divided by node count or redistributed by thickness by this source owner.
  q=1.0_real64
  call evaluate_subsurface_solute_source(q,4.0_real64,dz,0.25_real64,mass,bulk,total,status)
  if(status/=SUBSOL_OK.or.any(mass/=1.0_real64).or.total/=3.0_real64)error stop 'interval allocation changed'
  if(any(bulk/=[0.5_real64,1.0_real64,0.25_real64]))error stop 'interval bulk units'

  q=original_q;nan=ieee_value(0.0_real64,ieee_quiet_nan)
  q(2)=-1.0_real64;call refused(4.0_real64,0.25_real64,SUBSOL_INVALID)
  q=original_q;call refused(-1.0_real64,0.25_real64,SUBSOL_INVALID)
  call refused(4.0_real64,0.0_real64,SUBSOL_INVALID)
  dz(2)=0.0_real64;call refused(4.0_real64,0.25_real64,SUBSOL_INVALID)
  dz=original_dz;q(2)=nan;call refused(4.0_real64,0.25_real64,SUBSOL_INVALID)
  q=original_q;call refused(nan,0.25_real64,SUBSOL_INVALID)
  call refused(4.0_real64,nan,SUBSOL_INVALID)
  dz(2)=nan;call refused(4.0_real64,0.25_real64,SUBSOL_INVALID)
  dz=original_dz

  q=huge(1.0_real64);call refused(2.0_real64,1.0_real64,SUBSOL_OVERFLOW)
  q=huge(1.0_real64)/2.0_real64;dz=1.0_real64
  call refused(1.0_real64,1.0_real64,SUBSOL_OVERFLOW) ! finite nodes, overflowing total
  q=original_q;dz=original_dz;q(1)=huge(1.0_real64)/2.0_real64;dz(1)=0.25_real64
  call refused(1.0_real64,1.0_real64,SUBSOL_OVERFLOW) ! finite amount, overflowing bulk increment
  q=original_q;dz=original_dz
  mass=-9.0_real64;bulk=-8.0_real64;total=-7.0_real64
  call evaluate_subsurface_solute_source(q,4.0_real64,dz,0.25_real64,mass(:2),bulk,total,status)
  if(status/=SUBSOL_SHAPE.or.any(mass/=-9.0_real64).or.any(bulk/=-8.0_real64).or.total/=-7.0_real64) &
    error stop 'shape refusal modified outputs'
  call accepted_a()
  print '(a)', 'SUBSURFACE_SOLUTE_SOURCE_UNITS_CONSERVATION_NONMUTATION_ABA_REFUSALS=PASS'
contains
  subroutine accepted_a()
    call evaluate_subsurface_solute_source(q,4.0_real64,dz,0.25_real64,mass,bulk,total,status)
    if(status/=SUBSOL_OK.or.any(mass/=[1.0_real64,0.0_real64,2.0_real64]))error stop 'source A'
    if(any(bulk/=[0.5_real64,0.0_real64,0.5_real64]).or.total/=3.0_real64)error stop 'source A units'
    if(dot_product(bulk,dz)/=total.or.sum(mass)/=total)error stop 'source A conservation'
    if(any(q/=original_q).or.any(dz/=original_dz))error stop 'source mutated physical input'
  end subroutine
  subroutine refused(concentration,interval,expected)
    real(real64),intent(in)::concentration,interval
    integer,intent(in)::expected
    mass=-9.0_real64;bulk=-8.0_real64;total=-7.0_real64
    call evaluate_subsurface_solute_source(q,concentration,dz,interval,mass,bulk,total,status)
    if(status/=expected)error stop 'wrong source refusal'
    if(any(mass/=-9.0_real64).or.any(bulk/=-8.0_real64).or.total/=-7.0_real64)error stop 'refusal published source'
  end subroutine
end program
