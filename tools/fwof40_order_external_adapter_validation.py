#!/usr/bin/env python3
from pathlib import Path
import sys

if len(sys.argv) != 3:
    raise SystemExit('usage: order_external_adapter_validation.py <input> <output>')
src = Path(sys.argv[1]).read_text(encoding='utf-8')

replacements = {
"    if (.not. committed%ready() .or. .not. committed%time_is_bound()) return\n":
"    if (.not. committed%ready()) return\n    if (.not. committed%time_is_bound()) return\n",
"    if (.not. ok .or. persistence_status /= KERNEL_PERSISTENCE_OK .or. .not. snapshot%ready()) return\n":
"    if (.not. ok) return\n    if (persistence_status /= KERNEL_PERSISTENCE_OK) return\n    if (.not. snapshot%ready()) return\n",
"    if (.not. view_ok .or. crop_status /= FMR_WOFOST_CROP_PERSISTENCE_OK .or. .not. view%ready()) return\n":
"    if (.not. view_ok) return\n    if (crop_status /= FMR_WOFOST_CROP_PERSISTENCE_OK) return\n    if (.not. view%ready()) return\n",
"    if (.not. tx_ok .or. crop_status /= FMR_WOFOST_CROP_PERSISTENCE_OK .or. .not. tx_state%ready()) then\n      status = FWO40_EXTERNAL_INVALID_PHYSICAL\n      return\n    end if\n":
"    if (.not. tx_ok) then\n      status = FWO40_EXTERNAL_INVALID_PHYSICAL\n      return\n    end if\n    if (crop_status /= FMR_WOFOST_CROP_PERSISTENCE_OK) then\n      status = FWO40_EXTERNAL_INVALID_PHYSICAL\n      return\n    end if\n    if (.not. tx_state%ready()) then\n      status = FWO40_EXTERNAL_INVALID_PHYSICAL\n      return\n    end if\n",
"    if (.not. snapshot_ok .or. persistence_status /= KERNEL_PERSISTENCE_OK .or. .not. snapshot%ready()) then\n      status = FWO40_EXTERNAL_RECONSTRUCTION_FAILED\n      return\n    end if\n":
"    if (.not. snapshot_ok) then\n      status = FWO40_EXTERNAL_RECONSTRUCTION_FAILED\n      return\n    end if\n    if (persistence_status /= KERNEL_PERSISTENCE_OK) then\n      status = FWO40_EXTERNAL_RECONSTRUCTION_FAILED\n      return\n    end if\n    if (.not. snapshot%ready()) then\n      status = FWO40_EXTERNAL_RECONSTRUCTION_FAILED\n      return\n    end if\n",
"    if (.not. restore_ok .or. persistence_status /= KERNEL_PERSISTENCE_OK .or. .not. committed%ready()) then\n      committed = kernel_committed_state_t()\n      status = FWO40_EXTERNAL_RECONSTRUCTION_FAILED\n      return\n    end if\n":
"    if (.not. restore_ok) then\n      committed = kernel_committed_state_t()\n      status = FWO40_EXTERNAL_RECONSTRUCTION_FAILED\n      return\n    end if\n    if (persistence_status /= KERNEL_PERSISTENCE_OK) then\n      committed = kernel_committed_state_t()\n      status = FWO40_EXTERNAL_RECONSTRUCTION_FAILED\n      return\n    end if\n    if (.not. committed%ready()) then\n      committed = kernel_committed_state_t()\n      status = FWO40_EXTERNAL_RECONSTRUCTION_FAILED\n      return\n    end if\n"
}
for old, new in replacements.items():
    count = src.count(old)
    if count != 1:
        raise SystemExit(f'F-WOF40 adapter ordering anchor count={count}: {old.splitlines()[0]}')
    src = src.replace(old, new, 1)
Path(sys.argv[2]).write_text(src, encoding='utf-8')
print('FWOF40_EXTERNAL_ADAPTER_ORDERED_VALIDATION_MATERIALIZED=PASS')
