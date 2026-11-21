! Call complete original modules. No water retention/conductivity formula is copied.
program actual_original_hydraulic_probe
  use ieee_arithmetic,only:ieee_is_finite
  use MOD_grid,only:numnod,layer
  use MOD_swap_base,only:swfrost,swhyst
  use MOD_MvG,only:cofgen,iHWCKmodel,swsophy,sw_use_elas,fl_use_tables,fl_use_kh_power, &
    set_cofgen_pointers,calc_cofgen_extra,watcon,moiscap,hconduc,dhconduc
  use WC_K_models_04_11,only:BiModal,NoVap
  use variables,only:indeks,fhyst,fluseksatexm
  implicit none
  integer::model,soil,j,omega_index,dry_index,alpha_index
  character(len=24)::argument
  real(8),parameter::weights(5)=[0d0,.2d0,.5d0,.8d0,1d0]
  real(8),parameter::dry_heads(3)=[1d4,1d6,1d8],alpha_factors(3)=[.1d0,1d0,10d0]
  real(8)::head,w,capacity,k,dk,left_w,right_w,left_k,right_k,delta
  call get_command_argument(1,argument);read(argument,*)model
  if(model<1.or.model>11)error stop 'Unsupported original component selector'
  numnod=2;layer(1:2)=[1,2];swsophy=0;sw_use_elas=0;swfrost=0;swhyst=0
  fl_use_tables=.false.;fl_use_kh_power=.false.;fluseksatexm=.false.
  indeks=-1;fhyst=1d0;NoVap=.true.;BiModal=any(model==[6,7,10,11])
  call set_cofgen_pointers()
  cofgen=0d0
  ! Exact two-soil coefficients of the already archived original4..11 component.
  cofgen(1,1:2)=.02d0;cofgen(2,1:2)=[.433878d0,.387064d0]
  cofgen(3,1:2)=[83.24164d0,22.76176d0];cofgen(4,1:2)=[.021645d0,.016083d0]
  cofgen(5,1:2)=[7.202077d0,2.439662d0];cofgen(6,1:2)=[1.348770d0,1.524418d0]
  cofgen(7,1:2)=1d0-1d0/cofgen(6,1:2);cofgen(8,1:2)=2d0*cofgen(4,1:2)
  cofgen(9,1:2)=-.01d0
  cofgen(13,1:2)=[.005d0,.003d0];cofgen(14,1:2)=[1.5d0,1.6d0]
  cofgen(15,1:2)=1d0-1d0/cofgen(14,1:2);cofgen(16,1:2)=.8d0;cofgen(17,1:2)=.2d0
  cofgen(18,1:2)=1d6;cofgen(19,1:2)=10d0;cofgen(20,1:2)=-1.5d0;cofgen(21,1:2)=.01d0
  if(model/=7)error stop 'This grid owns model7 capacity only'
  iHWCKmodel=model
  do alpha_index=1,3
  do omega_index=1,5
  do dry_index=1,3
    cofgen(13,1:2)=[.005d0,.003d0]*alpha_factors(alpha_index)
    cofgen(16,1:2)=weights(omega_index);cofgen(17,1:2)=1d0-weights(omega_index)
    cofgen(18,1:2)=dry_heads(dry_index)
    call calc_cofgen_extra(2)
    do soil=1,2
      do j=0,3
        head=-10d0**(3d0-real(j,8));delta=abs(head)*1d-3
        w=watcon(soil,head);capacity=moiscap(soil,head)
        k=hconduc(soil,head,w,1d0);dk=dhconduc(soil,head,w,capacity,1d0)
        left_w=watcon(soil,head-delta);right_w=watcon(soil,head+delta)
        left_k=hconduc(soil,head-delta,left_w,1d0);right_k=hconduc(soil,head+delta,right_w,1d0)
        if(.not.all(ieee_is_finite([w,capacity,k,dk,left_w,right_w,left_k,right_k]))) &
          error stop 'Nonfinite actual original model7 parameter grid'
        write(*,'(a,6(1x,i0),10(1x,es25.17e3))')'ACTUAL_ORIGINAL_HYDRAULIC', &
          model,soil,j,alpha_index,omega_index,dry_index,head,w,capacity,k,dk,left_w,right_w,left_k,right_k,delta
      end do
    end do
  end do
  end do
  end do
end program
