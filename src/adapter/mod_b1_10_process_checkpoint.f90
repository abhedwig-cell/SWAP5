module mod_b1_10_process_checkpoint
  use, intrinsic :: iso_fortran_env, only: real64
  use MOD_grid, only: numnod
  use MOD_swap_base, only: swhea, swsolu, swcrop, swirfix
  use mod_transaction_reference, only: transaction_state_t
  use mod_b1_10_water_checkpoint, only: b1_10_water_state_t, capture_b1_10_water_state, restore_b1_10_water_state
  use MOD_SoilTemperature, only: tsoil
  use MOD_solute_global, only: cml, ageml
  use MOD_Solute, only: cmsy
  use MOD_irrigation, only: schedule, dayfix, nirri
  use plant_interface, only: icrop, croptype, fl_start_croprotation, fl_start_cropemergence, fl_cropemergence, &
       fl_cropharvest, fl_cropharvestday, fl_cropisreset, cf, ch, vcover, siccap, sicact, siccaploss, &
       noddrz, rd, dvs, lai, tsum, wrt, wst, wlv, wso, dwrt, dwst, dwlv, &
       laipot, wrtpot, wstpot, wlvpot, wsopot, dwrtpot, dwstpot, dwlvpot, &
       dmhrv, dmloss, icut, tcut, dmhrvpot, dmlosspot, icutpot, tcutpot
  use MOD_cropdevelopment, only: fl_cropcalendar, fl_readcropfile, fl_prep, fl_sow, fl_germ, &
       delay_prep, delay_sow, tsumgerm, rdpot, cumdens, cumdens_top, lrv_node, wroot_node, wroot_node_top
  use MOD_wofost, only: wofost_states, agro_management, s_act, s_pot, m_act, m_pot, &
       vern, fl_anthesis, fl_vernalised, t_tsumcum, nofd, atmin7
  implicit none
  private

  type, public :: b1_10_thermal_state_t
    real(real64), allocatable :: tsoil(:)
  end type

  type, public :: b1_10_solute_state_t
    integer :: mode = 0
    real(real64), allocatable :: cml(:)
    real(real64), allocatable :: cmsy(:)
    real(real64), allocatable :: ageml(:)
  end type

  type, public :: b1_10_irrigation_state_t
    integer :: dayfix = 0
    integer :: nirri = 0
  end type

  ! Compact optional cross-call continuation for the B1.10 macropore route.
  ! This is physical/process continuation, not solver scratch or reporting history.
  type, public :: b1_10_macropore_continuation_t
    integer :: nstep = 0
  end type

  type, public :: b1_10_crop_common_state_t
    integer :: icrop = 0
    logical :: fl_start_croprotation = .false.
    logical :: fl_start_cropemergence = .false.
    logical :: fl_cropemergence = .false.
    logical :: fl_cropharvest = .false.
    logical :: fl_cropharvestday = .false.
    logical :: fl_cropisreset = .false.
    logical :: fl_cropcalendar = .false.
    logical :: fl_readcropfile = .false.
    logical :: fl_prep = .false.
    logical :: fl_sow = .false.
    logical :: fl_germ = .false.
    integer :: delay_prep = 0
    integer :: delay_sow = 0
    real(real64) :: tsumgerm = 0.0_real64
    real(real64) :: rdpot = 0.0_real64
    integer :: noddrz = 0
    real(real64) :: rd = 0.0_real64
    real(real64) :: dvs = 0.0_real64
    real(real64) :: lai = 0.0_real64
    real(real64) :: tsum = 0.0_real64
    real(real64) :: cf = 0.0_real64
    real(real64) :: ch = 0.0_real64
    real(real64) :: vcover = 0.0_real64
    real(real64) :: siccap = 0.0_real64
    real(real64) :: sicact = 0.0_real64
    real(real64) :: siccaploss = 0.0_real64
    real(real64) :: wrt = 0.0_real64, wst = 0.0_real64, wlv = 0.0_real64, wso = 0.0_real64
    real(real64) :: dwrt = 0.0_real64, dwst = 0.0_real64, dwlv = 0.0_real64
    real(real64) :: laipot = 0.0_real64
    real(real64) :: wrtpot = 0.0_real64, wstpot = 0.0_real64, wlvpot = 0.0_real64, wsopot = 0.0_real64
    real(real64) :: dwrtpot = 0.0_real64, dwstpot = 0.0_real64, dwlvpot = 0.0_real64
    real(real64) :: dmhrv = 0.0_real64, dmloss = 0.0_real64
    real(real64) :: dmhrvpot = 0.0_real64, dmlosspot = 0.0_real64
    integer :: icut = 0, tcut = 0, icutpot = 0, tcutpot = 0
    real(real64), allocatable :: cumdens(:)
    real(real64), allocatable :: cumdens_top(:)
    real(real64), allocatable :: lrv_node(:)
    real(real64), allocatable :: wroot_node(:)
    real(real64), allocatable :: wroot_node_top(:)
  end type

  type, public :: b1_10_wofost_state_t
    type(wofost_states) :: s_act
    type(wofost_states) :: s_pot
    type(agro_management) :: m_act
    type(agro_management) :: m_pot
    real(real64) :: vern = 0.0_real64
    logical :: fl_anthesis = .false.
    logical :: fl_vernalised = .false.
    integer :: t_tsumcum = 0
    integer :: nofd = 0
    real(real64) :: atmin7(7) = 0.0_real64
  end type

  type, extends(b1_10_water_state_t), public :: b1_10_process_state_t
    type(b1_10_thermal_state_t), allocatable :: thermal
    type(b1_10_solute_state_t), allocatable :: solute
    type(b1_10_irrigation_state_t), allocatable :: irrigation
    type(b1_10_crop_common_state_t), allocatable :: crop
    type(b1_10_wofost_state_t), allocatable :: wofost
    type(b1_10_macropore_continuation_t), allocatable :: macropore
  contains
    procedure :: clone => b1_10_process_clone
  end type

  public :: capture_b1_10_process_state, restore_b1_10_process_state
  public :: bind_b1_10_macropore_continuation, read_b1_10_macropore_continuation
  public :: clear_b1_10_macropore_continuation, b1_10_macropore_continuation_complete

contains

  subroutine capture_b1_10_process_state(state)
    type(b1_10_process_state_t), intent(inout) :: state
    integer :: nc, nt
    call capture_b1_10_water_state(state%b1_10_water_state_t)

    if (swhea > 0) then
      if (.not. allocated(state%thermal)) allocate(state%thermal)
      state%thermal%tsoil = tsoil(1:numnod)
    else if (allocated(state%thermal)) then
      deallocate(state%thermal)
    end if

    if (swsolu > 0) then
      if (.not. allocated(state%solute)) allocate(state%solute)
      state%solute%mode = swsolu
      state%solute%cml = cml(1:numnod)
      state%solute%cmsy = cmsy(1:numnod)
      if (swsolu == 2) then
        state%solute%ageml = ageml(1:numnod)
      else if (allocated(state%solute%ageml)) then
        deallocate(state%solute%ageml)
      end if
    else if (allocated(state%solute)) then
      deallocate(state%solute)
    end if

    if (swirfix == 1 .or. schedule == 1) then
      if (.not. allocated(state%irrigation)) allocate(state%irrigation)
      state%irrigation%dayfix = dayfix
      state%irrigation%nirri = nirri
    else if (allocated(state%irrigation)) then
      deallocate(state%irrigation)
    end if

    if (swcrop == 1) then
      if (.not. allocated(state%crop)) allocate(state%crop)
      state%crop%icrop = icrop
      state%crop%fl_start_croprotation = fl_start_croprotation
      state%crop%fl_start_cropemergence = fl_start_cropemergence
      state%crop%fl_cropemergence = fl_cropemergence
      state%crop%fl_cropharvest = fl_cropharvest
      state%crop%fl_cropharvestday = fl_cropharvestday
      state%crop%fl_cropisreset = fl_cropisreset
      state%crop%fl_cropcalendar = fl_cropcalendar
      state%crop%fl_readcropfile = fl_readcropfile
      state%crop%fl_prep = fl_prep
      state%crop%fl_sow = fl_sow
      state%crop%fl_germ = fl_germ
      state%crop%delay_prep = delay_prep
      state%crop%delay_sow = delay_sow
      state%crop%tsumgerm = tsumgerm
      state%crop%rdpot = rdpot
      state%crop%noddrz = noddrz
      state%crop%rd = rd; state%crop%dvs = dvs; state%crop%lai = lai; state%crop%tsum = tsum
      state%crop%cf = cf; state%crop%ch = ch; state%crop%vcover = vcover
      state%crop%siccap = siccap; state%crop%sicact = sicact; state%crop%siccaploss = siccaploss
      state%crop%wrt=wrt; state%crop%wst=wst; state%crop%wlv=wlv; state%crop%wso=wso
      state%crop%dwrt=dwrt; state%crop%dwst=dwst; state%crop%dwlv=dwlv
      state%crop%laipot=laipot; state%crop%wrtpot=wrtpot; state%crop%wstpot=wstpot; state%crop%wlvpot=wlvpot; state%crop%wsopot=wsopot
      state%crop%dwrtpot=dwrtpot; state%crop%dwstpot=dwstpot; state%crop%dwlvpot=dwlvpot
      state%crop%dmhrv=dmhrv; state%crop%dmloss=dmloss; state%crop%icut=icut; state%crop%tcut=tcut
      state%crop%dmhrvpot=dmhrvpot; state%crop%dmlosspot=dmlosspot; state%crop%icutpot=icutpot; state%crop%tcutpot=tcutpot
      nc = min(size(cumdens), 2*(numnod+1))
      nt = min(size(cumdens_top), numnod+1)
      state%crop%cumdens = cumdens(1:nc)
      state%crop%cumdens_top = cumdens_top(1:nt)
      state%crop%lrv_node = lrv_node(1:numnod)
      state%crop%wroot_node = wroot_node(1:numnod)
      state%crop%wroot_node_top = wroot_node_top(1:numnod)

      if (icrop >= 1 .and. icrop <= size(croptype) .and. croptype(icrop) == 2) then
        if (.not. allocated(state%wofost)) allocate(state%wofost)
        state%wofost%s_act=s_act; state%wofost%s_pot=s_pot
        state%wofost%m_act=m_act; state%wofost%m_pot=m_pot
        state%wofost%vern=vern; state%wofost%fl_anthesis=fl_anthesis; state%wofost%fl_vernalised=fl_vernalised
        state%wofost%t_tsumcum=t_tsumcum; state%wofost%nofd=nofd; state%wofost%atmin7=atmin7
      else if (allocated(state%wofost)) then
        deallocate(state%wofost)
      end if
    else
      if (allocated(state%crop)) deallocate(state%crop)
      if (allocated(state%wofost)) deallocate(state%wofost)
    end if
  end subroutine

  subroutine restore_b1_10_process_state(state)
    type(b1_10_process_state_t), intent(in) :: state
    integer :: nc, nt
    call restore_b1_10_water_state(state%b1_10_water_state_t)

    if ((swhea > 0) .neqv. allocated(state%thermal)) error stop 'B1.10 process state: thermal/config mismatch'
    if ((swsolu > 0) .neqv. allocated(state%solute)) error stop 'B1.10 process state: solute/config mismatch'
    if ((swirfix == 1 .or. schedule == 1) .neqv. allocated(state%irrigation)) &
      error stop 'B1.10 process state: irrigation/config mismatch'
    if ((swcrop == 1) .neqv. allocated(state%crop)) error stop 'B1.10 process state: crop/config mismatch'
    if (allocated(state%solute)) then
      if (state%solute%mode /= swsolu) error stop 'B1.10 process state: solute mode mismatch'
    end if

    if (allocated(state%thermal)) then
      if (size(state%thermal%tsoil) /= numnod) error stop 'B1.10 process state: thermal shape mismatch'
      tsoil(1:numnod)=state%thermal%tsoil
    end if
    if (allocated(state%solute)) then
      if (size(state%solute%cml) /= numnod .or. size(state%solute%cmsy) /= numnod) error stop 'B1.10 process state: solute shape mismatch'
      cml(1:numnod)=state%solute%cml; cmsy(1:numnod)=state%solute%cmsy
      if (state%solute%mode == 2) then
        if (.not. allocated(state%solute%ageml) .or. size(state%solute%ageml)/=numnod) error stop 'B1.10 process state: age tracer shape mismatch'
        ageml(1:numnod)=state%solute%ageml
      end if
    end if
    if (allocated(state%irrigation)) then
      dayfix=state%irrigation%dayfix; nirri=state%irrigation%nirri
    end if
    if (allocated(state%crop)) then
      icrop=state%crop%icrop
      fl_start_croprotation=state%crop%fl_start_croprotation
      fl_start_cropemergence=state%crop%fl_start_cropemergence
      fl_cropemergence=state%crop%fl_cropemergence
      fl_cropharvest=state%crop%fl_cropharvest
      fl_cropharvestday=state%crop%fl_cropharvestday
      fl_cropisreset=state%crop%fl_cropisreset
      fl_cropcalendar=state%crop%fl_cropcalendar
      fl_readcropfile=state%crop%fl_readcropfile
      fl_prep=state%crop%fl_prep; fl_sow=state%crop%fl_sow; fl_germ=state%crop%fl_germ
      delay_prep=state%crop%delay_prep; delay_sow=state%crop%delay_sow; tsumgerm=state%crop%tsumgerm
      rdpot=state%crop%rdpot; noddrz=state%crop%noddrz; rd=state%crop%rd; dvs=state%crop%dvs; lai=state%crop%lai; tsum=state%crop%tsum
      cf=state%crop%cf; ch=state%crop%ch; vcover=state%crop%vcover
      siccap=state%crop%siccap; sicact=state%crop%sicact; siccaploss=state%crop%siccaploss
      wrt=state%crop%wrt; wst=state%crop%wst; wlv=state%crop%wlv; wso=state%crop%wso
      dwrt=state%crop%dwrt; dwst=state%crop%dwst; dwlv=state%crop%dwlv
      laipot=state%crop%laipot; wrtpot=state%crop%wrtpot; wstpot=state%crop%wstpot; wlvpot=state%crop%wlvpot; wsopot=state%crop%wsopot
      dwrtpot=state%crop%dwrtpot; dwstpot=state%crop%dwstpot; dwlvpot=state%crop%dwlvpot
      dmhrv=state%crop%dmhrv; dmloss=state%crop%dmloss; icut=state%crop%icut; tcut=state%crop%tcut
      dmhrvpot=state%crop%dmhrvpot; dmlosspot=state%crop%dmlosspot; icutpot=state%crop%icutpot; tcutpot=state%crop%tcutpot
      nc=size(state%crop%cumdens); nt=size(state%crop%cumdens_top)
      if (nc > size(cumdens) .or. nt > size(cumdens_top) .or. size(state%crop%lrv_node)/=numnod) error stop 'B1.10 process state: crop shape mismatch'
      cumdens=0.0_real64; cumdens(1:nc)=state%crop%cumdens
      cumdens_top=0.0_real64; cumdens_top(1:nt)=state%crop%cumdens_top
      lrv_node=0.0_real64; lrv_node(1:numnod)=state%crop%lrv_node
      wroot_node=0.0_real64; wroot_node(1:numnod)=state%crop%wroot_node
      wroot_node_top=0.0_real64; wroot_node_top(1:numnod)=state%crop%wroot_node_top
    end if
    if (allocated(state%wofost)) then
      s_act=state%wofost%s_act; s_pot=state%wofost%s_pot
      m_act=state%wofost%m_act; m_pot=state%wofost%m_pot
      vern=state%wofost%vern; fl_anthesis=state%wofost%fl_anthesis; fl_vernalised=state%wofost%fl_vernalised
      t_tsumcum=state%wofost%t_tsumcum; nofd=state%wofost%nofd; atmin7=state%wofost%atmin7
    end if
  end subroutine

  subroutine bind_b1_10_macropore_continuation(state, nstep, accepted)
    type(b1_10_process_state_t), intent(inout) :: state
    integer, intent(in) :: nstep
    logical, intent(out) :: accepted

    accepted = .false.
    if (nstep < 0) return
    if (.not. allocated(state%macropore)) allocate(state%macropore)
    state%macropore%nstep = nstep
    accepted = .true.
  end subroutine bind_b1_10_macropore_continuation

  subroutine read_b1_10_macropore_continuation(state, nstep, available)
    type(b1_10_process_state_t), intent(in) :: state
    integer, intent(out) :: nstep
    logical, intent(out) :: available

    available = allocated(state%macropore)
    if (available) then
      nstep = state%macropore%nstep
    else
      nstep = 0
    end if
  end subroutine read_b1_10_macropore_continuation

  subroutine clear_b1_10_macropore_continuation(state)
    type(b1_10_process_state_t), intent(inout) :: state
    if (allocated(state%macropore)) deallocate(state%macropore)
  end subroutine clear_b1_10_macropore_continuation

  logical function b1_10_macropore_continuation_complete(state, macropore_active) result(complete)
    type(b1_10_process_state_t), intent(in) :: state
    logical, intent(in) :: macropore_active

    if (macropore_active) then
      complete = allocated(state%macropore)
      if (complete) complete = state%macropore%nstep >= 0
    else
      complete = .not. allocated(state%macropore)
    end if
  end function b1_10_macropore_continuation_complete

  subroutine b1_10_process_clone(self, copy)
    class(b1_10_process_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy
    allocate(b1_10_process_state_t :: copy)
    select type (target => copy)
    type is (b1_10_process_state_t)
      target%b1_10_water_state_t = self%b1_10_water_state_t
      target%thermal = self%thermal
      target%solute = self%solute
      target%irrigation = self%irrigation
      target%crop = self%crop
      target%wofost = self%wofost
      target%macropore = self%macropore
    class default
      error stop 'B1.10 process state: clone allocation failure'
    end select
  end subroutine
end module mod_b1_10_process_checkpoint
