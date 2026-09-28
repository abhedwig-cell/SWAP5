module mod_ppa_wu05a3_sorptivity_events
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private
  public :: update_sorptivity_events, refresh_sorptivity_wall
contains
  subroutine refresh_sorptivity_wall(top,volume,proportion,thickness,wall_old,wall_new,status)
    integer,intent(in) :: top
    real(real64),intent(in) :: volume(:),proportion(:),thickness(:),wall_old(:)
    real(real64),intent(out) :: wall_new(:)
    integer,intent(out) :: status
    integer :: n,ic
    real(real64) :: radicand(size(volume))
    status=1; wall_new=0.0_real64
    n=size(volume)
    if(top<1 .or. top>n) return
    if(size(proportion)/=n .or. size(thickness)/=n .or. size(wall_old)/=n .or. size(wall_new)/=n) return
    if(.not.all(ieee_is_finite(volume)) .or. .not.all(ieee_is_finite(proportion)) .or. &
        .not.all(ieee_is_finite(thickness)) .or. .not.all(ieee_is_finite(wall_old))) return
    if(any(proportion(top:n)<=0.0_real64) .or. any(thickness(top:n)<=0.0_real64) .or. &
        any(volume(top:n)<0.0_real64)) return
    do ic=top,n
      radicand(ic)=1.0_real64-volume(ic)/proportion(ic)/thickness(ic)
    end do
    if(any(radicand(top:n)<0.0_real64)) return
    wall_new=wall_old
    do ic=top,n
      wall_new(ic)=sqrt(radicand(ic))
    end do
    status=0
  end subroutine

  subroutine update_sorptivity_events(n,nd,top,saturated_top,swabs,water_top,bottom,dt,ended, &
      wet,proportion,diameter,time_old,sorp_old,theta_old,wall_old,time_new,sorp_new,theta_new,wall_new,status)
    integer, intent(in) :: n,nd,top,saturated_top,swabs,water_top(:),bottom(:)
    real(real64), intent(in) :: dt,wet(:,:),proportion(:,:),diameter(:)
    real(real64), intent(in) :: time_old(:,:),sorp_old(:,:),theta_old(:,:),wall_old(:)
    logical, intent(in) :: ended(:,:)
    real(real64), intent(out) :: time_new(:,:),sorp_new(:,:),theta_new(:,:),wall_new(:)
    integer, intent(out) :: status
    integer :: id,ic,last
    status=1
    time_new=0.0_real64; sorp_new=0.0_real64; theta_new=0.0_real64; wall_new=0.0_real64
    if(n<1 .or. nd<1 .or. top<1 .or. top>n .or. saturated_top<1 .or. saturated_top>n+1) return
    if(swabs/=0 .and. swabs/=1) return
    if(size(water_top)/=nd .or. size(bottom)/=nd .or. size(diameter)/=n .or. size(wall_old)/=n .or. &
        size(wall_new)/=n) return
    if(any(shape(wet)/=[nd,n]) .or. any(shape(proportion)/=[nd,n]) .or. any(shape(ended)/=[nd,n]) .or. &
        any(shape(time_old)/=[nd,n]) .or. any(shape(sorp_old)/=[nd,n]) .or. any(shape(theta_old)/=[nd,n]) .or. &
        any(shape(time_new)/=[nd,n]) .or. any(shape(sorp_new)/=[nd,n]) .or. any(shape(theta_new)/=[nd,n])) return
    if(any(water_top<1) .or. any(water_top>n+1) .or. any(bottom<0) .or. any(bottom>n)) return
    if(.not.ieee_is_finite(dt)) return
    if(dt<=0.0_real64) return
    if(.not.all(ieee_is_finite(time_old)) .or. .not.all(ieee_is_finite(sorp_old)) .or. &
        .not.all(ieee_is_finite(theta_old)) .or. .not.all(ieee_is_finite(wall_old)) .or. &
        .not.all(ieee_is_finite(wet)) .or. .not.all(ieee_is_finite(proportion)) .or. &
        .not.all(ieee_is_finite(diameter))) return
    if(any(time_old<0.0_real64) .or. any(diameter<=0.0_real64)) return
    time_new=time_old; sorp_new=sorp_old; theta_new=theta_old; wall_new=wall_old
    if(swabs==1) then
      do id=1,nd
        last=min(bottom(id),saturated_top-1)
        do ic=water_top(id),last
          if(ended(id,ic)) then
            time_new(id,ic)=0.0_real64; sorp_new(id,ic)=0.0_real64; theta_new(id,ic)=0.0_real64
            wall_new(ic)=0.0_real64
          else
            theta_new(id,ic)=theta_new(id,ic)+wall_new(ic)*wet(id,ic)*proportion(id,ic)* &
                (4.0_real64/diameter(ic))*sorp_new(id,ic)*(sqrt(time_new(id,ic)+dt)-sqrt(time_new(id,ic)))
            time_new(id,ic)=time_new(id,ic)+dt
          end if
        end do
        time_new(id,top:water_top(id)-1)=0.0_real64
        sorp_new(id,top:water_top(id)-1)=0.0_real64
        theta_new(id,top:water_top(id)-1)=0.0_real64
        time_new(id,last+1:n)=0.0_real64
        sorp_new(id,last+1:n)=0.0_real64
        theta_new(id,last+1:n)=0.0_real64
      end do
    end if
    status=0
  end subroutine
end module
