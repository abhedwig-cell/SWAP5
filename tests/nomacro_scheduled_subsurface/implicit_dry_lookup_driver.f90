program actual_original_nonhistory_dry_lookup
  use, intrinsic::ieee_arithmetic,only:ieee_is_finite
  use MOD_grid,only:numnod,numlay,layer,nod1lay
  use MOD_swap_base,only:swfrost,swmacro,swhyst
  use variables,only:indeks,fhyst,fluseksatexm,dt,ksatfit
  use MOD_MvG,only:cofgen,set_cofgen_pointers,watcon,hconduc, &
    swsophy,iHWCKmodel,sw_use_elas,fl_use_tables,fl_use_kh_power
  use MOD_RWU_micro,only:get_MFLP_K,M_table,K_table
  implicit none
  real(8)::clock,node,recorded_head,recorded_capacity,head,m,k,upper,wilt,heads(5)
  integer::unit,i
  character(1024)::path
  call get_command_argument(1,path)
  numnod=1;numlay=1;layer(1)=1;nod1lay(1)=1;swfrost=0;swmacro=0;swhyst=0
  swsophy=0;iHWCKmodel=1;sw_use_elas=0;fl_use_tables=.false.;fl_use_kh_power=.false.
  indeks=-1;fhyst=1d0;fluseksatexm=.false.;cofgen=0d0
  open(newunit=unit,file=trim(path),status='old',action='read')
  read(unit,*)clock,dt,node,recorded_head,recorded_capacity,cofgen(:,1)
  close(unit)
  call set_cofgen_pointers
  ksatfit(1)=cofgen(3,1)
  call get_MFLP_K(1)
  wilt=hconduc(1,-20000d0,watcon(1,-20000d0),10d0)
  upper=hconduc(1,-19000d0,watcon(1,-19000d0),10d0)
  if(K_table(431,1)/=wilt.or.M_table(431,1)/=0d0)error stop 'Actual original dry endpoint not initialized'
  if(.not.all(ieee_is_finite([M_table(430:431,1),K_table(430:431,1)])))error stop 'Undefined dry endpoint'
  if(M_table(430,1)<=0d0.or.K_table(430,1)<=0d0.or.maxval(K_table(430:431,1))>upper) &
    error stop 'Actual original initialized endpoint outside constitutive range'
  heads=[-19756.1983135119335d0,-19952.62314968879d0,-19999.9d0,-20000d0,-20000.1d0]
  do i=1,size(heads)
    head=heads(i);call get_MFLP_K(2,head,1,m,k)
    if(.not.all(ieee_is_finite([m,k])).or.min(m,k)<0d0.or.k>upper)error stop 'Invalid actual original dry lookup'
    if(head==-20000d0.and.(m/=0d0.or.k/=wilt))error stop 'Dry endpoint lookup differs from original constitutive endpoint'
    if(head< -20000d0.and.(m/=0d0.or.k/=0d0))error stop 'Original below-wilting delegation changed'
    write(*,'(a,*(1x,es25.17e3))')'ACTUAL_ORIGINAL_NONHISTORY_DRY_LOOKUP',head,m,k,wilt,upper
  end do
  write(*,'(a)')'REAL_ORIGINAL_NONHISTORY_COMPLETE_DRY_ENDPOINT_FIVE_INPUTS_PASS'
end program
