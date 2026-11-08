"""Render the isolated Andelst V9 historical matrix-only inflow-cap experiment."""
import json
from pathlib import Path
import build_joint_upper_support_candidate as v9
from build_joint_entry_candidate import ROOT, once, sha

def render(folder):
    shadow=v9.render(folder)
    def edit(name, edits):
        src=ROOT/name
        p=shadow.get(src,folder/name)
        s=(p if p.exists() else src).read_text()
        for old,new in edits:s=once(s,old,new)
        p.parent.mkdir(parents=True,exist_ok=True)
        p.write_text(s)
        shadow[src]=p

    # A conditional limit on matrix inflow only. Keep geometric storage,
    # outflow availability and top-input redistribution on their old bounds.
    edit('src/process/macropore/mod_ppa_wu05a6_top_inflow_limiter.f90',[
      ('  implicit none','  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite\n  implicit none'),
      ('    integer :: num_domains = 0','    real(real64), allocatable :: matrix_only_capacity_cm(:)\n    integer :: num_domains = 0'),
      ('    real(real64) :: requested_top_total, final_top_total, storage_deadband, available_outflow',
       '    real(real64) :: requested_top_total, final_top_total, storage_deadband, available_outflow, inflow_cap, inflow_deadband'),
      ('      if(temporary_storage>request%maximum_storage_cm(id)+storage_deadband .and. inflow_total(id)>0.0_real64)then\n        excess=temporary_storage-request%maximum_storage_cm(id)',
       '''      inflow_cap=request%maximum_storage_cm(id)
      inflow_deadband=storage_deadband
      if(allocated(request%matrix_only_capacity_cm))then
        if(request%potential_matrix_sat_cm(id)>0d0.and. &
           request%potential_top_vertical_cm(id)+request%potential_top_lateral_cm(id)+ &
           request%potential_interflow_sat_cm(id)<request%matrix_only_rate_threshold_cm)then
          if(request%potential_matrix_sat_cm(id)>request%matrix_only_rate_threshold_cm)then
            inflow_cap=request%matrix_only_capacity_cm(id)
            inflow_deadband=1d-7
          end if
        end if
      end if
      if(temporary_storage>inflow_cap+inflow_deadband.and.inflow_total(id)>0d0)then
        excess=temporary_storage-inflow_cap'''),
      ('    real(real64), allocatable :: matrix_only_capacity_cm(:)',
       '    real(real64), allocatable :: matrix_only_capacity_cm(:)\n    real(real64) :: matrix_only_rate_threshold_cm=0d0'),
      ('    nd=request%num_domains\n    storage_deadband',
       '''    nd=request%num_domains
    if(allocated(request%matrix_only_capacity_cm))then
      if(size(request%matrix_only_capacity_cm)/=nd)return
      if(any(.not.ieee_is_finite(request%matrix_only_capacity_cm)))return
      if(any(request%matrix_only_capacity_cm<0d0).or.any(request%matrix_only_capacity_cm>request%maximum_storage_cm))return
    end if
    storage_deadband''')])
    edit('src/process/macropore/mod_ppa_wu05a6_rate_bundle.f90',[
      ('    target%conservative_storage_bounds=source%conservative_storage_bounds',
       '''    target%conservative_storage_bounds=source%conservative_storage_bounds
    target%matrix_only_rate_threshold_cm=source%matrix_only_rate_threshold_cm
    if(allocated(source%matrix_only_capacity_cm))target%matrix_only_capacity_cm=source%matrix_only_capacity_cm''')])
    edit('src/runtime/mod_ppa_wu05a16_inner_macropore_provider.f90',[
      ('    integer::n\n\n    ok=.false.\n    if(present(surface_area_fraction))',
       '    integer::n,id\n    real(real64)::capacity\n\n    ok=.false.\n    if(present(surface_area_fraction))'),
      ('    call evaluate_macropore_rate_bundle(request,rates)',
       '''    block
      use mod_ppa_wu05a6_rapid_drain_rate,only:derive_rapid_volume_under_drain
      allocate(request%limiter%matrix_only_capacity_cm(geometry_current%num_domains))
      request%limiter%matrix_only_capacity_cm=0d0
      request%limiter%matrix_only_rate_threshold_cm=1d-7*self%step_duration
      if(matrix_view%active)then
        do id=1,geometry_current%num_domains
          if(geometry_current%bottom_domain(id)<geometry_current%top_node)cycle
          call derive_rapid_volume_under_drain(matrix_view%groundwater_level_cm,self%z,self%dz, &
            geometry_current%volume_domain_cp(id,:),geometry_current%top_node,geometry_current%bottom_domain(id),capacity,ok)
          if(.not.ok)return
          request%limiter%matrix_only_capacity_cm(id)=min(capacity,request%limiter%maximum_storage_cm(id))
        end do
      end if
    end block
    call evaluate_macropore_rate_bundle(request,rates)''')])
    m=folder/'MODEL.json'; data=json.loads(m.read_text())
    data['rendered_sources_sha256']={str(k.relative_to(ROOT)):sha(p.read_bytes()) for k,p in shadow.items()}
    m.write_text(json.dumps(data,indent=2)+'\n')
    return shadow

if __name__ == '__main__':
    base = v9.previous.previous.previous.previous.drainage.current.contact.base
    base.render = render
    base.main()
