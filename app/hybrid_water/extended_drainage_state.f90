! Experimental component: original MOD_drain transaction and native carry.
! Public SWDRA2 admission is separate. No process equation is implemented here.
module hybrid_extended_drainage_state
  use iso_fortran_env, only: real128
  use ieee_arithmetic, only: ieee_is_finite
  implicit none
  private
  public :: extended_drain_trial_begin, extended_drain_trial_end
  public :: extended_drain_checkpoint, extended_drain_witness
  public :: extended_drain_window_begin, extended_drain_surface_flux
  logical, save :: active = .false.
  integer, save :: saved_domain(8), saved_adjustments
  real(8), save :: saved_clock
  real(8), allocatable, save :: saved_values(:)
  logical, save :: window_active=.false., origin_pending=.false., branch_seen=.false.
  integer, save :: accepted_steps=0, rejected_steps=0
  real(8), save :: stock_origin, branch_supply=0d0, branch_discharge=0d0
  real(8), allocatable, save :: original_level_origin(:)
  real(real128), save :: flux(6)=0.0_real128
  real(real128), allocatable, save :: level_flux(:)
contains
  subroutine extended_drain_window_begin()
    if (active) error stop 'Extended drain window contains unresolved trial'
    window_active=.true.;origin_pending=.true.
    accepted_steps=0;rejected_steps=0;flux=0.0_real128
    if (allocated(level_flux)) deallocate(level_flux)
    if (allocated(original_level_origin)) deallocate(original_level_origin)
  end subroutine

  subroutine extended_drain_surface_flux(supply, discharge)
    real(8), intent(in) :: supply, discharge
    if (.not.active.or.branch_seen) error stop 'Foreign original surfacewater flux witness'
    if (.not.all(ieee_is_finite([supply,discharge])).or.min(supply,discharge)<0d0) &
      error stop 'Invalid original surfacewater supply or discharge'
    branch_supply=supply;branch_discharge=discharge;branch_seen=.true.
  end subroutine

  subroutine domain(header)
    use MOD_swap_base, only: swmacro, swdra
    use MOD_grid, only: numnod
    use MOD_drain, only: nrlevs, swsrf, swsec, nrpri, nrsec, swdivd, qdra
    integer, intent(out) :: header(8)
    if (swmacro /= 0.or.swdra /= 2) error stop 'Foreign extended drain process domain'
    if (numnod < 1.or.numnod > size(qdra,2).or.nrlevs < 1.or.nrlevs > size(qdra,1)) &
      error stop 'Foreign extended drain geometry'
    ! Original SWSRF1 uses an unassigned saved local water level. Its separate
    ! reference-defect investigation cannot acquire admission through this owner.
    if (swsrf < 2.or.swsrf > 3.or.swsec < 1.or.swsec > 2) &
      error stop 'Unqualified extended surfacewater selector'
    if (nrpri /= swsrf-2.or.nrsec /= nrlevs-nrpri.or.nrsec < 1.or.swdivd < 0.or.swdivd > 1) &
      error stop 'Foreign extended drain partition'
    header = [1,numnod,nrlevs,swsrf,swsec,nrpri,nrsec,swdivd]
  end subroutine

  subroutine pack(values)
    use MOD_grid, only: numnod
    use MOD_drain, only: nrlevs,wlp,wls,swst,wlstar,wetper,qdrd,qdrtot,wlsbak,qdrain,drainl,diffl,qdra
    real(8), allocatable, intent(out) :: values(:)
    values = [wlp,wls,swst,wlstar,wetper,qdrd,qdrtot,wlsbak, &
              qdrain(1:nrlevs),drainl(1:nrlevs),diffl(1:nrlevs), &
              reshape(qdra(1:nrlevs,1:numnod),[nrlevs*numnod])]
  end subroutine

  subroutine validate(values, adjustments, header)
    use MOD_grid, only: numnod, layer
    use MOD_drain, only: cofani, ksatcp
    real(8), intent(in) :: values(:)
    integer, intent(in) :: adjustments, header(8)
    if (size(values) /= 11+3*header(3)+header(3)*header(2)) &
      error stop 'Incomplete extended drain state'
    if (.not.all(ieee_is_finite(values)).or.adjustments < 0) then
      write(*,'(a,*(1x,es25.17e3))') 'EXTENDED_DRAIN_INVALID_STATE',values
      write(*,'(a,*(1x,es25.17e3))') 'EXTENDED_DRAIN_ACTUAL_KSAT',ksatcp(1:numnod)
      write(*,'(a,*(1x,es25.17e3))') 'EXTENDED_DRAIN_ACTUAL_ANISOTROPY',cofani
      write(*,'(a,*(1x,i0))') 'EXTENDED_DRAIN_ACTUAL_LAYERS',layer(1:numnod)
      error stop 'Invalid extended drain state'
    end if
    if (values(3) < 0d0.or.values(5) < 0d0) error stop 'Negative original surface storage or perimeter'
  end subroutine

  subroutine unpack(values, adjustments)
    use MOD_grid, only: numnod
    use MOD_drain, only: nrlevs,wlp,wls,swst,wlstar,wetper,qdrd,qdrtot,wlsbak,qdrain,drainl,diffl,qdra,numadj
    real(8), intent(in) :: values(:)
    integer, intent(in) :: adjustments
    integer :: r
    r=nrlevs
    wlp=values(1);wls=values(2);swst=values(3);wlstar=values(4)
    wetper=values(5);qdrd=values(6);qdrtot=values(7);wlsbak=values(8:11)
    qdrain(1:r)=values(12:11+r);drainl(1:r)=values(12+r:11+2*r)
    diffl(1:r)=values(12+2*r:11+3*r)
    qdra(1:r,1:numnod)=reshape(values(12+3*r:),[r,numnod])
    numadj=adjustments
  end subroutine

  subroutine extended_drain_trial_begin()
    use MOD_drain, only: numadj, nrlevs, swst
    use MOD_integral, only: cqdrain
    use variables, only: t1900
    if (active) error stop 'Nested extended drain trial'
    call domain(saved_domain)
    call pack(saved_values)
    call validate(saved_values,numadj,saved_domain)
    if (.not.ieee_is_finite(t1900)) error stop 'Invalid extended drain trial clock'
    saved_clock=t1900;saved_adjustments=numadj;active=.true.
    branch_seen=.false.;branch_supply=0d0;branch_discharge=0d0
    ! The original Integral(2) has already performed its actual date resets.
    ! Capture its counters here, so January/reset boundaries remain original.
    if (window_active.and.origin_pending) then
      allocate(level_flux(nrlevs),original_level_origin(nrlevs))
      level_flux=0.0_real128;original_level_origin=cqdrain(1:nrlevs)
      stock_origin=swst;origin_pending=.false.
    end if
  end subroutine

  subroutine extended_drain_trial_end(rejected)
    use variables, only: t1900,dt,runots
    use MOD_drain, only: swsec,nrlevs,swst,qdrd,qdrtot,qdrain
    logical, intent(in) :: rejected
    integer :: current(8)
    if (.not.active) error stop 'Missing extended drain trial origin'
    call domain(current)
    if (any(current /= saved_domain).or.t1900 /= saved_clock) &
      error stop 'Changed extended drain trial origin'
    if (rejected) then
      call unpack(saved_values,saved_adjustments)
      if (window_active) rejected_steps=rejected_steps+1
    else if (window_active) then
      if (swsec==2.and..not.branch_seen) error stop 'Missing original simulated surfacewater flux'
      ! Accumulate actual original double products, in read-only wider sums.
      ! The original stock, flux and timestep assignments remain untouched.
      flux(1)=flux(1)+real(qdrd*dt,real128)
      flux(2)=flux(2)+real((qdrtot-qdrd)*dt,real128)
      flux(3)=flux(3)+real(runots,real128)
      if (swsec==2) then
        flux(4)=flux(4)+real(branch_supply*dt,real128)
        flux(5)=flux(5)+real(branch_discharge*dt,real128)
      else
        ! Prescribed WLS is an external volume constraint, analogous to a
        ! prescribed-head reaction. Record it explicitly; never change SWST.
        flux(6)=flux(6)+real(swst,real128)-real(saved_values(3),real128) &
                -real(qdrd*dt,real128)-real(runots,real128)
      end if
      level_flux=level_flux+real(qdrain(1:nrlevs)*dt,real128)
      accepted_steps=accepted_steps+1
    end if
    active=.false.
    deallocate(saved_values)
  end subroutine

  subroutine extended_drain_checkpoint(unit, restoring)
    use MOD_drain, only: numadj
    use variables, only: t1900
    integer, intent(in) :: unit
    logical, intent(in) :: restoring
    integer :: expected(8), header(8), copy(8), adjustments, adjustment_copy, trailer, ios, nvalues
    real(8) :: clock, clock_copy
    real(8), allocatable :: values(:), witness(:)
    if (active) error stop 'Cannot publish active extended drain trial'
    call domain(expected)
    nvalues=11+3*expected(3)+expected(3)*expected(2)
    allocate(values(nvalues),witness(nvalues))
    if (restoring) then
      read(unit,iostat=ios) header,copy,clock,clock_copy,adjustments,adjustment_copy,values,witness,trailer
      if (ios /= 0) error stop 'Incomplete extended drain native state'
    else
      header=expected;copy=header;clock=t1900;clock_copy=clock
      adjustments=numadj;adjustment_copy=adjustments
      call pack(values);witness=values;trailer=92+16*nvalues
    end if
    if (any(header /= expected).or.any(copy /= header).or.trailer /= 92+16*nvalues) &
      error stop 'Foreign extended drain native domain'
    if (.not.ieee_is_finite(clock).or.clock /= clock_copy.or.clock /= t1900) &
      error stop 'Foreign extended drain native clock'
    call validate(values,adjustments,expected)
    if (adjustments /= adjustment_copy.or.any(values /= witness)) &
      error stop 'Extended drain native state differs from duplicate witness'
    ! No original state changes until the complete typed candidate validates.
    if (restoring) then
      call unpack(values,adjustments)
    else
      write(unit) header,copy,clock,clock_copy,adjustments,adjustment_copy,values,witness,trailer
    end if
  end subroutine

  subroutine extended_drain_witness()
    use MOD_drain, only: numadj,nrlevs,swst
    use MOD_integral, only: iqdra,iruno,cqdrain
    use variables, only: t1900
    real(8), allocatable :: values(:)
    integer :: header(8)
    call domain(header);call pack(values);call validate(values,numadj,header)
    write(*,'(a,1x,es25.17e3,2(1x,i0),*(1x,es25.17e3))') &
      'HYBRID_EXTENDED_DRAIN_STATE',t1900,numadj,size(values),values
    if (window_active) then
      if (origin_pending.or.accepted_steps<1) error stop 'Empty extended drain accepted window'
      write(*,'(a,1x,es25.17e3,2(1x,i0),*(1x,es25.17e3))') &
        'HYBRID_EXTENDED_DRAIN_FLUX',t1900,accepted_steps,rejected_steps, &
        stock_origin,swst,real(flux,8),iqdra,iruno, &
        cqdrain(1:nrlevs)-original_level_origin,real(level_flux,8)
    end if
  end subroutine
end module
