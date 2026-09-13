module MOD_arrays
  implicit none
  integer, parameter :: macp=7, madr=3
end module MOD_arrays

module MOD_grid
  implicit none
  integer :: numnod=4
end module MOD_grid

module variables
  use iso_fortran_env, only: real64
  use MOD_arrays, only: macp
  implicit none
  real(real64) :: h(macp)=0,theta(macp)=0,hm1(macp)=0,thetm1(macp)=0
  real(real64) :: pond=0,pondm1=0,gwl=0,gwlm1=0,volact=0,ldwet=0,spev=0,saev=0
  real(real64) :: dt=0,dtold=0,t=0,t1900=0,tcum=0,timjan1=0,tstart=0,tend=0,outper=0
  real(real64) :: volini=0,pondini=0,ivolbeg=0,ipondbeg=0,issnowbeg=0,isicbeg=0,ithetabeg(macp)=0
  integer :: daycum=0,daynr=0,imonth=0,iyear=0,ioutdat=0,ioutdatint=0,isteps=0,nprintcount=0,cntper=0
  character(len=11) :: date=''
  logical :: fldayend=.false.,fldaystart=.false.,fldecdt=.false.,fldtmin=.false.,fldtreduce=.false.
  logical :: flbaloutput=.false.,flheader=.false.,floutput=.false.,floutputshort=.false.,flrunend=.false.
  logical :: flzerocumu=.false.,flzerointr=.false.
end module variables

module MOD_swap_base
  implicit none
  integer :: swhea=1, swsolu=1, swcrop=1, swirfix=1, swsnow=0, swmacro=0
end module MOD_swap_base

module MOD_SoilTemperature
  use iso_fortran_env, only: real64
  use MOD_arrays, only: macp
  implicit none
  real(real64) :: tsoil(macp)=0
  integer :: ipos_qtop=0, ipos_tetop=0, ipos_tebot=0
end module MOD_SoilTemperature

module MOD_solute_global
  use iso_fortran_env, only: real64
  use MOD_arrays, only: macp
  implicit none
  real(real64) :: cml(macp)=0, ageml(macp)=0
end module MOD_solute_global

module MOD_Solute
  use iso_fortran_env, only: real64
  use MOD_arrays, only: macp
  implicit none
  real(real64) :: cmsy(macp)=0
  real(real64) :: imdectot=0,imrottot=0,imsqbot=0,imsqdra=0,imsqirrig=0,imsqprec=0,imqsol(macp+1)=0
  real(real64) :: sbaldev=0,sdstor=0,sampro=0,rottot=0,sqdra=0,isqbot=0,dectot=0,sqprec=0,sqirrig=0,sqbot=0,samini=0,isqtop=0
end module MOD_Solute

module MOD_integral_global
  use iso_fortran_env, only: real64
  use MOD_arrays, only: macp
  implicit none
  real(real64) :: inqpotrot_day(macp)=0,inqredrot_day(macp)=0
  real(real64) :: iqrot_day=0,iqreddry_day=0,iqredsol_day=0,iptra_day=0,ialpwet_day=0,ialpdry_day=0
end module MOD_integral_global

module MOD_meteo
  implicit none
  integer :: meteo_rec=0,rain_rec=0,i_metdetail=0
  logical :: fl_update_meteo=.false.
end module MOD_meteo

module MOD_irrigation
  use iso_fortran_env, only: real64
  use MOD_arrays, only: macp
  implicit none
  integer :: schedule=0,dayfix=0,nirri=0,irrigevent=0,isua=0
  real(real64) :: cirr=0,dt_irr_event=0,gird=0,nird=0,qssdisum=0
  real(real64) :: qssdi(macp)=0
  logical :: flirrigate=.false.
end module MOD_irrigation

module MOD_integral
  use iso_fortran_env, only: real64
  use MOD_arrays, only: macp,madr
  implicit none
  real(real64) :: inqrot(macp)=0,inq(macp+1)=0,inqssdi(macp)=0,inqpotrot(macp)=0,inqredrot(macp)=0
  real(real64) :: iqdo(macp+1)=0,iqup(macp+1)=0
  real(real64) :: cqdrain(madr)=0,cqdrainin(madr)=0,cqdrainout(madr)=0
  real(real64) :: inqdra(madr,macp)=0,inqdra_in(madr,macp)=0,inqdra_out(madr,macp)=0
  real(real64) :: iqrot=0,iqssdi=0,iqredwet=0,iqreddry=0,iqredsol=0,iqredfrs=0,iintc=0,isintc=0,iepd=0,ipeva=0,iptra=0,ievap=0
  real(real64) :: iruno=0,irunon=0,iqbot=0,iqbdo=0,iqbup=0,iqtdo=0,iqtup=0,igrai=0,inrai=0,igird=0,inird=0
  real(real64) :: cgrai=0,cnrai=0,caintc=0,cqrot=0,cqbot=0,cqbotdo=0,cqbotup=0,cqssdi=0,cqtdo=0,cqtup=0
  real(real64) :: crunoff=0,crunon=0,cevap=0,cepd=0,cpeva=0,cptra=0,cinund=0,cqprai=0,cgird=0,cnird=0,cqdra=0,iqdra=0
  real(real64) :: cgsnow=0,cmelt=0,csnrai=0,csubl=0,isnrai=0,igsnow=0,isubl=0
end module MOD_integral

module plant_interface
  use iso_fortran_env, only: real64
  implicit none
  integer :: icrop=1, croptype(3)=[2,1,2], noddrz=0
  logical :: fl_start_croprotation=.false.,fl_start_cropemergence=.false.,fl_cropemergence=.true.
  logical :: fl_cropharvest=.false.,fl_cropharvestday=.false.,fl_cropisreset=.false.
  real(real64) :: cf=0,ch=0,vcover=0,siccap=0,sicact=0,siccaploss=0,rd=0,dvs=0,lai=0,tsum=0
  real(real64) :: wrt=0,wst=0,wlv=0,wso=0,dwrt=0,dwst=0,dwlv=0,laipot=0
  real(real64) :: wrtpot=0,wstpot=0,wlvpot=0,wsopot=0,dwrtpot=0,dwstpot=0,dwlvpot=0
  real(real64) :: dmhrv=0,dmloss=0,dmhrvpot=0,dmlosspot=0
  integer :: icut=0,tcut=0,icutpot=0,tcutpot=0
end module plant_interface

module MOD_cropdevelopment
  use iso_fortran_env, only: real64
  use MOD_arrays, only: macp
  implicit none
  logical :: fl_cropcalendar=.true.,fl_readcropfile=.true.,fl_prep=.false.,fl_sow=.false.,fl_germ=.false.
  integer :: delay_prep=0,delay_sow=0
  real(real64) :: tsumgerm=0,rdpot=0
  real(real64) :: cumdens(2*(macp+1))=0,cumdens_top(macp+1)=0,lrv_node(macp)=0,wroot_node(macp)=0,wroot_node_top(macp)=0
end module MOD_cropdevelopment

module MOD_wofost
  use iso_fortran_env, only: real64
  implicit none
  type :: wofost_states
    real(real64) :: marker=0
  end type
  type :: agro_management
    real(real64) :: marker=0
  end type
  type(wofost_states) :: s_act,s_pot
  type(agro_management) :: m_act,m_pot
  real(real64) :: vern=0,atmin7(7)=0
  logical :: fl_anthesis=.false.,fl_vernalised=.false.
  integer :: t_tsumcum=0,nofd=0
end module MOD_wofost
