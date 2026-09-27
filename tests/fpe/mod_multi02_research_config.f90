module mod_multi02_research_config
  implicit none
  private
  integer, save :: multi02_workers = 1
  public :: set_multi02_workers, get_multi02_workers
contains
  subroutine set_multi02_workers(value)
    integer, intent(in) :: value
    if(value/=1 .and. value/=2 .and. value/=4) error stop 'MULTI02 invalid worker count'
    multi02_workers=value
  end subroutine set_multi02_workers
  integer function get_multi02_workers() result(value)
    value=multi02_workers
  end function get_multi02_workers
end module mod_multi02_research_config
