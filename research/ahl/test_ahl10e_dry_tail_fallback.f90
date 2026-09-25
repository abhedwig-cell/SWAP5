program test_ahl10e_dry_tail_fallback
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_ahl09_dc_provider, only: ahl09_dc_provider_t, bind_ahl09_dc_provider
  implicit none
  real(real64), parameter :: dt=0.25_real64
  type(b110_default_mvg_parameters_t), target :: hp
  type(b110_default_mvg_provider_t) :: analytical
  type(ahl09_dc_provider_t) :: lookup
  real(real64), allocatable :: cofgen(:,:)
  real(real64) :: h(1),wa(1),ka(1),ca(1),da(1),wl(1),kl(1),cl(1),dl(1)
  character(len=512) :: table_path
  logical :: valid

  call get_command_argument(1,table_path)
  if(len_trim(table_path)==0) error stop 'usage: test TABLE_PATH'

  allocate(cofgen(24,1));cofgen=0.0_real64
  cofgen(1,1)=0.01_real64
  cofgen(2,1)=0.336701_real64
  cofgen(3,1)=17.418504_real64
  cofgen(4,1)=0.030304_real64
  cofgen(5,1)=0.0736_real64
  cofgen(6,1)=2.887502_real64
  cofgen(7,1)=1.0_real64-1.0_real64/cofgen(6,1)
  cofgen(8,1)=cofgen(4,1)
  cofgen(9,1)=0.0_real64
  cofgen(10,1)=cofgen(3,1)
  cofgen(11,1)=0.999_real64
  cofgen(12,1)=0.99_real64*cofgen(3,1)
  cofgen(22,1)=-1.0e6_real64
  cofgen(23,1)=1.0e-12_real64

  call initialize_b110_default_mvg_parameters(hp,cofgen)
  call bind_b110_default_mvg_provider(analytical,hp,dt)
  call bind_ahl09_dc_provider(lookup,hp,dt,trim(table_path),valid)
  if(.not.valid) error stop 'lookup bind failed'

  h(1)=-5.0e5_real64
  call analytical%evaluate(h,wa,ka,ca,da)
  call lookup%evaluate(h,wl,kl,cl,dl)
  call require(abs(wl(1)-wa(1))<=1.0e-15_real64,'tail theta analytical fallback')
  call require(abs(cl(1)-ca(1))<=1.0e-18_real64,'tail C analytical fallback')
  call require(abs(kl(1)-ka(1))<=max(1.0e-30_real64,abs(ka(1))*1.0e-13_real64),'tail K analytical fallback')

  h(1)=-2.0e5_real64
  call lookup%evaluate(h,wl,kl,cl,dl)
  call require(wl(1)>0.0_real64 .and. cl(1)>0.0_real64 .and. kl(1)>0.0_real64,'represented-domain finite positive hydraulics')

  write(*,'(A)') 'AHL10E_O05_DRY_TAIL_ANALYTICAL_FALLBACK=PASS'
contains
  subroutine require(ok,msg)
    logical,intent(in)::ok
    character(len=*),intent(in)::msg
    if(.not.ok)then
      write(*,'(A,1X,A)')'AHL10E_FAIL',trim(msg)
      error stop 1
    end if
  end subroutine require
end program test_ahl10e_dry_tail_fallback
