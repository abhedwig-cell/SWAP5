"""NASA QC bit contracts, including saturated main retrieval and fill values."""
import unittest
import numpy as np

from collect_modis_lai import flags


class QualityFlags(unittest.TestCase):
    def test_main_saturation_is_usable_but_backup_and_fill_are_not(self):
        numeric,main,strict = flags(np.array([20,20,20,255],dtype=np.uint8),
                                  np.array([0,32,64,0],dtype=np.uint8),np.zeros(4,dtype=np.uint8))
        self.assertEqual(numeric.tolist(),[True,True,True,False])
        self.assertEqual(main.tolist(),[True,True,False,False])
        self.assertEqual(strict.tolist(),[True,True,False,False])

    def test_cloud_detector_land_water_flags_stay_distinct(self):
        _,main,strict = flags(np.array([10]*5,dtype=np.uint8),
                              np.array([0,8,4,0,0],dtype=np.uint8),
                              np.array([128,0,0,2,32],dtype=np.uint8))
        self.assertEqual(main.tolist(),[True]*5)
        self.assertEqual(strict.tolist(),[True,False,False,False,False])


if __name__ == '__main__':
    unittest.main()
