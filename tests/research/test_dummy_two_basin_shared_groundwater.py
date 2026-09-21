from __future__ import annotations

import math
import unittest

from dummy_two_basin_shared_groundwater import (
    TwoBasinSharedGroundwaterConfig,
    TwoBasinSharedGroundwaterState,
    equilibrium_head_m,
    exact_state,
    modes,
    path_flows,
    storage_rates,
    total_storage_m3,
)


class TwoBasinSharedGroundwaterTests(unittest.TestCase):
    def config(
        self,
        *,
        C: float = 50.0,
        Kr: float = 20.0,
    ) -> TwoBasinSharedGroundwaterConfig:
        return TwoBasinSharedGroundwaterConfig(
            surface_storage_m2=100.0,
            groundwater_storage_m2=100.0,
            exchange_conductance_m2_per_time=C,
            routing_conductance_m2_per_time=Kr,
        )

    def initial(self) -> TwoBasinSharedGroundwaterState:
        return TwoBasinSharedGroundwaterState(
            basin1_head_m=1.0,
            basin2_head_m=0.0,
            groundwater_head_m=0.4,
        )

    def test_n1_initial_path_flows_match_preregistration(self) -> None:
        q=path_flows(self.config(),self.initial())
        self.assertAlmostEqual(q.routing_1_to_2_m3_per_time,20.0,places=12)
        self.assertAlmostEqual(q.basin1_to_groundwater_m3_per_time,30.0,places=12)
        self.assertAlmostEqual(q.basin2_to_groundwater_m3_per_time,-20.0,places=12)

    def test_n2_initial_component_storage_rates_close_exactly(self) -> None:
        rates=storage_rates(self.config(),self.initial())
        self.assertAlmostEqual(rates.basin1_m3_per_time,-50.0,places=12)
        self.assertAlmostEqual(rates.basin2_m3_per_time,40.0,places=12)
        self.assertAlmostEqual(rates.groundwater_m3_per_time,10.0,places=12)
        self.assertAlmostEqual(rates.total_m3_per_time,0.0,places=12)

    def test_n3_downstream_basin_has_two_equal_initial_inflow_paths(self) -> None:
        q=path_flows(self.config(),self.initial())
        surface_in=q.routing_1_to_2_m3_per_time
        groundwater_in=-q.basin2_to_groundwater_m3_per_time
        self.assertAlmostEqual(surface_in,20.0,places=12)
        self.assertAlmostEqual(groundwater_in,20.0,places=12)
        self.assertAlmostEqual(surface_in,groundwater_in,places=12)

    def test_n4_exact_total_storage_is_conserved_for_all_sampled_times(self) -> None:
        c=self.config()
        initial=self.initial()
        initial_total=total_storage_m3(c,initial)
        self.assertAlmostEqual(initial_total,140.0,places=12)
        for t in (0.0,0.01,0.1,0.5,1.0,2.0,10.0):
            state=exact_state(c,initial,t)
            self.assertAlmostEqual(
                total_storage_m3(c,state),
                initial_total,
                places=10,
            )

    def test_n5_exact_t1_heads_match_preregistration(self) -> None:
        state=exact_state(self.config(),self.initial(),1.0)
        self.assertAlmostEqual(state.basin1_head_m,0.6773891685419139,places=11)
        self.assertAlmostEqual(state.basin2_head_m,0.2708195088013148,places=11)
        self.assertAlmostEqual(state.groundwater_head_m,0.45179132265677135,places=11)

    def test_n6_surface_difference_mode_decays_as_exp_minus_0p9t(self) -> None:
        c=self.config()
        initial=self.initial()
        for t in (0.0,0.2,0.7,1.0,2.0):
            state=exact_state(c,initial,t)
            d=modes(c,state).surface_difference_m
            self.assertAlmostEqual(d,math.exp(-0.9*t),places=11)

    def test_n7_common_surface_groundwater_mode_decays_as_exp_minus_1p5t(self) -> None:
        c=self.config()
        initial=self.initial()
        for t in (0.0,0.2,0.7,1.0,2.0):
            state=exact_state(c,initial,t)
            x=modes(c,state).surface_groundwater_contrast_m
            self.assertAlmostEqual(x,0.1*math.exp(-1.5*t),places=11)

    def test_n8_routing_changes_difference_mode_but_not_common_mode(self) -> None:
        initial=self.initial()
        states=[]
        for Kr in (0.0,20.0,100.0):
            c=self.config(Kr=Kr)
            state=exact_state(c,initial,1.0)
            m=modes(c,state)
            states.append((Kr,state,m))

        reference_mean=states[0][2].surface_mean_m
        reference_hg=states[0][1].groundwater_head_m
        for _,state,m in states[1:]:
            self.assertAlmostEqual(m.surface_mean_m,reference_mean,places=11)
            self.assertAlmostEqual(state.groundwater_head_m,reference_hg,places=11)

        self.assertGreater(
            states[0][2].surface_difference_m,
            states[1][2].surface_difference_m,
        )
        self.assertGreater(
            states[1][2].surface_difference_m,
            states[2][2].surface_difference_m,
        )

    def test_n9_zero_exchange_decouples_groundwater_and_leaves_surface_routing(self) -> None:
        c=self.config(C=0.0,Kr=20.0)
        initial=self.initial()
        state=exact_state(c,initial,1.0)
        m=modes(c,state)

        self.assertAlmostEqual(state.groundwater_head_m,0.4,places=12)
        self.assertAlmostEqual(m.surface_mean_m,0.5,places=12)
        self.assertAlmostEqual(
            m.surface_difference_m,
            math.exp(-0.4),
            places=11,
        )
        self.assertAlmostEqual(total_storage_m3(c,state),140.0,places=10)

    def test_n10_path_signs_and_component_ownership_are_consistent(self) -> None:
        c=self.config()
        state=self.initial()
        q=path_flows(c,state)
        rates=storage_rates(c,state)

        self.assertGreater(q.routing_1_to_2_m3_per_time,0.0)
        self.assertGreater(q.basin1_to_groundwater_m3_per_time,0.0)
        self.assertLess(q.basin2_to_groundwater_m3_per_time,0.0)

        self.assertAlmostEqual(
            rates.basin1_m3_per_time,
            -q.routing_1_to_2_m3_per_time-q.basin1_to_groundwater_m3_per_time,
            places=12,
        )
        self.assertAlmostEqual(
            rates.basin2_m3_per_time,
            q.routing_1_to_2_m3_per_time-q.basin2_to_groundwater_m3_per_time,
            places=12,
        )
        self.assertAlmostEqual(
            rates.groundwater_m3_per_time,
            q.basin1_to_groundwater_m3_per_time+q.basin2_to_groundwater_m3_per_time,
            places=12,
        )

    def test_n11_long_time_limit_is_common_weighted_equilibrium(self) -> None:
        c=self.config()
        initial=self.initial()
        h_eq=equilibrium_head_m(c,initial)
        self.assertAlmostEqual(h_eq,140.0/300.0,places=12)

        state=exact_state(c,initial,50.0)
        self.assertAlmostEqual(state.basin1_head_m,h_eq,places=10)
        self.assertAlmostEqual(state.basin2_head_m,h_eq,places=10)
        self.assertAlmostEqual(state.groundwater_head_m,h_eq,places=10)

    def test_n12_invalid_inputs_are_rejected(self) -> None:
        with self.assertRaises(ValueError):
            TwoBasinSharedGroundwaterConfig(
                surface_storage_m2=0.0,
                groundwater_storage_m2=100.0,
                exchange_conductance_m2_per_time=50.0,
                routing_conductance_m2_per_time=20.0,
            )
        with self.assertRaises(ValueError):
            TwoBasinSharedGroundwaterConfig(
                surface_storage_m2=100.0,
                groundwater_storage_m2=100.0,
                exchange_conductance_m2_per_time=-1.0,
                routing_conductance_m2_per_time=20.0,
            )
        with self.assertRaises(ValueError):
            exact_state(self.config(),self.initial(),-1.0)


if __name__=="__main__":
    unittest.main(verbosity=2)
