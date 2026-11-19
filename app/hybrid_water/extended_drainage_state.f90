! Experimental component: original MOD_drain transaction and native carry.
! Public SWDRA2 admission is separate. No process equation is implemented here.
module hybrid_extended_drainage_state
  use ieee_arithmetic, only: ieee_is_finite
  implicit none
  private
  public :: extended_drain_trial_begin, extended_drain_trial_end
  public :: extended_drain_checkpoint, extended_drain_witness
  logical, save :: active = .false.
  integer, save :: saved_domain(8), saved_adjustments
  real(8), save :: saved_clock
  real(8), allocatable, save :: saved_values(:)
contains
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
    real(8), intent(in) :: values(:)
    integer, intent(in) :: adjustments, header(8)
    if (size(values) /= 11+3*header(3)+header(3)*header(2)) &
      error stop 'Incomplete extended drain state'
    if (.not.all(ieee_is_finite(values)).or.adjustments < 0) error stop 'Invalid extended drain state'
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
    use MOD_drain, only: numadj
    use variables, only: t1900
    if (active) error stop 'Nested extended drain trial'
    call domain(saved_domain)
    call pack(saved_values)
    call validate(saved_values,numadj,saved_domain)
    if (.not.ieee_is_finite(t1900)) error stop 'Invalid extended drain trial clock'
    saved_clock=t1900;saved_adjustments=numadj;active=.true.
  end subroutine

  subroutine extended_drain_trial_end(rejected)
    use variables, only: t1900
    logical, intent(in) :: rejected
    integer :: current(8)
    if (.not.active) error stop 'Missing extended drain trial origin'
    call domain(current)
    if (any(current /= saved_domain).or.t1900 /= saved_clock) &
      error stop 'Changed extended drain trial origin'
    if (rejected) call unpack(saved_values,saved_adjustments)
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
    use MOD_drain, only: numadj
    use variables, only: t1900
    real(8), allocatable :: values(:)
    integer :: header(8)
    call domain(header);call pack(values);call validate(values,numadj,header)
    write(*,'(a,1x,es25.17e3,2(1x,i0),*(1x,es25.17e3))') &
      'HYBRID_EXTENDED_DRAIN_STATE',t1900,numadj,size(values),values
  end subroutine
end module
