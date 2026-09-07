program test_fci08_process_checkpoint
  use, intrinsic :: iso_fortran_env, only: real64
  use MOD_grid, only: numnod
  use MOD_swap_base, only: swhea, swsolu, swcrop, swirfix
  use variables
  use MOD_SoilTemperature, only: tsoil
  use MOD_solute_global, only: cml, ageml
  use MOD_Solute, only: cmsy
  use MOD_irrigation, only: schedule, flirrigate, dayfix, nirri
  use plant_interface
  use MOD_cropdevelopment
  use MOD_wofost
  use mod_transaction_reference, only: transaction_state_t
  use mod_b1_10_process_checkpoint
  implicit none
  type(b1_10_process_state_t) :: s, probe
  class(transaction_state_t), allocatable :: copy
  integer :: i

  swhea=1; swsolu=2; swcrop=1; swirfix=1; schedule=0; flirrigate=.false.
  croptype(1)=2; icrop=1; fl_cropemergence=.true.
  do i=1,numnod
    h(i)=i; theta(i)=10+i; hm1(i)=20+i; thetm1(i)=30+i
    tsoil(i)=40+i; cml(i)=50+i; cmsy(i)=60+i; ageml(i)=70+i
    lrv_node(i)=80+i; wroot_node(i)=90+i; wroot_node_top(i)=100+i
  end do
  pond=1; pondm1=2; gwl=3; gwlm1=4; volact=5; ldwet=6; spev=7; saev=8
  dayfix=9; nirri=10; rd=11; dvs=12; lai=13; tsum=14; sicact=15
  cumdens=1; cumdens_top=2
  s_act%marker=21; s_pot%marker=22; m_act%marker=23; m_pot%marker=24; vern=25; atmin7=26

  call capture_b1_10_process_state(s)
  if (.not. allocated(s%irrigation)) error stop 'fixed irrigation config must allocate state even when flirrigate=false'
  call s%clone(copy)

  h=-9; theta=-9; hm1=-9; thetm1=-9; tsoil=-9; cml=-9; cmsy=-9; ageml=-9
  dayfix=-9; nirri=-9; rd=-9; dvs=-9; lai=-9; tsum=-9; sicact=-9
  cumdens=-9; cumdens_top=-9; lrv_node=-9; wroot_node=-9; wroot_node_top=-9
  s_act%marker=-9; s_pot%marker=-9; m_act%marker=-9; m_pot%marker=-9; vern=-9; atmin7=-9

  call restore_b1_10_process_state(s)
  call chk(h(numnod),real(numnod,real64),'h')
  call chk(tsoil(numnod),40.0_real64+numnod,'tsoil')
  call chk(cml(numnod),50.0_real64+numnod,'cml')
  call chk(cmsy(numnod),60.0_real64+numnod,'cmsy')
  call chk(ageml(numnod),70.0_real64+numnod,'ageml')
  if(dayfix/=9 .or. nirri/=10) error stop 'irrigation process state'
  call chk(rd,11.0_real64,'rd'); call chk(s_act%marker,21.0_real64,'wofost')
  call chk(atmin7(7),26.0_real64,'atmin7')

  select type(c=>copy)
  type is(b1_10_process_state_t)
    if(.not.allocated(c%thermal) .or. .not.allocated(c%solute) .or. .not.allocated(c%irrigation) .or. &
       .not.allocated(c%crop) .or. .not.allocated(c%wofost)) error stop 'clone optional state'
    call chk(c%thermal%tsoil(numnod),40.0_real64+numnod,'clone thermal')
    call chk(c%wofost%s_act%marker,21.0_real64,'clone wofost')
  class default
    error stop 'clone dynamic type'
  end select

  ! WOFOST state must exist before emergence too; a rejected trial may cross emergence.
  fl_cropemergence=.false.; croptype(1)=2; icrop=1
  call capture_b1_10_process_state(probe)
  if (.not. allocated(probe%wofost)) error stop 'pre-emergence WOFOST continuation missing'

  ! Irrigation ownership follows configured capability, not today's event flag.
  swirfix=0; schedule=1; flirrigate=.false.
  call capture_b1_10_process_state(probe)
  if (.not. allocated(probe%irrigation)) error stop 'scheduled irrigation continuation missing'
  swirfix=0; schedule=0
  call capture_b1_10_process_state(probe)
  if (allocated(probe%irrigation)) error stop 'inactive irrigation must not consume persistent state'

  ! Optional process state must disappear when its physics is inactive.
  swhea=0; swsolu=0; swcrop=0
  call capture_b1_10_process_state(probe)
  if (allocated(probe%thermal) .or. allocated(probe%solute) .or. allocated(probe%crop) .or. &
      allocated(probe%wofost)) error stop 'inactive optional physics consumed persistent state'

  print *, 'FCI08_PROCESS_CHECKPOINT PASS'
contains
  subroutine chk(a,b,label)
    real(real64),intent(in)::a,b
    character(len=*),intent(in)::label
    if(abs(a-b)>1.e-12_real64) then
      print *,trim(label),a,b
      error stop 'FCI08 checkpoint comparison'
    end if
  end subroutine chk
end program test_fci08_process_checkpoint
