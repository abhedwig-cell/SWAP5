program test_fpe_elastic04_provider_identity
  use, intrinsic :: iso_fortran_env, only: real64
  use MOD_grid, only: numnod
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_fpe_elastic01_provider, only: fpe_elastic01_provider_t, bind_fpe_elastic01_provider
  use mod_fpe_elastic04_typed_provider, only: fpe_elastic04_material_config_t, fpe_elastic04_provider_t, &
       bind_fpe_elastic04_provider
  implicit none
  type(b110_default_mvg_parameters_t),target :: hp
  type(b110_default_mvg_provider_t) :: base
  type(fpe_elastic01_provider_t) :: legacy
  type(fpe_elastic04_material_config_t),target :: material
  type(fpe_elastic04_provider_t) :: typed
  real(real64),allocatable :: c(:,:),h(:),tb(:),kb(:),cb(:),db(:),tl(:),kl(:),cl(:),dl(:),tt(:),kt(:),ct(:),dt(:)
  real(real64)::tr,ts,alpha,nvg,ksat,lambda,elas,mm
  integer::i
  call rr(1,tr);call rr(2,ts);call rr(3,alpha);call rr(4,nvg);call rr(5,ksat);call rr(6,lambda);call rr(7,elas)
  allocate(c(24,numnod),h(numnod),tb(numnod),kb(numnod),cb(numnod),db(numnod),tl(numnod),kl(numnod),cl(numnod),dl(numnod),tt(numnod),kt(numnod),ct(numnod),dt(numnod))
  c=0.0_real64;mm=1.0_real64-1.0_real64/nvg
  do i=1,numnod
    c(1,i)=tr;c(2,i)=ts;c(3,i)=ksat;c(4,i)=alpha;c(5,i)=lambda;c(6,i)=nvg;c(7,i)=mm
    c(8,i)=alpha;c(9,i)=0.0_real64;c(10,i)=ksat;c(11,i)=0.999_real64;c(12,i)=0.99_real64*ksat
    c(22,i)=-1.0e6_real64;c(23,i)=1.0e-12_real64;c(24,i)=elas
  end do
  call initialize_b110_default_mvg_parameters(hp,c)
  h=[(-20.0_real64,-20.0_real64,i=1,numnod)]
  do i=1,numnod
    select case(mod(i-1,8))
    case(0);h(i)=-20.0_real64
    case(1);h(i)=-1.0_real64
    case(2);h(i)=-0.01_real64
    case(3);h(i)=-0.001_real64
    case(4);h(i)=0.0_real64
    case(5);h(i)=0.1_real64
    case(6);h(i)=1.0_real64
    case default;h(i)=100.0_real64
    end select
  end do

  call bind_b110_default_mvg_provider(base,hp,0.01_real64)
  material%elastic_storage_active=.false.
  call bind_fpe_elastic04_provider(typed,hp,material,0.01_real64)
  call base%evaluate(h,tb,kb,cb,db)
  call typed%evaluate(h,tt,kt,ct,dt)
  call req(all(tb==tt).and.all(kb==kt).and.all(cb==ct).and.all(db==dt),'inactive not bit-identical')

  material%elastic_storage_active=.true.;allocate(material%specific_elastic_storage(numnod));material%specific_elastic_storage=elas
  call bind_fpe_elastic04_provider(typed,hp,material,0.01_real64)
  call bind_fpe_elastic01_provider(legacy,hp,0.01_real64)
  call typed%evaluate(h,tt,kt,ct,dt);call legacy%evaluate(h,tl,kl,cl,dl)
  call req(all(tt==tl).and.all(kt==kl).and.all(ct==cl).and.all(dt==dl),'active legacy identity')

  do i=1,numnod
    material%specific_elastic_storage(i)=elas*(0.5_real64+real(i,real64)/real(numnod,real64))
  end do
  call bind_fpe_elastic04_provider(typed,hp,material,0.01_real64)
  h=2.0_real64;call typed%evaluate(h,tt,kt,ct,dt)
  do i=1,numnod
    call req(abs(tt(i)-(ts+2.0_real64*material%specific_elastic_storage(i)))<=1e-14_real64,'heterogeneous theta')
    call req(ct(i)==material%specific_elastic_storage(i),'heterogeneous capacity')
  end do
  write(*,'(A)')'F_PE_ELASTIC04_PROVIDER=PASS'
contains
  subroutine rr(k,x);integer,intent(in)::k;real(real64),intent(out)::x;character(len=64)::s;call get_command_argument(k,s);read(s,*)x;end subroutine
  subroutine req(ok,msg);logical,intent(in)::ok;character(len=*),intent(in)::msg;if(.not.ok)then;write(*,'(A,1X,A)')'F_PE_ELASTIC04_FAIL',trim(msg);error stop 1;end if;end subroutine
end program
