! Test-only independent inverse: Newton in IEEE quad, not production bisection.
module matrix_nonlinear_oracle
  use iso_fortran_env,only:real64,real128
  implicit none
contains
  function nonlinear_inverse(theta,rho,kf,cref,exponent,mass) result(c)
    real(real64),intent(in)::theta,rho,kf,cref,exponent,mass
    real(real64)::c
    real(real128)::w,b,r,n,m,x,y,f,df
    integer::iteration
    w=real(theta,real128);b=real(rho,real128)*real(kf,real128)
    r=real(cref,real128);n=real(exponent,real128);m=real(mass,real128)
    if(m<=0.0_real128)then
      c=0.0_real64;return
    end if
    if(w<=0.0_real128)error stop 'oracle requires positive matrix water'
    x=m/w
    do iteration=1,1024
      f=w*x+b*r*(x/r)**n-m
      if(abs(f)<128*epsilon(x)*m)then
        c=real(x,real64);return
      end if
      df=w+b*n*(x/r)**(n-1)
      y=x-f/df
      if(y<=0.0_real128)y=x/2
      x=y
    end do
    error stop 'independent Newton did not converge'
  end function
end module
