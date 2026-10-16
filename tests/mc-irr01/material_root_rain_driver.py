"""One uncapped DCS1 witness: daily rain must affect the real selected gift."""
from pathlib import Path
import sys

def prepare(root, target):
    sys.path.insert(0, str(root/'tests/mc-irr01'))
    from material_root_cycle_driver import prepare as material
    material(root, target, 2, 1, True)
    source=target.read_text()
    old='tc%file_weather_irrigation_depth%maximum_depth_cm=.04_real64'
    assert source.count(old)==1
    source=source.replace(old,'tc%file_weather_irrigation_depth%maximum_depth_cm=.4_real64')
    anchor='  end subroutine\n  real(real64) function literal_irrigation_theta'
    assert source.count(anchor)==1
    witness='''    if(rain>config%file_weather_irrigation_depth%rainfall_threshold_cm.and. &
        depth>0._real64.and.depth<config%file_weather_irrigation_depth%maximum_depth_cm)then
      call require(abs(depth-(cdef-rain))<1.e-13_real64,'uncapped whole-day rain discriminator')
      write(*,'(a,4es25.16e3)')'MATERIAL_ROOT_UNCAPPED_DAILY_RAIN=',rd%actual_root_depth_cm,cdef,rain,depth
    end if
'''
    source=source.replace(anchor,witness+anchor)
    target.write_text(source)
    return target
