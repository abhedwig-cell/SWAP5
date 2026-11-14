! Exercise the actual original constitutive module; no copied curve formulas.
program original_constitutive_curves
  use ieee_arithmetic, only: ieee_is_finite
  use MOD_grid, only: layer
  use WC_K_models_04_11, only: functionvalue_04_11, BiModal, NoVap
  implicit none
  real(8) :: cof(24,2),h,w,k,c,previous
  integer :: model,soil,j,models(2)
  cof=0d0
  cof(1,:)=.02d0;cof(2,:)=[.433878d0,.387064d0]
  cof(3,:)=[83.24164d0,22.76176d0];cof(4,:)=[.021645d0,.016083d0]
  cof(5,:)=[7.202077d0,2.439662d0];cof(6,:)=[1.348770d0,1.524418d0]
  cof(7,:)=1d0-1d0/cof(6,:)
  cof(13,:)=[.005d0,.003d0];cof(14,:)=[1.5d0,1.6d0]
  cof(15,:)=1d0-1d0/cof(14,:);cof(16,:)=.8d0;cof(17,:)=.2d0
  cof(18,:)=1d6;cof(19,:)=10d0;cof(20,:)=-1.5d0;cof(21,:)=.01d0
  layer(1:2)=[1,2];NoVap=.true.
  do model=4,11
    models=model;BiModal=any(model==[6,7,10,11])
    do soil=1,2
      previous=-1d0
      do j=0,180
        h=-10d0**(6d0-real(j,8)/20d0)
        w=functionvalue_04_11(1,soil,models,cof,h)
        k=functionvalue_04_11(2,soil,models,cof,h)
        c=functionvalue_04_11(3,soil,models,cof,h)
        if(.not.all(ieee_is_finite([w,k,c])))error stop 'Nonfinite original curve'
        if(w<0d0.or.w>cof(2,soil)+1d-12.or.k<0d0.or.c<0d0)error stop 'Original curve outside physical domain'
        if(w<previous-1d-12)error stop 'Nonmonotone original water retention'
        previous=w
        print '(3i5,4es25.16)',model,soil,j,h,w,k,c
      end do
    end do
  end do
end program

! Failure-only host diagnostic; no physical code is replaced.
subroutine swap_error(component,message)
  character(*),intent(in)::component,message
  print *,component,message
  error stop 'Original component refused its input'
end subroutine
