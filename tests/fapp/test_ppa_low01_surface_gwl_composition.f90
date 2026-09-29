program test_ppa_low01_surface_gwl_composition
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use mod_ppa_low01_surface_gwl_composition
  implicit none
  integer, parameter :: n=4
  integer :: i, j, status
  real(real64) :: gwlinp, rain, irrigation, melt, area_store, runon, reva, epd
  real(real64) :: pond, pond_previous, dt, runots, q0, qv(n+1), head(n), qbot
  real(real64) :: dz(n), macro_fraction(n), theta(n), theta_previous(n)
  real(real64) :: sink(n), source(n), qrot(n), disnod(n), kmean(n)
  real(real64) :: expected_q0, expected_qv1, expected_qv(n+1), expected_head(n), expected_qbot
  real(real64) :: saved, replay, alternate

  dz = [10.0_real64, 12.0_real64, 14.0_real64, 16.0_real64]
  macro_fraction = [1.0_real64, 0.8_real64, 0.6_real64, 0.4_real64]
  theta = [0.30_real64, 0.32_real64, 0.28_real64, 0.25_real64]
  theta_previous = [0.31_real64, 0.30_real64, 0.29_real64, 0.24_real64]
  sink = [0.01_real64, 0.02_real64, 0.03_real64, 0.04_real64]
  source = [0.02_real64, 0.01_real64, 0.02_real64, 0.03_real64]
  qrot = [0.0_real64, 0.01_real64, -0.01_real64, 0.02_real64]
  disnod = [5.0_real64, 11.0_real64, 13.0_real64, 15.0_real64]
  kmean = [2.0_real64, 1.5_real64, 1.2_real64, 0.9_real64]

  do i=1,100000
    gwlinp = -real(mod(i*3, 1000),real64)/100000.0_real64
    rain = real(mod(i*37,200001)-100000,real64)/10000.0_real64
    irrigation = real(mod(i*17,200001)-100000,real64)/10000.0_real64
    melt = real(mod(i*101,200001)-100000,real64)/10000.0_real64
    area_store = real(mod(i*43,100001),real64)/100000.0_real64
    runon = real(mod(i*29,200001)-100000,real64)/10000.0_real64
    reva = real(mod(i*23,200001)-100000,real64)/10000.0_real64
    epd = real(mod(i*13,200001)-100000,real64)/10000.0_real64
    pond = real(mod(i*11,200001)-100000,real64)/10000.0_real64
    pond_previous = real(mod(i*31,200001)-100000,real64)/10000.0_real64
    dt = real(mod(i*7,100000)+1,real64)/10000.0_real64
    runots = real(mod(i*53,200001)-100000,real64)/10000.0_real64
    do j=1,n
      theta(j)=real(mod(i*37+j*109,100001),real64)/100000.0_real64
      theta_previous(j)=real(mod(i*17+j*43,100001),real64)/100000.0_real64
      sink(j)=real(mod(i*101+j*13,20001)-10000,real64)/100000.0_real64
      source(j)=real(mod(i*29+j*71,20001)-10000,real64)/100000.0_real64
      qrot(j)=real(mod(i*23+j*31,20001)-10000,real64)/100000.0_real64
    end do

    expected_q0=(rain+irrigation+melt)*(1.0_real64-area_store)+runon-reva-epd
    expected_qv1=-expected_q0+(pond-pond_previous)/dt+runots/dt
    expected_qv(1)=expected_qv1
    expected_head(1)=gwlinp+disnod(1)*(expected_qv(1)/kmean(1)+1.0_real64)
    do j=1,n
      expected_qv(j+1)=expected_qv(j)+dz(j)*macro_fraction(j)*(theta(j)-theta_previous(j))/dt+ &
          sink(j)-source(j)+qrot(j)
    end do
    do j=2,n
      expected_head(j)=expected_head(j-1)+disnod(j)*(expected_qv(j)/kmean(j)+1.0_real64)
    end do
    expected_qbot=expected_qv(n+1)

    call evaluate_ppa_low01_surface_gwl_composition(gwlinp,rain,irrigation,melt,area_store,runon,reva,epd, &
        pond,pond_previous,dt,runots,dz,macro_fraction,theta,theta_previous,sink,source,qrot,disnod,kmean, &
        q0,qv,head,qbot,status)
    if(status/=PPA_LOW01_SURFACE_COMPOSITION_OK .or. transfer(q0,0_int64)/=transfer(expected_q0,0_int64) .or. &
       any(transfer(qv,[0_int64],n+1)/=transfer(expected_qv,[0_int64],n+1)) .or. &
       any(transfer(head,[0_int64],n)/=transfer(expected_head,[0_int64],n)) .or. &
       transfer(qbot,0_int64)/=transfer(expected_qbot,0_int64)) &
      error stop '100000-vector composed surface-GWL source oracle mismatch'
  end do

  rain=0.3_real64; irrigation=0.1_real64; melt=0.2_real64; area_store=0.25_real64
  runon=0.05_real64; reva=0.04_real64; epd=0.03_real64; pond=0.02_real64
  pond_previous=0.01_real64; dt=0.5_real64; runots=0.005_real64; gwlinp=-0.00005_real64
  call evaluate_ppa_low01_surface_gwl_composition(gwlinp,rain,irrigation,melt,area_store,runon,reva,epd, &
      pond,pond_previous,dt,runots,dz,macro_fraction,theta,theta_previous,sink,source,qrot,disnod,kmean, &
      q0,qv,head,saved,status)
  call evaluate_ppa_low01_surface_gwl_composition(gwlinp,rain,irrigation,melt,area_store,runon+0.1_real64,reva,epd, &
      pond,pond_previous,dt,runots,dz,macro_fraction,theta,theta_previous,sink,source,qrot,disnod,kmean, &
      q0,qv,head,alternate,status)
  call evaluate_ppa_low01_surface_gwl_composition(gwlinp,rain,irrigation,melt,area_store,runon,reva,epd, &
      pond,pond_previous,dt,runots,dz,macro_fraction,theta,theta_previous,sink,source,qrot,disnod,kmean, &
      q0,qv,head,replay,status)
  if(transfer(saved,0_int64)/=transfer(replay,0_int64).or.transfer(saved,0_int64)==transfer(alternate,0_int64)) &
    error stop 'A/B/A replay mismatch'

  write(*,'(a)') 'PPA_LOW01_SURFACE_GWL_COMPOSITION_SOURCE_ORACLE_100000=PASS'
  write(*,'(a)') 'PPA_LOW01_SURFACE_GWL_SEED_PROFILE_AND_QBOT=PASS'
  write(*,'(a)') 'PPA_LOW01_SURFACE_GWL_COMPOSITION_STATELESS_A_B_A=PASS'

end program test_ppa_low01_surface_gwl_composition
