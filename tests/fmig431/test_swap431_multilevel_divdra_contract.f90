! Calls original B1.11 DIVDRA unedited and the production process/binder.
program multilevel_contract
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_value,ieee_quiet_nan,ieee_positive_inf
  use MOD_grid, only: dz,zbotcp,layer
  use MOD_swap_base, only: swfrost
  use MOD_drain, only: nrlevs,cofani,Lspacing,qdrain,qdra,DIVDRA
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_drainage_spatial_distribution
  use mod_fmr_divdra_runtime_binding
  implicit none
  type(drainage_distribution_parameters_t)::p(3),bad(3)
  type(process_hydraulic_view_t)::v
  type(drainage_multilevel_diagnostics_t)::d
  type(fmr_divdra_multilevel_binding_diagnostics_t)::b
  real(real64),allocatable::flux(:,:),bound(:,:)
  real(real64)::k(8),qs(3),gw(7),rates(3,9),space(3,5),maxerr,maxclosure,expected,depth
  integer::grid,geometry,water,forcing,i,j,ncases
  swfrost=0;maxerr=0;maxclosure=0;ncases=0
  rates(:,1)=[.003d0,.002d0,.001d0];rates(:,2)=-rates(:,1)
  rates(:,3)=[.003d0,-.002d0,.001d0];rates(:,4)=[0.d0,-.002d0,.002d0]
  rates(:,5)=[.003d0,0.d0,0.d0];rates(:,6)=[0.d0,0.d0,-.001d0]
  rates(:,7)=0;rates(:,8)=[.003d0,-.003d0,0.d0];rates(:,9)=[1.0001d-10,-2.d-10,4.d-10]
  space(:,1)=[40.d0,12.d0,4.d0];space(:,2)=[4.d0,40.d0,12.d0]
  space(:,3)=[8.d0,8.d0,8.d0];space(:,4)=[.5d0,2.d0,1.d0];space(:,5)=[100.d0,200.d0,150.d0]
  do grid=1,3
    dz=1.d0;cofani=1.d0;k=2.d0
    if(grid==2)then
      dz=[.25d0,.75d0,1.5d0,.5d0,2.d0,.25d0,1.25d0,1.5d0]
      cofani=[.4d0,3.d0];k=[1.d0,4.d0,.2d0,2.d0,8.d0,.7d0,3.d0,1.3d0]
    else if(grid==3)then
      cofani=[2.d0,.6d0];k=[.3d0,2.d0,4.d0,1.d0,.8d0,5.d0,.6d0,2.2d0]
    end if
    depth=0
    do i=1,8
      depth=depth+dz(i);zbotcp(i)=-depth
    end do
    gw=[.2d0,0.d0,-.15d0,zbotcp(2),zbotcp(2)-.5d-10,zbotcp(2)-2.d-10,-depth+.1d0]
    do nrlevs=2,3
    do geometry=1,5
      Lspacing=space(:,geometry)
      do i=1,3
        p(i)%active_nodes=8;p(i)%dz=dz;p(i)%zbotcp=zbotcp;p(i)%saturated_conductivity=k
        p(i)%horizontal_anisotropy_factor=cofani(layer);p(i)%drain_spacing=Lspacing(i)
      end do
      do water=1,7
        v%groundwater_level=gw(water)
        do forcing=1,9
          qs=rates(:,forcing);qdrain=qs
          call DIVDRA(k,v%groundwater_level)
          call distribute_multilevel_signed_divdra(p(:nrlevs),v,qs(:nrlevs),flux,d)
          call check(d%status==DRAIN_DIST_OK.and.d%evaluated,'process success')
          call check(d%active_levels==count(abs(qs(:nrlevs))>1.d-10),'active level count')
          maxerr=max(maxerr,maxval(abs(flux-qdra(:nrlevs,:))))
          call check(maxval(abs(flux-qdra(:nrlevs,:)))<1.d-14,'original reference nodal partition')
          do j=1,nrlevs
            maxclosure=max(maxclosure,abs(sum(flux(j,:))-qs(j)))
            call check(abs(sum(flux(j,:))-qs(j))<1.d-14,'per-level scalar closure')
          end do
          if(allocated(bound))deallocate(bound)
          call fmr_bind_multilevel_signed_divdra(p(:nrlevs),v,qs(:nrlevs),bound,b)
          call check(b%status==FMR_DIVDRA_BIND_OK.and.b%published,'binder success')
          call check(all(bound==flux).and.all(b%authoritative_scalar_transfer==qs(:nrlevs)),'no second partition')
          ncases=ncases+1
        end do
      end do
    end do
    end do
  end do
  ! Independent uniform-profile interacting oracle: KD1=16, KD2=16*.028/.148,
  ! KD3=16*.004/.148, with L=[40,12,4], q=[.003,.002,.001].
  dz=1;cofani=1;k=2;v%groundwater_level=0
  do i=1,3
    p(i)%dz=dz;p(i)%zbotcp=[-1.d0,-2.d0,-3.d0,-4.d0,-5.d0,-6.d0,-7.d0,-8.d0]
    p(i)%saturated_conductivity=k;p(i)%horizontal_anisotropy_factor=1;p(i)%drain_spacing=space(i,1)
  end do
  qs=rates(:,1)
  call distribute_multilevel_signed_divdra(p,v,qs,flux,d)
  call check(d%status==DRAIN_DIST_OK,'literal success')
  ! cumulative q*L=[.148,.028,.004], d1=8, d2=8*.028/.148, d3=8*.004/.148
  do i=1,3
    select case(i)
    case(1);depth=8.d0
    case(2);depth=8.d0*.028d0/.148d0
    case(3);depth=8.d0*.004d0/.148d0
    end select
    call check(abs(d%discharge_layer_bottom_depth(i)-depth)<1.d-14,'literal layer depth')
    do j=1,8
      expected=qs(i)*max(0.d0,min(real(j,8),depth)-real(j-1,8))/depth
      call check(abs(flux(i,j)-expected)<1.d-14,'literal overlap oracle')
    end do
  end do
  ! Unavailable scalars and invalid inputs must not publish a worker matrix.
  if(allocated(bound))deallocate(bound)
  qs(2)=1.d-10
  call fmr_bind_multilevel_signed_divdra(p,v,qs,bound,b)
  call check(b%process_status==DRAIN_DIST_TRANSFER_BELOW_ADMITTED_MAGNITUDE.and..not.allocated(bound),'tiny rejects')
  qs(2)=ieee_value(0.d0,ieee_quiet_nan)
  call fmr_bind_multilevel_signed_divdra(p,v,qs,bound,b)
  call check(b%process_status==DRAIN_DIST_INVALID_TRANSFER.and..not.allocated(bound),'nan rejects')
  qs(2)=ieee_value(0.d0,ieee_positive_inf)
  call fmr_bind_multilevel_signed_divdra(p,v,qs,bound,b)
  call check(b%process_status==DRAIN_DIST_INVALID_TRANSFER.and..not.allocated(bound),'inf rejects')
  qs=rates(:,1);bad=p;bad(2)%dz(1)=2
  call fmr_bind_multilevel_signed_divdra(bad,v,qs,bound,b)
  call check(b%status==FMR_DIVDRA_BIND_PROCESS_REJECTED.and..not.allocated(bound),'grid rejects')
  call fmr_bind_multilevel_signed_divdra(p,v,qs(:2),bound,b)
  call check(b%status==FMR_DIVDRA_BIND_PROCESS_REJECTED.and..not.allocated(bound),'shape rejects')
  v%groundwater_level=-8
  call fmr_bind_multilevel_signed_divdra(p,v,qs,bound,b)
  call check(b%process_status==DRAIN_DIST_INVALID_HYDRAULIC_VIEW.and..not.allocated(bound),'view rejects')
  allocate(bound(2,2));bound=123
  call fmr_bind_multilevel_signed_divdra(p,v,qs,bound,b)
  call check(b%status==FMR_DIVDRA_BIND_TARGET_ALREADY_BOUND.and.all(bound==123),'target nonmutation')
  print '(A,I0,A,ES12.4,A,ES12.4)','MULTILEVEL_ORIGINAL_CASES=',ncases,' MAX_NODAL=',maxerr,' MAX_CLOSURE=',maxclosure
  print '(A)','MULTILEVEL_LITERAL_ORIGINAL_BINDER_NEGATIVES=PASS'
contains
  subroutine check(ok,label)
    logical,intent(in)::ok
    character(*),intent(in)::label
    if(.not.ok)then
      print *,label
      error stop 1
    end if
  end subroutine
end program
