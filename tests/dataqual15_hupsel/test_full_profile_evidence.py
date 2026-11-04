"""Profile inventory controls against real immutable historical typed data."""
import copy,unittest
from full_profile_evidence import check_points,DAYS
from scientific_followup import native_data

class ProfileBoundary(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  cls.daily,_,cls.points,_,_,_=native_data()
  cls.geometry=copy.deepcopy(cls.points[1096])
 def test_complete_actual_historical_inventory(self):
  proof=check_points(self.points,self.daily,self.geometry)
  self.assertEqual([p['day'] for p in proof],list(DAYS))
 def test_missing_observation(self):
  p=copy.deepcopy(self.points);del p[120]
  with self.assertRaises(AssertionError):check_points(p,self.daily,self.geometry)
 def test_clock_rebinding(self):
  p=copy.deepcopy(self.points);p[120]['day']=121
  with self.assertRaises(AssertionError):check_points(p,self.daily,self.geometry)
 def test_water_donor_mismatch(self):
  p=copy.deepcopy(self.points);p[120]['water_stock_cm']+=1e-6
  with self.assertRaises(AssertionError):check_points(p,self.daily,self.geometry)
 def test_solute_donor_mismatch(self):
  p=copy.deepcopy(self.points);p[120]['solute_stock_mg_cm2']+=1e-6
  with self.assertRaises(AssertionError):check_points(p,self.daily,self.geometry)
 def test_grid_change(self):
  p=copy.deepcopy(self.points);p[120]['dz_cm'][0]+=1e-6
  with self.assertRaises(AssertionError):check_points(p,self.daily,self.geometry)
 def test_extra_observation_is_not_original_schedule(self):
  p=copy.deepcopy(self.points);p[121]=copy.deepcopy(p[120]);p[121]['day']=121
  with self.assertRaises(AssertionError):check_points(p,self.daily,self.geometry)

if __name__=='__main__':unittest.main(verbosity=2)
