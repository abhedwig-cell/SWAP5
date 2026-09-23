using Ribasim
import BasicModelInterface as BMI

const DURATION = 21600.0
const FULL_TOL = 1.0e-6
const MASS_TOL = 1.0e-8
const STORAGE_TOL = 1.0e-10
const LIMITED_GAP = 1.0e-6

const CASES = [
    (id="E1_POSITIVE_DRAINAGE", requested=0.0025, kind=:drainage),
    (id="E2_NEGATIVE_INFILTRATION_SUFFICIENT", requested=-0.0025, kind=:infiltration),
    (id="E3_NEGATIVE_INFILTRATION_LIMITED", requested=-0.0025, kind=:limited),
]

require(x::Bool, msg::AbstractString) = x || error(msg)

function one(model, name)
    v = BMI.get_value_ptr(model, name)
    require(length(v) == 1, "G7 requires exactly one $name")
    return Float64(v[1])
end

function physical_run(path, kind; override_infiltration=nothing)
    model = BMI.initialize(Ribasim.Model, path)
    try
        if override_infiltration !== nothing
            v = BMI.get_value_ptr(model, "basin.infiltration")
            require(length(v) == 1, "G7 recomposition requires one infiltration forcing")
            v[1] = override_infiltration / DURATION
        end
        initial_level = one(model, "basin.level")
        initial_storage = one(model, "basin.storage")
        initial_drain = one(model, "basin.cumulative_drainage")
        initial_inf = one(model, "basin.cumulative_infiltration")

        BMI.update_until(model, DURATION)
        require(isapprox(BMI.get_current_time(model), DURATION; atol=1e-8, rtol=0.0), "$(case.id) endpoint")

        final_storage = one(model, "basin.storage")
        drain = one(model, "basin.cumulative_drainage") - initial_drain
        inf = one(model, "basin.cumulative_infiltration") - initial_inf
        signed_realized = drain - inf
        residual = final_storage - initial_storage - drain + inf

        require(abs(residual) <= MASS_TOL, "$(case.id) mass residual $residual")
        require(final_storage >= -STORAGE_TOL, "$(case.id) negative storage $final_storage")

        return (
            initial_level=initial_level,
            initial_storage=initial_storage,
            final_storage=final_storage,
            drain=drain,
            inf=inf,
            signed_realized=signed_realized,
            residual=residual,
        )
    finally
        BMI.finalize(model)
    end
end

function run_case(root, case)
    path = joinpath(root, case.id, "ribasim.toml")
    first = physical_run(path, case.kind)
    require(abs(first.residual) <= MASS_TOL, "$(case.id) first mass residual")
    require(first.final_storage >= -STORAGE_TOL, "$(case.id) first negative storage")

    second_realized = first.signed_realized
    second_residual = first.residual

    if case.kind == :drainage
        require(abs(first.signed_realized - case.requested) <= FULL_TOL, "$(case.id) full drainage realization")
    elseif case.kind == :infiltration
        require(abs(first.signed_realized - case.requested) <= FULL_TOL, "$(case.id) full infiltration realization")
    else
        require(first.signed_realized < 0.0, "$(case.id) expected outward transfer")
        require(abs(first.signed_realized) < abs(case.requested) - LIMITED_GAP, "$(case.id) not availability limited")
        second = physical_run(path, case.kind; override_infiltration=abs(first.signed_realized))
        second_realized = second.signed_realized
        second_residual = second.residual
        require(abs(second_residual) <= MASS_TOL, "$(case.id) recomposed mass residual")
        require(second.final_storage >= -STORAGE_TOL, "$(case.id) recomposed negative storage")
        require(abs(second_realized - first.signed_realized) <= FULL_TOL,
            "$(case.id) same-origin Ribasim recomposition did not realize adjusted request")
        println("SW_RIB_ADM01_G7_RIBASIM_SAME_ORIGIN_RECOMPOSITION=PASS")
    end

    println("G7_RECEIPT,$(case.id),$(100.0*first.initial_level),$(case.requested),$(first.signed_realized),$second_realized,$second_residual")
    println("SW_RIB_ADM01_G7_PHYSICAL_CASE_PASS=$(case.id)")
end

function main()
    length(ARGS) == 1 || error("usage: adm01_g7_realization.jl <model-root>")
    root = abspath(ARGS[1])
    for case in CASES
        run_case(root, case)
    end
    println("SW_RIB_ADM01_G7_REAL_RIBASIM=PASS")
end

main()
