module mod_b111_crop_n_owner
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_b111_crop_n_fixation_policy, only: b111_nfix_request_t,prepare_b111_nfix_request,B111_NFIX_OK
  implicit none
  private

  integer,parameter,public::B111_CROPN_OK=0
  integer,parameter,public::B111_CROPN_INVALID=1
  integer,parameter,public::B111_CROPN_BALANCE=2

  type,public::b111_crop_n_state_t
    real(real64)::anlv_kg_ha=0.0_real64
    real(real64)::anst_kg_ha=0.0_real64
    real(real64)::anrt_kg_ha=0.0_real64
    real(real64)::anso_kg_ha=0.0_real64
    real(real64)::nuptake_total_kg_ha=0.0_real64
    real(real64)::nfix_total_kg_ha=0.0_real64
    real(real64)::nloss_leaf_kg_ha=0.0_real64
    real(real64)::nloss_stem_kg_ha=0.0_real64
    real(real64)::nloss_root_kg_ha=0.0_real64
    real(real64)::initial_n_kg_ha=0.0_real64
  contains
    procedure::valid=>crop_n_valid
    procedure::balance_residual=>crop_n_balance_residual
  end type

  type,public::b111_crop_n_forcing_t
    real(real64)::delt_day=1.0_real64
    real(real64)::dvs=0.0_real64
    real(real64)::reltr=1.0_real64
    real(real64)::dvsnlt=0.0_real64
    real(real64)::dvsnt=0.0_real64
    real(real64)::nfixf=0.0_real64
    real(real64)::tcnt_day=1.0_real64
    real(real64)::fntrt=0.0_real64
    real(real64)::wlv_kg_ha=0.0_real64
    real(real64)::wst_kg_ha=0.0_real64
    real(real64)::wrt_kg_ha=0.0_real64
    real(real64)::wso_kg_ha=0.0_real64
    real(real64)::nmaxlv=0.0_real64
    real(real64)::nmaxst=0.0_real64
    real(real64)::nmaxrt=0.0_real64
    real(real64)::nmaxso=0.0_real64
    real(real64)::rnflv=0.0_real64
    real(real64)::rnfst=0.0_real64
    real(real64)::rnfrt=0.0_real64
    real(real64)::drlv_kg_ha_day=0.0_real64
    real(real64)::drst_kg_ha_day=0.0_real64
    real(real64)::drrt_kg_ha_day=0.0_real64
    real(real64)::soil_supply_kg_m2_day=0.0_real64
  end type

  type,public::b111_crop_n_request_t
    integer::status=B111_CROPN_INVALID
    real(real64)::ndeml_kg_ha=0.0_real64
    real(real64)::ndems_kg_ha=0.0_real64
    real(real64)::ndemr_kg_ha=0.0_real64
    real(real64)::ndemso_kg_ha_day=0.0_real64
    real(real64)::vegetative_demand_kg_ha=0.0_real64
    real(real64)::soil_demand_kg_ha=0.0_real64
    real(real64)::fixation_demand_kg_ha=0.0_real64
  end type

  type,public::b111_crop_n_receipt_t
    integer::status=B111_CROPN_INVALID
    real(real64)::vegetative_demand_kg_ha=0.0_real64
    real(real64)::soil_demand_kg_ha=0.0_real64
    real(real64)::fixation_kg_ha=0.0_real64
    real(real64)::soil_uptake_kg_ha=0.0_real64
    real(real64)::storage_uptake_kg_ha=0.0_real64
    real(real64)::loss_kg_ha=0.0_real64
    real(real64)::leaf_loss_kg_ha=0.0_real64
    real(real64)::stem_loss_kg_ha=0.0_real64
    real(real64)::root_loss_kg_ha=0.0_real64
    real(real64)::balance_residual_kg_ha=0.0_real64
  end type

  public::initialize_b111_crop_n_state,prepare_b111_crop_n_request,apply_b111_crop_n_day

contains

  subroutine initialize_b111_crop_n_state(anlv,anst,anrt,anso,state,status)
    real(real64),intent(in)::anlv,anst,anrt,anso
    type(b111_crop_n_state_t),intent(out)::state
    integer,intent(out)::status
    state=b111_crop_n_state_t();status=B111_CROPN_INVALID
    if(.not.all(ieee_is_finite([anlv,anst,anrt,anso])).or.min(anlv,anst,anrt,anso)<0.0_real64)return
    state%anlv_kg_ha=anlv;state%anst_kg_ha=anst;state%anrt_kg_ha=anrt;state%anso_kg_ha=anso
    state%initial_n_kg_ha=anlv+anst+anrt+anso
    status=B111_CROPN_OK
  end subroutine

  pure logical function crop_n_valid(self) result(ok)
    class(b111_crop_n_state_t),intent(in)::self
    real(real64)::v(10)
    v=[self%anlv_kg_ha,self%anst_kg_ha,self%anrt_kg_ha,self%anso_kg_ha,self%nuptake_total_kg_ha, &
       self%nfix_total_kg_ha,self%nloss_leaf_kg_ha,self%nloss_stem_kg_ha,self%nloss_root_kg_ha,self%initial_n_kg_ha]
    ok=all(ieee_is_finite(v)).and.all(v>=0.0_real64)
  end function

  pure real(real64) function crop_n_balance_residual(self) result(r)
    class(b111_crop_n_state_t),intent(in)::self
    r=self%initial_n_kg_ha+self%nuptake_total_kg_ha+self%nfix_total_kg_ha- &
      (self%anlv_kg_ha+self%anst_kg_ha+self%anrt_kg_ha+self%anso_kg_ha)- &
      (self%nloss_leaf_kg_ha+self%nloss_stem_kg_ha+self%nloss_root_kg_ha)
  end function

  subroutine prepare_b111_crop_n_request(committed,f,request)
    type(b111_crop_n_state_t),intent(in)::committed
    type(b111_crop_n_forcing_t),intent(in)::f
    type(b111_crop_n_request_t),intent(out)::request
    type(b111_nfix_request_t)::fixreq
    real(real64)::nlimit

    request=b111_crop_n_request_t()
    if(.not.committed%valid().or..not.valid_forcing(f))return
    request%ndeml_kg_ha=max(f%nmaxlv*f%wlv_kg_ha-committed%anlv_kg_ha,0.0_real64)
    request%ndems_kg_ha=max(f%nmaxst*f%wst_kg_ha-committed%anst_kg_ha,0.0_real64)
    request%ndemr_kg_ha=max(f%nmaxrt*f%wrt_kg_ha-committed%anrt_kg_ha,0.0_real64)
    request%ndemso_kg_ha_day=max(f%nmaxso*f%wso_kg_ha-committed%anso_kg_ha,0.0_real64)/f%tcnt_day
    request%vegetative_demand_kg_ha=max(0.0_real64,request%ndeml_kg_ha+request%ndems_kg_ha+request%ndemr_kg_ha)
    nlimit=merge(1.0_real64,0.0_real64,f%dvs<f%dvsnlt.and.f%reltr>0.01_real64)
    request%soil_demand_kg_ha=(1.0_real64-f%nfixf)*request%vegetative_demand_kg_ha*nlimit
    call prepare_b111_nfix_request(f%dvs,f%reltr,f%dvsnlt,f%nfixf,f%wlv_kg_ha,f%wst_kg_ha,f%wrt_kg_ha, &
         f%nmaxlv,f%nmaxst,f%nmaxrt,committed%anlv_kg_ha,committed%anst_kg_ha,committed%anrt_kg_ha,fixreq)
    if(fixreq%status/=B111_NFIX_OK)return
    request%fixation_demand_kg_ha=fixreq%fixation_request
    request%status=B111_CROPN_OK
  end subroutine

  subroutine apply_b111_crop_n_day(committed,f,candidate,receipt)
    type(b111_crop_n_state_t),intent(in)::committed
    type(b111_crop_n_forcing_t),intent(in)::f
    type(b111_crop_n_state_t),intent(out)::candidate
    type(b111_crop_n_receipt_t),intent(out)::receipt
    type(b111_crop_n_request_t)::request
    real(real64)::ndeml,ndems,ndemr,ndemso,ndemto,nuptr,nfixtr
    real(real64)::atnlv,atnst,atnrt,atn,nsupso,rnso,rntlv,rntst,rntrt
    real(real64)::rnulv,rnust,rnurt,rnldlv,rnldst,rnldrt
    real(real64)::tol,scale

    candidate=committed;receipt=b111_crop_n_receipt_t()
    if(.not.committed%valid().or..not.valid_forcing(f))return

    call prepare_b111_crop_n_request(committed,f,request)
    if(request%status/=B111_CROPN_OK)return
    ndeml=request%ndeml_kg_ha;ndems=request%ndems_kg_ha;ndemr=request%ndemr_kg_ha
    ndemso=request%ndemso_kg_ha_day;ndemto=request%vegetative_demand_kg_ha
    receipt%vegetative_demand_kg_ha=request%vegetative_demand_kg_ha
    receipt%soil_demand_kg_ha=request%soil_demand_kg_ha
    receipt%fixation_kg_ha=request%fixation_demand_kg_ha
    nuptr=max(0.0_real64,min(receipt%soil_demand_kg_ha,f%soil_supply_kg_m2_day*1.0e4_real64))/f%delt_day
    nfixtr=receipt%fixation_kg_ha/f%delt_day

    atnlv=max(0.0_real64,committed%anlv_kg_ha-f%wlv_kg_ha*f%rnflv)
    atnst=max(0.0_real64,committed%anst_kg_ha-f%wst_kg_ha*f%rnfst)
    atnrt=max((atnlv+atnst)*f%fntrt,committed%anrt_kg_ha-f%wrt_kg_ha*f%rnfrt)
    atn=atnlv+atnst+atnrt
    nsupso=merge(atn/f%tcnt_day,0.0_real64,f%dvs>=f%dvsnt)
    rnso=min(ndemso,nsupso)

    rntlv=0.0_real64;rntst=0.0_real64;rntrt=0.0_real64
    if(atn>1.0e-5_real64)then
      rntlv=rnso*atnlv/atn;rntst=rnso*atnst/atn;rntrt=rnso*atnrt/atn
    end if
    rnulv=0.0_real64;rnust=0.0_real64;rnurt=0.0_real64
    if(ndemto>1.0e-5_real64)then
      rnulv=(ndeml/ndemto)*(nuptr+nfixtr)
      rnust=(ndems/ndemto)*(nuptr+nfixtr)
      rnurt=(ndemr/ndemto)*(nuptr+nfixtr)
    end if
    rnldlv=f%rnflv*f%drlv_kg_ha_day
    rnldst=f%rnfst*f%drst_kg_ha_day
    rnldrt=f%rnfrt*f%drrt_kg_ha_day

    candidate%anlv_kg_ha=max(0.0_real64,committed%anlv_kg_ha+(rnulv-rntlv-rnldlv)*f%delt_day)
    candidate%anst_kg_ha=max(0.0_real64,committed%anst_kg_ha+(rnust-rntst-rnldst)*f%delt_day)
    candidate%anrt_kg_ha=max(0.0_real64,committed%anrt_kg_ha+(rnurt-rntrt-rnldrt)*f%delt_day)
    candidate%anso_kg_ha=committed%anso_kg_ha+rnso*f%delt_day
    candidate%nuptake_total_kg_ha=committed%nuptake_total_kg_ha+nuptr*f%delt_day
    candidate%nfix_total_kg_ha=committed%nfix_total_kg_ha+nfixtr*f%delt_day
    candidate%nloss_leaf_kg_ha=committed%nloss_leaf_kg_ha+rnldlv*f%delt_day
    candidate%nloss_stem_kg_ha=committed%nloss_stem_kg_ha+rnldst*f%delt_day
    candidate%nloss_root_kg_ha=committed%nloss_root_kg_ha+rnldrt*f%delt_day
    receipt%soil_uptake_kg_ha=nuptr*f%delt_day
    receipt%storage_uptake_kg_ha=rnso*f%delt_day
    receipt%leaf_loss_kg_ha=rnldlv*f%delt_day
    receipt%stem_loss_kg_ha=rnldst*f%delt_day
    receipt%root_loss_kg_ha=rnldrt*f%delt_day
    receipt%loss_kg_ha=receipt%leaf_loss_kg_ha+receipt%stem_loss_kg_ha+receipt%root_loss_kg_ha
    receipt%balance_residual_kg_ha=candidate%balance_residual()

    scale=max(1.0_real64,candidate%initial_n_kg_ha+candidate%nuptake_total_kg_ha+candidate%nfix_total_kg_ha)
    tol=4096.0_real64*epsilon(1.0_real64)*scale
    if(.not.candidate%valid().or.abs(receipt%balance_residual_kg_ha)>tol)then
      candidate=committed
      receipt%status=B111_CROPN_BALANCE
      return
    end if
    receipt%status=B111_CROPN_OK
  end subroutine

  pure logical function valid_forcing(f) result(ok)
    type(b111_crop_n_forcing_t),intent(in)::f
    real(real64)::v(23)
    v=[f%delt_day,f%dvs,f%reltr,f%dvsnlt,f%dvsnt,f%nfixf,f%tcnt_day,f%fntrt, &
       f%wlv_kg_ha,f%wst_kg_ha,f%wrt_kg_ha,f%wso_kg_ha,f%nmaxlv,f%nmaxst,f%nmaxrt,f%nmaxso, &
       f%rnflv,f%rnfst,f%rnfrt,f%drlv_kg_ha_day,f%drst_kg_ha_day,f%drrt_kg_ha_day,f%soil_supply_kg_m2_day]
    ok=all(ieee_is_finite(v)).and.f%delt_day>0.0_real64.and.f%tcnt_day>0.0_real64.and. &
       f%nfixf>=0.0_real64.and.f%nfixf<=1.0_real64.and.f%fntrt>=0.0_real64.and. &
       f%reltr>=0.0_real64.and.min(f%wlv_kg_ha,f%wst_kg_ha,f%wrt_kg_ha,f%wso_kg_ha, &
       f%nmaxlv,f%nmaxst,f%nmaxrt,f%nmaxso,f%rnflv,f%rnfst,f%rnfrt,f%drlv_kg_ha_day, &
       f%drst_kg_ha_day,f%drrt_kg_ha_day,f%soil_supply_kg_m2_day)>=0.0_real64
  end function
end module
