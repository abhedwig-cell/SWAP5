from __future__ import annotations

from fractions import Fraction
import unittest

from coupling_contract_harness import (
    CouplingState,
    InterfaceObservation,
    TileWaterRecord,
    aggregate_tiles,
    canonical_tile_set_hash,
    evaluate_interface,
    run_predictor_corrector,
)


class FMQ07CouplingContractTests(unittest.TestCase):
    def test_p20_two_tile_area_weighted_mass_closes_exactly(self) -> None:
        rows = [
            TileWaterRecord("soil", Fraction(3, 4), 100, 112, 15, 3),
            TileWaterRecord("open-water", Fraction(1, 4), 50, 46, 1, 5),
        ]
        agg = aggregate_tiles(rows)
        self.assertEqual(agg.storage_change, Fraction(8, 1))
        self.assertEqual(agg.net_boundary, Fraction(8, 1))
        self.assertEqual(agg.residual, 0)

    def test_p20_tile_order_does_not_change_identity_or_aggregate(self) -> None:
        rows = [
            TileWaterRecord("a", Fraction(1, 5), 10, 12, 2, 0),
            TileWaterRecord("b", Fraction(3, 10), 20, 17, 0, 3),
            TileWaterRecord("c", Fraction(1, 2), 30, 35, 7, 2),
        ]
        forward = aggregate_tiles(rows)
        reverse = aggregate_tiles(list(reversed(rows)))
        self.assertEqual(forward, reverse)
        self.assertEqual(canonical_tile_set_hash(rows), canonical_tile_set_hash(reversed(rows)))

    def test_p20_fraction_gap_or_overlap_rejected(self) -> None:
        for fractions in ((Fraction(1, 2), Fraction(2, 5)), (Fraction(3, 5), Fraction(1, 2))):
            rows = [
                TileWaterRecord("a", fractions[0], 10, 11, 1, 0),
                TileWaterRecord("b", fractions[1], 10, 11, 1, 0),
            ]
            with self.assertRaises(ValueError):
                aggregate_tiles(rows)

    def test_p20_nonconserving_tile_rejected_before_aggregation(self) -> None:
        rows = [
            TileWaterRecord("a", Fraction(1, 2), 10, 12, 1, 0),
            TileWaterRecord("b", Fraction(1, 2), 10, 11, 1, 0),
        ]
        with self.assertRaises(ValueError):
            aggregate_tiles(rows)

    def test_p21_rejected_predictor_cannot_change_committed_state(self) -> None:
        initial = CouplingState(1000)
        result = run_predictor_corrector(
            initial,
            predictor_delta=70,
            corrector_delta=25,
            accept_predictor=False,
            accept_corrector=True,
        )
        self.assertEqual(result.initial, initial)
        self.assertEqual(result.trials[0].candidate.water_units, 1070)
        self.assertEqual(result.trials[1].candidate.water_units, 1025)
        self.assertEqual(result.committed.water_units, 1025)
        self.assertEqual(result.commits, 1)
        self.assertEqual(result.committed_flux_into_swap, 25)

    def test_p21_predictor_hint_never_becomes_physical_corrector_origin(self) -> None:
        a = run_predictor_corrector(
            CouplingState(500), predictor_delta=1000, corrector_delta=-20,
            accept_predictor=True, accept_corrector=True
        )
        b = run_predictor_corrector(
            CouplingState(500), predictor_delta=-999, corrector_delta=-20,
            accept_predictor=False, accept_corrector=True
        )
        self.assertEqual(a.committed, b.committed)
        self.assertEqual(a.committed_flux_into_swap, b.committed_flux_into_swap)
        self.assertEqual(a.commits, 1)
        self.assertEqual(b.commits, 1)

    def test_p21_rejected_corrector_rolls_back_everything(self) -> None:
        initial = CouplingState(700)
        result = run_predictor_corrector(
            initial,
            predictor_delta=40,
            corrector_delta=15,
            accept_predictor=False,
            accept_corrector=False,
        )
        self.assertEqual(result.committed, initial)
        self.assertEqual(result.commits, 0)
        self.assertEqual(result.committed_flux_into_swap, 0)
        self.assertEqual(result.rollbacks, 2)

    def test_p22_exact_flux_conservation_and_qualified_head_tolerance(self) -> None:
        result = evaluate_interface(
            InterfaceObservation(h_swap_units=1002, h_mf_units=1000, q_swap_units=37, q_mf_units=-37),
            qualified_head_tolerance_units=2,
        )
        self.assertTrue(result.flux_conserved)
        self.assertEqual(result.flux_residual, 0)
        self.assertTrue(result.head_within_tolerance)
        self.assertTrue(result.accepted)

    def test_p22_flux_defect_is_hard_even_when_head_matches(self) -> None:
        result = evaluate_interface(
            InterfaceObservation(h_swap_units=1000, h_mf_units=1000, q_swap_units=37, q_mf_units=-36),
            qualified_head_tolerance_units=100,
        )
        self.assertFalse(result.flux_conserved)
        self.assertEqual(result.flux_residual, 1)
        self.assertTrue(result.head_within_tolerance)
        self.assertFalse(result.accepted)

    def test_p22_head_residual_is_separate_from_mass_conservation(self) -> None:
        result = evaluate_interface(
            InterfaceObservation(h_swap_units=1010, h_mf_units=1000, q_swap_units=-8, q_mf_units=8),
            qualified_head_tolerance_units=3,
        )
        self.assertTrue(result.flux_conserved)
        self.assertFalse(result.head_within_tolerance)
        self.assertFalse(result.accepted)


if __name__ == "__main__":
    unittest.main(verbosity=2)
