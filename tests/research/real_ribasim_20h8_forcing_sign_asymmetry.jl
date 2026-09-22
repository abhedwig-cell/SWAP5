using Ribasim
using JuMP
import BasicModelInterface as BMI

const DAY = 86400.0
const STORAGE_EXCESS = 7.990372381083688
const FORCING = 8.000042512171305
const ROOT_MEMORY = 39.99037238108369
const EXTERNAL_POSITIVE = 7.990414893254993

const ALLOC_TOL = 0.05
const FACTOR_TOL = 1.0e-6
const STORAGE_TOL = 0.05
const FORCING_TOL = 0.01

function require(condition::Bool, message::AbstractString)
    condition || error(message)
end

function inspect_case(
        path::AbstractString,
        label::AbstractString;
        infiltration_m3_day::Float64,
        drainage_m3_day::Float64,
    )
    model = BMI.initialize(Ribasim.Model, path)
    (; p_independent) = model.integrator.p
    allocation = p_independent.allocation
    require(length(allocation.allocation_models) == 1, "expected one allocation model")
    am = only(allocation.allocation_models)

    basin_id = Ribasim.NodeID(:Basin, 2, p_independent)
    root_id = Ribasim.NodeID(:UserDemand, 3, p_independent)
    external_id = Ribasim.NodeID(:UserDemand, 4, p_independent)

    infiltration = BMI.get_value_ptr(model, "basin.infiltration")
    drainage = BMI.get_value_ptr(model, "basin.drainage")
    require(length(infiltration) == 1, "expected one Basin infiltration value")
    require(length(drainage) == 1, "expected one Basin drainage value")
    infiltration[1] = infiltration_m3_day / DAY
    drainage[1] = drainage_m3_day / DAY

    Ribasim.update_allocation!(model)

    alpha = JuMP.value(am.problem[:low_storage_factor][basin_id])
    storage_change = JuMP.value(am.problem[:basin_storage_change][basin_id]) * am.scaling.storage
    root_alloc = JuMP.value(
        am.problem[:user_demand_allocated][root_id, Int32(2)]
    ) * am.scaling.flow * DAY
    external_alloc = JuMP.value(
        am.problem[:user_demand_allocated][external_id, Int32(3)]
    ) * am.scaling.flow * DAY
    explicit_positive = am.explicit_positive_forcing_volume[basin_id]
    implicit_negative = am.implicit_negative_forcing_volume[basin_id]

    println(
        "RIBASIM_REAL_20H8_LP label=$label " *
        "infiltration_m3_day=$infiltration_m3_day drainage_m3_day=$drainage_m3_day " *
        "explicit_positive_forcing_m3=$explicit_positive " *
        "implicit_negative_forcing_m3=$implicit_negative " *
        "low_storage_factor=$alpha storage_change_m3=$storage_change " *
        "root_alloc_m3_day=$root_alloc external_alloc_m3_day=$external_alloc"
    )

    BMI.finalize(model)
    return (
        alpha=alpha,
        storage_change=storage_change,
        root=root_alloc,
        external=external_alloc,
        explicit_positive=explicit_positive,
        implicit_negative=implicit_negative,
    )
end

function main()
    length(ARGS) == 1 || error("usage: real_ribasim_20h8_forcing_sign_asymmetry.jl <ribasim.toml>")
    path = abspath(ARGS[1])
    require(isfile(path), "Ribasim input missing")

    control = inspect_case(
        path,
        "control";
        infiltration_m3_day=0.0,
        drainage_m3_day=0.0,
    )
    require(abs(control.explicit_positive) <= FORCING_TOL, "control explicit positive forcing nonzero")
    require(abs(control.implicit_negative) <= FORCING_TOL, "control implicit negative forcing nonzero")
    require(isapprox(control.alpha, 1.0; atol=FACTOR_TOL, rtol=0.0), "control alpha is not 1")
    require(isapprox(control.storage_change, -STORAGE_EXCESS; atol=STORAGE_TOL, rtol=0.0), "control storage draw differs from frozen memory")
    require(isapprox(control.root, ROOT_MEMORY; atol=ALLOC_TOL, rtol=0.0), "control root allocation differs from frozen memory")
    require(isapprox(control.external, 0.0; atol=ALLOC_TOL, rtol=0.0), "control external allocation nonzero")

    negative = inspect_case(
        path,
        "negative_infiltration";
        infiltration_m3_day=FORCING,
        drainage_m3_day=0.0,
    )
    require(abs(negative.explicit_positive) <= FORCING_TOL, "negative case explicit positive forcing nonzero")
    require(isapprox(negative.implicit_negative, FORCING; atol=FORCING_TOL, rtol=0.0), "negative forcing did not reach implicit ledger")
    require(isapprox(negative.alpha, 0.0; atol=FACTOR_TOL, rtol=0.0), "negative forcing alpha did not collapse to 0")
    require(isapprox(negative.storage_change, -STORAGE_EXCESS; atol=STORAGE_TOL, rtol=0.0), "negative case changed accepted storage memory")
    require(isapprox(negative.root, ROOT_MEMORY; atol=ALLOC_TOL, rtol=0.0), "negative case root allocation differs from H6 oracle")
    require(isapprox(negative.external, 0.0; atol=ALLOC_TOL, rtol=0.0), "negative case external allocation nonzero")

    positive = inspect_case(
        path,
        "positive_drainage";
        infiltration_m3_day=0.0,
        drainage_m3_day=FORCING,
    )
    require(isapprox(positive.explicit_positive, FORCING; atol=FORCING_TOL, rtol=0.0), "positive forcing did not reach explicit ledger")
    require(abs(positive.implicit_negative) <= FORCING_TOL, "positive case implicit negative forcing nonzero")
    require(isapprox(positive.alpha, 1.0; atol=FACTOR_TOL, rtol=0.0), "positive forcing alpha is not 1")
    require(isapprox(positive.storage_change, -STORAGE_EXCESS; atol=STORAGE_TOL, rtol=0.0), "positive case changed accepted storage memory")
    require(isapprox(positive.root, 40.0; atol=ALLOC_TOL, rtol=0.0), "positive forcing did not fill root demand")
    require(isapprox(positive.external, EXTERNAL_POSITIVE; atol=ALLOC_TOL, rtol=0.0), "positive forcing external allocation differs from frozen reference")

    require(
        positive.external - negative.external > 7.9,
        "forcing sign did not create the preregistered management asymmetry",
    )

    println(
        "RIBASIM_REAL_20H8_CURRENT_FORCING_SIGN_ASYMMETRY=PASS " *
        "control_root=$(control.root) negative_root=$(negative.root) " *
        "positive_root=$(positive.root) positive_external=$(positive.external) " *
        "negative_alpha=$(negative.alpha) positive_alpha=$(positive.alpha)"
    )
end

main()
