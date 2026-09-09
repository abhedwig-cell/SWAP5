from __future__ import annotations

from dataclasses import dataclass

from run_lmfp02_testbench import B110Material

SOURCE_ARCHIVE_SHA256 = "2b48353db6cdf00246a1e5c0dcaafc2c61858729fad18446a1dc66359ec2a360"
SOURCE_MEMBER = "SWAP_4.3.1/data/soil/Staringreeks_2018.csv"
SOURCE_MEMBER_SHA256 = "12234a25374b0a47a20e5fcee0577132895f263a77e0f60f5eb4f2fcb5f9ecae"


@dataclass(frozen=True)
class CatalogRow:
    sfu: str
    ores: float
    osat: float
    alfa: float
    npar: float
    ksatfit: float
    ksatexm: float
    lexp: float
    h_enpr: float


CATALOG = (
    CatalogRow("B01", 0.02, 0.427494, 0.021659, 1.734737, 31.225016, 312.25016, 0.98087, 0.0),
    CatalogRow("B02", 0.02, 0.433878, 0.021645, 1.34877, 83.241635, 832.41635, 7.202077, 0.0),
    CatalogRow("B03", 0.02, 0.44279, 0.014993, 1.50488, 19.077237, 190.77237, 0.139209, 0.0),
    CatalogRow("B04", 0.02, 0.461926, 0.01488, 1.39685, 34.884276, 348.84276, 0.294536, 0.0),
    CatalogRow("B05", 0.01, 0.380881, 0.042807, 1.8078, 63.650403, 636.50403, 0.024227, 0.0),
    CatalogRow("B06", 0.01, 0.384816, 0.020923, 1.24225, 104.103005, 1041.03005, -1.20013, 0.0),
    CatalogRow("B07", 0.0, 0.400582, 0.018349, 1.248279, 14.582327, 510.381445, 0.952016, 0.0),
    CatalogRow("B08", 0.01, 0.432651, 0.010478, 1.277992, 3.002741, 105.095935, -1.919289, 0.0),
    CatalogRow("B09", 0.0, 0.429539, 0.006964, 1.267179, 1.747586, 61.16551, -2.387059, 0.0),
    CatalogRow("B10", 0.01, 0.448112, 0.012834, 1.13525, 3.832283, 306.58264, 4.580513, 0.0),
    CatalogRow("B11", 0.01, 0.591286, 0.02162, 1.106695, 6.30532, 504.4256, -5.549216, 0.0),
    CatalogRow("B12", 0.01, 0.529749, 0.016562, 1.090671, 2.245895, 179.6716, -4.493581, 0.0),
    CatalogRow("B13", 0.01, 0.416084, 0.008362, 1.437024, 29.832408, 59.664816, -1.356913, 0.0),
    CatalogRow("B14", 0.01, 0.416774, 0.00541, 1.301528, 0.895023, 1.790046, -0.334926, 0.0),
    CatalogRow("B15", 0.01, 0.528458, 0.023731, 1.282347, 87.450789, 262.352367, -1.477564, 0.0),
    CatalogRow("B16", 0.01, 0.786061, 0.021072, 1.278798, 12.357246, 37.071738, -1.220936, 0.0),
    CatalogRow("B17", 0.0, 0.718626, 0.019062, 1.136658, 4.483735, 13.451205, 0.0001, 0.0),
    CatalogRow("B18", 0.0, 0.765452, 0.020468, 1.150709, 13.144562, 39.433686, 0.0001, 0.0),
    CatalogRow("O01", 0.01, 0.365847, 0.015987, 2.162751, 22.322154, 223.22154, 2.867967, 0.0),
    CatalogRow("O02", 0.02, 0.387064, 0.016083, 1.524418, 22.761756, 227.61756, 2.439662, 0.0),
    CatalogRow("O03", 0.01, 0.33981, 0.017243, 1.703395, 12.36681, 123.6681, 0.0001, 0.0),
    CatalogRow("O04", 0.01, 0.364074, 0.013642, 1.48844, 25.814715, 258.14715, 2.179397, 0.0),
    CatalogRow("O05", 0.01, 0.336701, 0.030304, 2.887502, 17.418504, 174.18504, 0.0736, 0.0),
    CatalogRow("O06", 0.01, 0.333434, 0.015959, 1.288705, 32.833899, 328.33899, -1.009748, 0.0),
    CatalogRow("O07", 0.01, 0.513126, 0.011985, 1.153018, 37.55042, 375.5042, -2.013289, 0.0),
    CatalogRow("O08", 0.0, 0.453751, 0.011324, 1.345968, 8.64086, 302.4301, -0.903823, 0.0),
    CatalogRow("O09", 0.0, 0.458246, 0.009715, 1.375784, 3.766627, 131.831945, -1.013083, 0.0),
    CatalogRow("O10", 0.01, 0.472343, 0.010048, 1.245691, 2.300067, 80.502345, -0.792959, 0.0),
    CatalogRow("O11", 0.0, 0.443617, 0.014316, 1.126001, 2.122436, 169.79488, 2.357139, 0.0),
    CatalogRow("O12", 0.01, 0.560703, 0.008813, 1.158128, 1.079729, 86.37832, -3.172265, 0.0),
    CatalogRow("O13", 0.01, 0.573268, 0.027854, 1.079952, 9.689291, 775.14328, -6.091311, 0.0),
    CatalogRow("O14", 0.01, 0.393878, 0.003288, 1.616573, 2.495984, 4.991968, 0.514012, 0.0),
    CatalogRow("O15", 0.01, 0.410058, 0.007756, 1.287343, 2.791251, 5.582502, 0.0001, 0.0),
    CatalogRow("O16", 0.0, 0.889246, 0.009711, 1.363576, 1.462624, 4.387872, -0.664647, 0.0),
    CatalogRow("O17", 0.01, 0.848635, 0.011929, 1.271536, 3.402009, 10.206027, -1.2493, 0.0),
    CatalogRow("O18", 0.01, 0.580278, 0.012657, 1.316172, 35.951279, 107.853837, -0.785534, 0.0),
)

CATALOG_BY_ID = {row.sfu: row for row in CATALOG}


def b110_material(row: CatalogRow) -> B110Material:
    """Map source-bound Staringreeks_2018 fields into the F-LMFP B110 evaluator."""
    if row.h_enpr != 0.0:
        raise ValueError(("catalog_h_enpr_requires_mapping_review", row.sfu, row.h_enpr))
    vals = [0.0] * 24
    vals[0] = row.ores
    vals[1] = row.osat
    vals[2] = row.ksatfit
    vals[3] = row.alfa
    vals[4] = row.lexp
    vals[5] = row.npar
    vals[6] = 1.0 - 1.0 / row.npar
    vals[8] = row.h_enpr
    vals[9] = row.ksatexm
    return B110Material.from_input(vals)


def validate_catalog() -> None:
    assert len(CATALOG) == 36
    assert len(CATALOG_BY_ID) == len(CATALOG)
    assert tuple(row.sfu for row in CATALOG[:18]) == tuple(f"B{i:02d}" for i in range(1, 19))
    assert tuple(row.sfu for row in CATALOG[18:]) == tuple(f"O{i:02d}" for i in range(1, 19))
    for row in CATALOG:
        assert 0.0 <= row.ores < row.osat <= 1.0
        assert row.alfa > 0.0
        assert row.npar > 1.0
        assert row.ksatfit > 0.0
        assert row.ksatexm > 0.0
        assert -25.0 <= row.lexp <= 25.0
        assert -40.0 <= row.h_enpr <= 0.0


validate_catalog()
