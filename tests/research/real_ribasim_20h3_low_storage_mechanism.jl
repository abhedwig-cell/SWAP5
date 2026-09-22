using Ribasim
using JuMP
import BasicModelInterface as BMI

const DAY = 86400.0
const INJECTION = 7.999914667576883
const REDUCED_ROOT = 32.0 - INJECTION
const ALLOC_TOL = 0.05
const FORCING_TOL = 0.01
const ALPHA_TOL = 1.0e-6
const STORAGE_TOL = 0.05

function require(condition::Bool, message::AbstractString)
    condition || error(message)
end

function inspect_case(
        path::AbstractString,
        label::AbstractString;
        infiltration_m3_day::Float64,
        fix_alpha_one::Bool,
    )
    model = BMI.initialize(Ribasim.Model, path)
    (; p_independent) = model.integrator.p
    (; allocation) = p_independent
    require(length(allocation.allocation_models) == 1, "expected one allocation model")
    am = only(allocation.allocation_models)

    basin_id = Ribasim.NodeID(:Basin, 2, p_independent)
    root_id = Ribasim.NodeID(:UserDemand, 3, p_independent)
    external_id = Ribasim.NodeID(:UserDemand, 4, p_independent)

    infiltration = BMI.get_value_ptr(model, "basin.infiltration")
    require(length(infiltration) == 1, "expected one Basin infiltration value")
    infiltration[1] = infiltration_m3_day / DAY
    require(
        isapprox(infiltration[1] * DAY, infiltration_m3_day; atol=FORCING_TOL, rtol=0.0),
        "$label infiltration pointer readback mismatch",
    )

    alpha_var = am.problem[:low_storage_factor][basin_id]
    if fix_alpha_one
        JuMP.fix(alpha_var, 1.0; force=true)
    end

    Ribasim.update_allocation!(model)

    root_alloc = JuMP.value(
        am.problem[:user_demand_allocated][root_id, Int32(2)]
    ) * am.scaling.flow * DAY
    ext_alloc = JuMP.value(
        am.problem[:user_demand_allocated][external_id, Int32(3)]
    ) * am.scaling.flow * DAY
    alpha = JuMP.value(alpha_var)
    storage_change = JuMP.value(
        am.problem[:basin_storage_change][basin_id]
    ) * am.scaling.storage
    implicit_negative = am.implicit_negative_forcing_volume[basin_id]

    println(
        "RIBASIM_REAL_20H3_LP label=$label " *
        "infiltration_m3_day=$infiltration_m3_day " *
        "implicit_negative_forcing_m3=$implicit_negative " *
        "low_storage_factor=$alpha storage_change_m3=$storage_change " *
        "root_alloc_m3_day=$root_alloc external_alloc_m3_day=$ext_alloc"
    )

    BMI.finalize(model)
    return (
        root=root_alloc,
        external=ext_alloc,
        alpha=alpha,
        storage_change=storage_change,
        implicit_negative=implicit_negative,
    )
end

function main()
    length(ARGS) == 1 || error("usage: real_ribasim_20h3_low_storage_mechanism.jl <ribasim.toml>")
    path = abspath(ARGS[1])
    require(isfile(path), "Ribasim input missing")

    control = inspect_case(
        path,
        "control";
        infiltration_m3_day=0.0,
        fix_alpha_one=false,
    )
    require(isapprox(control.root, 32.0; atol=ALLOC_TOL, rtol=0.0), "control root allocation differs from 32")
    require(isapprox(control.external, 0.0; atol=ALLOC_TOL, rtol=0.0), "control external allocation is nonzero")
    require(isapprox(control.alpha, 1.0; atol=ALPHA_TOL, rtol=0.0), "control low_storage_factor is not 1")
    require(abs(control.implicit_negative) <= FORCING_TOL, "control implicit negative forcing is nonzero")
    require(abs(control.storage_change) <= STORAGE_TOL, "control storage change is nonzero")

    free_case = inspect_case(
        path,
        "injected_free_alpha";
        infiltration_m3_day=INJECTION,
        fix_alpha_one=false,
    )
    require(isapprox(free_case.implicit_negative, INJECTION; atol=FORCING_TOL, rtol=0.0), "injected forcing did not reach allocation LP")
    require(isapprox(free_case.root, 32.0; atol=ALLOC_TOL, rtol=0.0), "free-alpha root allocation differs from 32")
    require(isapprox(free_case.external, 0.0; atol=ALLOC_TOL, rtol=0.0), "free-alpha external allocation is nonzero")
    require(isapprox(free_case.alpha, 0.0; atol=ALPHA_TOL, rtol=0.0), "free-alpha low_storage_factor did not collapse to 0")
    require(abs(free_case.storage_change) <= STORAGE_TOL, "free-alpha forecast storage change is nonzero")

    fixed_case = inspect_case(
        path,
        "injected_alpha_fixed_one";
        infiltration_m3_day=INJECTION,
        fix_alpha_one=true,
    )
    require(isapprox(fixed_case.implicit_negative, INJECTION; atol=FORCING_TOL, rtol=0.0), "fixed-alpha injected forcing did not reach allocation LP")
    require(isapprox(fixed_case.alpha, 1.0; atol=ALPHA_TOL, rtol=0.0), "fixed-alpha factor is not 1")
    require(isapprox(fixed_case.root, REDUCED_ROOT; atol=ALLOC_TOL, rtol=0.0), "fixed-alpha root allocation differs from 32 minus infiltration")
    require(isapprox(fixed_case.external, 0.0; atol=ALLOC_TOL, rtol=0.0), "fixed-alpha external allocation is nonzero")
    require(abs(fixed_case.storage_change) <= STORAGE_TOL, "fixed-alpha forecast storage change is nonzero")

    require(
        free_case.root - fixed_case.root > 7.0,
        "low_storage_factor intervention did not materially alter root allocation",
    )

    println(
        "RIBASIM_REAL_20H3_MECHANISM=PASS " *
        "free_alpha=$(free_case.alpha) fixed_alpha=$(fixed_case.alpha) " *
        "free_root_m3_day=$(free_case.root) fixed_root_m3_day=$(fixed_case.root)"
    )
end

main()
