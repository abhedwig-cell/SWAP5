program test_ppa_wu05a3_definecompart_source_oracle
  use, intrinsic :: iso_fortran_env, only: real64, int32
  use mod_ppa_wu05a3_definecompart
  implicit none
  call check_split_case()
  call check_merge_case()
  call check_grid_alignment_case()
  call check_invalid_case()
  print '(A)', 'PPA_WU05A3_DEFINECOMPART_SOURCE_ORACLE=PASS'
  print '(A)', 'PPA_WU05A3_DEFINECOMPART_BREAKPOINT_SPLIT_AND_IDENTITY=PASS'
  print '(A)', 'PPA_WU05A3_DEFINECOMPART_NEAR_BREAKPOINT_MERGE=PASS'
  print '(A)', 'PPA_WU05A3_DEFINECOMPART_EXISTING_GRID_ALIGNMENT=PASS'
  print '(A)', 'PPA_WU05A3_DEFINECOMPART_INVALID_DOMAIN_FAIL_CLOSED=PASS'
contains
  subroutine require(ok, code)
    logical, intent(in) :: ok
    integer, intent(in) :: code
    if (.not. ok) then
      write(*,'(A,I0)') 'PPA_WU05A3_DEFINECOMPART_FAIL=', code
      error stop 1
    end if
  end subroutine

  subroutine init_grid(bot, top)
    real(real64), intent(out) :: bot(8), top(8)
    bot = 0.0_real64
    top = 0.0_real64
    top(1:4) = [0.0_real64, -10.0_real64, -20.0_real64, -30.0_real64]
    bot(1:4) = [-10.0_real64, -20.0_real64, -30.0_real64, -40.0_real64]
  end subroutine

  subroutine check_split_case()
    real(real64) :: bot(8), top(8), ah, ic, st, sp, zsp
    integer(int32) :: extra, ids(8), status
    call init_grid(bot, top)
    ah=-15.0_real64; ic=-25.0_real64; st=-35.0_real64; sp=0.5_real64
    call ppa_wu05a3_definecompart(4_int32,bot,top,ah,ic,st,sp,2.0_real64,0_int32,extra,ids,zsp,status)
    call require(status==PPA_WU05A3_DEFINECOMPART_OK,1)
    call require(extra==3,2)
    call require(maxval(abs(top(1:7)-[0.0_real64,-10.0_real64,-15.0_real64, &
        -20.0_real64,-25.0_real64,-30.0_real64,-35.0_real64]))<1.0e-12_real64,3)
    call require(maxval(abs(bot(1:7)-[-10.0_real64,-15.0_real64,-20.0_real64, &
        -25.0_real64,-30.0_real64,-35.0_real64,-40.0_real64]))<1.0e-12_real64,4)
    call require(all(ids(1:7)==[1_int32,2_int32,2_int32,3_int32,3_int32,4_int32,4_int32]),5)
    call require(abs(zsp+20.0_real64)<1.0e-12_real64 .and. abs(sp-0.5_real64)<1.0e-12_real64,6)
  end subroutine

  subroutine check_merge_case()
    real(real64) :: bot(8), top(8), ah, ic, st, sp, zsp
    integer(int32) :: extra, ids(8), status
    call init_grid(bot, top)
    ah=-15.0_real64; ic=-15.05_real64; st=-35.0_real64; sp=0.5_real64
    call ppa_wu05a3_definecompart(4_int32,bot,top,ah,ic,st,sp,2.0_real64,0_int32,extra,ids,zsp,status)
    call require(status==PPA_WU05A3_DEFINECOMPART_OK,7)
    call require(extra==2 .and. abs(ah-ic)<1.0e-12_real64 .and. abs(zsp-ah)<1.0e-12_real64,8)
    call require(maxval(abs(top(1:6)-[0.0_real64,-10.0_real64,-15.0_real64, &
        -20.0_real64,-30.0_real64,-35.0_real64]))<1.0e-12_real64,9)
    call require(maxval(abs(bot(1:6)-[-10.0_real64,-15.0_real64,-20.0_real64, &
        -30.0_real64,-35.0_real64,-40.0_real64]))<1.0e-12_real64,10)
    call require(all(ids(1:6)==[1_int32,2_int32,2_int32,3_int32,4_int32,4_int32]),11)
  end subroutine

  subroutine check_grid_alignment_case()
    real(real64) :: bot(8), top(8), ah, ic, st, sp, zsp
    integer(int32) :: extra, ids(8), status
    call init_grid(bot, top)
    ah=-10.04_real64; ic=-19.96_real64; st=-29.95_real64; sp=1.0_real64
    call ppa_wu05a3_definecompart(4_int32,bot,top,ah,ic,st,sp,2.0_real64,0_int32,extra,ids,zsp,status)
    call require(status==PPA_WU05A3_DEFINECOMPART_OK,12)
    call require(abs(ah+10.0_real64)<1.0e-12_real64 .and. &
        abs(ic+20.0_real64)<1.0e-12_real64 .and. &
        abs(st+30.0_real64)<1.0e-12_real64,13)
    call require(extra==0 .and. all(ids(1:4)==[1_int32,2_int32,3_int32,4_int32]),14)
    call require(maxval(abs(top(1:4)-[0.0_real64,-10.0_real64,-20.0_real64,-30.0_real64]))<1.0e-12_real64,15)
    call require(maxval(abs(bot(1:4)-[-10.0_real64,-20.0_real64,-30.0_real64,-40.0_real64]))<1.0e-12_real64,16)
  end subroutine

  subroutine check_invalid_case()
    real(real64) :: bot(4), top(4), ah, ic, st, sp, zsp
    integer(int32) :: extra, ids(4), status
    bot=0.0_real64; top=0.0_real64
    ah=-1.0_real64; ic=-2.0_real64; st=-3.0_real64; sp=0.5_real64
    call ppa_wu05a3_definecompart(1_int32,bot,top,ah,ic,st,sp,2.0_real64,0_int32,extra,ids,zsp,status)
    call require(status==PPA_WU05A3_DEFINECOMPART_INVALID,17)
    call require(extra==0 .and. all(ids==0),18)
  end subroutine
end program test_ppa_wu05a3_definecompart_source_oracle
