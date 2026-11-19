program real_original_micro_finalization
  use, intrinsic::ieee_arithmetic,only:ieee_is_finite
  use MOD_arrays,only:macp,mcof
  use MOD_grid,only:numnod,numlay,layer,nod1lay,dz
  use MOD_swap_base,only:swhyst,swfrost,unit_log,unit_err,fl_do_not_read_crpfile
  use plant_interface,only:unit_crp,crpfilnam,sw_oxygen
  use variables,only:h,indeks,fhyst,ksatfit,t1900,date
  use MOD_MvG,only:cofgen,set_cofgen_pointers,swsophy,iHWCKmodel,sw_use_elas,fl_use_tables,fl_use_kh_power
  use MOD_RWU_micro,only:do_RWU_micro,M_table,K_table
  implicit none
  integer::unit,nroot,micro,sw_drought,ncof,node,j
  integer,parameter::nodes(3)=[11,13,14]
  real(8)::tp,alpha,initial_h(macp),lrv(macp),stress(macp),base(macp),upw(macp),plus(macp),minus(macp),maximum
  real(8),allocatable::saved_m(:,:),saved_k(:,:)
  character(1024)::path,mode
  call get_command_argument(1,path);call get_command_argument(2,mode)
  open(newunit=unit,file=trim(path),status='old',action='read')
  read(unit,*)numnod,numlay,nroot,tp,sw_drought,swhyst,swfrost,ncof,t1900
  if(ncof/=mcof.or.nroot/=14.or.numnod/=34.or.sw_drought/=3.or.swfrost/=0)error stop 'Foreign actual root fixture domain'
  read(unit,*)layer(1:numnod)
  read(unit,*)nod1lay(1:numlay)
  read(unit,*)dz(1:numnod)
  read(unit,*)cofgen(:,1:numnod)
  read(unit,*)indeks(1:numnod)
  read(unit,*)fhyst(1:numnod)
  read(unit,*)lrv(1:nroot)
  read(unit,*)stress(1:nroot)
  read(unit,*)h(1:numnod)
  allocate(saved_m(801,numlay),saved_k(801,numlay))
  read(unit,*)saved_m
  read(unit,*)saved_k
  close(unit)
  initial_h=h
  swsophy=0;iHWCKmodel=1;sw_use_elas=0;fl_use_tables=.false.;fl_use_kh_power=.false.
  call set_cofgen_pointers
  ksatfit(1:numlay)=cofgen(3,nod1lay(1:numlay))
  unit_log=6;unit_err=6;unit_crp=77;crpfilnam='grass.crp';sw_oxygen=2
  fl_do_not_read_crpfile=.false.;date='2004-09-08'
  micro=1
  call do_RWU_micro(1,micro,nroot,lrv(1:nroot),tp,stress(1:nroot),.false.,upw(1:nroot),alpha)
  ! Restore the actual initialized process input carry exported from the real
  ! failed state. These are original lookup values, never a substitute law.
  M_table=saved_m;K_table=saved_k
  call do_RWU_micro(2,micro,nroot,lrv(1:nroot),tp,stress(1:nroot),.false.,base(1:nroot),alpha)
  do j=1,2
    call do_RWU_micro(2,micro,nroot,lrv(1:nroot),tp,stress(1:nroot),.false.,upw(1:nroot),alpha)
    if(any(upw(1:nroot)/=base(1:nroot)))error stop 'Actual original root evaluation is not repeatable'
  end do
  maximum=0d0
  do j=1,3
    node=nodes(j)
    h=initial_h;h(node)=initial_h(node)+1d-6
    call do_RWU_micro(2,micro,nroot,lrv(1:nroot),tp,stress(1:nroot),.false.,plus(1:nroot),alpha)
    h=initial_h;h(node)=initial_h(node)-1d-6
    call do_RWU_micro(2,micro,nroot,lrv(1:nroot),tp,stress(1:nroot),.false.,minus(1:nroot),alpha)
    if(.not.all(ieee_is_finite([plus(1:nroot),minus(1:nroot)])))error stop 'Nonfinite actual original root response'
    if(minval([plus(1:nroot),minus(1:nroot)])<0d0)error stop 'Negative actual original root uptake'
    if(max(sum(plus(1:nroot)),sum(minus(1:nroot)))>tp+1d-10)error stop 'Actual original root exceeds demand'
    maximum=max(maximum,maxval(abs(plus(1:nroot)-minus(1:nroot))))
    write(*,'(a,1x,i0,*(1x,es25.17e3))')'ACTUAL_ORIGINAL_MICRO_RESPONSE',node,plus(1:nroot),minus(1:nroot)
  end do
  if(trim(mode)=='original')then
    if(maximum<1d-2)error stop 'Actual original root discontinuity not reproduced'
    write(*,'(a,1x,es25.17e3)')'REAL_ORIGINAL_MICRO_DISCONTINUITY_REPRODUCED',maximum
  else if(trim(mode)=='corrected')then
    if(maximum>1d-6)error stop 'Original root finalization remains discontinuous'
    write(*,'(a,1x,es25.17e3)')'REAL_ORIGINAL_MICRO_FINALIZATION_PASS',maximum
  else
    error stop 'Foreign root component mode'
  end if
end program
