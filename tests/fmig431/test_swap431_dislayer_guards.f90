program dislayer_guards
 use, intrinsic :: iso_fortran_env,only:real64
 use, intrinsic :: ieee_arithmetic,only:ieee_value,ieee_quiet_nan,ieee_positive_inf
 use mod_drainage_discharge_layer_transform
 use mod_process_hydraulic_view,only:process_hydraulic_view_t
 use mod_drainage_spatial_distribution,only:drainage_distribution_parameters_t
 use mod_fmr_divdra_dislayer_binding
 use mod_fmr_divdra_runtime_binding,only:fmr_bind_single_level_signed_divdra,fmr_divdra_binding_diagnostics_t
 implicit none
 type(drainage_distribution_parameters_t)::p(2),bad(2)
 type(discharge_layer_top_control_t)::c(2),bc(2)
 type(process_hydraulic_view_t)::v,bv
 type(fmr_divdra_dislayer_diagnostics_t)::d
 type(fmr_divdra_binding_diagnostics_t)::old
 type(discharge_layer_diagnostics_t)::transform
 real(real64),allocatable::target(:,:),reference(:,:)
 real(real64)::q(2),bq(2),nan,inf,row(4),saved(4),rates(3)
 integer::i,n
 nan=ieee_value(0.d0,ieee_quiet_nan);inf=ieee_value(0.d0,ieee_positive_inf)
 do i=1,2
  p(i)%active_nodes=4;p(i)%dz=[1.d0,1.d0,1.d0,1.d0];p(i)%zbotcp=[-1.d0,-2.d0,-3.d0,-4.d0]
  p(i)%saturated_conductivity=[1.d0,1.d0,1.d0,1.d0];p(i)%horizontal_anisotropy_factor=[1.d0,1.d0,1.d0,1.d0];p(i)%drain_spacing=40
 end do
 c%mode=1;c%top_level=-1.5d0;v%groundwater_level=-.5d0;q=[.003d0,-.002d0]
 do n=1,20
  bad=p;bc=c;bv=v;bq=q
  select case(n)
  case(1);bq(1)=nan
  case(2);bv%groundwater_level=nan
  case(3);deallocate(bad(1)%dz)
  case(4);bad(1)%saturated_conductivity(1)=nan
  case(5);bad(1)%horizontal_anisotropy_factor(1)=inf
  case(6);bad(1)%zbotcp(1)=nan
  case(7);bad(1)%drain_spacing=nan
  case(8);bad(1)%active_nodes=0
  case(9);bad(1)%dz(1)=-1
  case(10);bc(1)%mode=3
  case(11);bc(1)%top_level=nan
  case(12);bc(1)%top_level=.1d0
  case(13);bc(1)%top_level=-4.1d0
  case(14);bc(1)%mode=2;bc(1)%fraction=-.1d0
  case(15);bc(1)%mode=2;bc(1)%fraction=1.1d0
  case(16);bc(1)%mode=2;bc(1)%fraction=nan
  case(17);bc(1)%mode=2;bc(1)%dramet=4
  case(18);bc(1)%mode=2;bc(1)%dramet=2;bc(1)%shape=0
  case(19);bc(1)%mode=2;bc(1)%head_difference=inf
  case(20);bq(1)=1.d-10
  end select
  call fmr_bind_dislayer(bad(:1),bv,bq(:1),bc(:1),target,d)
  call check(.not.d%published.and..not.allocated(target),'invalid premutation')
 end do
 call fmr_bind_dislayer(p(:1),v,q,c,target,d)
 call check(.not.d%published.and..not.allocated(target),'q shape')
 call fmr_bind_dislayer(p,v,q,c(:1),target,d)
 call check(.not.d%published.and..not.allocated(target),'control shape')
 bad=p;bad(2)%saturated_conductivity(1)=2
 call fmr_bind_dislayer(bad,v,q,c,target,d)
 call check(.not.d%published.and..not.allocated(target),'parameter ownership')
 allocate(target(2,2));target=123
 call fmr_bind_dislayer(p,v,q,c,target,d)
 call check(d%status==FMR_DIVDRA_DISLAYER_PREBOUND.and.all(target==123),'prebound preserved')
 deallocate(target)
 c%mode=0;rates=[.003d0,-.003d0,0.d0]
 do i=1,3
  call fmr_bind_dislayer(p(:1),v,rates(i:i),c(:1),target,d)
  call fmr_bind_single_level_signed_divdra(p(1),v,rates(i),reference,old)
  call check(d%published.and.old%published.and.all(target==reference),'disabled exact original route')
  deallocate(target,reference)
 end do
 saved=[.1d0,.2d0,.3d0,.4d0];row=saved
 call apply_discharge_layer_top([1.d0,1.d0,1.d0,1.d0],nan,1.d0,row,transform)
 call check(.not.transform%evaluated.and.all(row==saved),'direct invalid top unchanged')
 call apply_discharge_layer_top([1.d0,1.d0,1.d0,1.d0],-5.d0,1.d0,row,transform)
 call check(.not.transform%evaluated.and.all(row==saved),'direct invalid geometry unchanged')
 print '(A)','DISLAYER_PREPUBLICATION_GUARDS=PASS'
 print '(A)','DISLAYER_INVALID_CASES=20 SHAPE=2 OWNERSHIP=1 PREBOUND=1 DEFAULT_EXACT=3 DIRECT_NONMUTATION=2'
contains
 subroutine check(ok,label)
  logical,intent(in)::ok
  character(*),intent(in)::label
  if(.not.ok)then
   print *,label
   error stop 84
  end if
 end subroutine
end program
