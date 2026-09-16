! F-CI06 materialized SWAP postimage.
! The source is split into ordered include chunks only to keep repository writes
! bounded; tools/fci/fci06_apply_controlled_source_port.py concatenates the four
! chunks into the exact normalized postimage used for source qualification.
include 'swap_part01.inc'
include 'swap_part02.inc'
include 'swap_part03.inc'
include 'swap_part04.inc'
