using Ribasim
import BasicModelInterface as BMI

const DURATION = 21600.0
const DURATION_DAY = 0.25
const AREA_M2 = 100.0
const FULL_TOL = 1.0e-6
const MASS_TOL = 1.0e-8
const STORAGE_TOL = 1.0e-10
const FIXED_POINT_TOL = 1.0e-8
const LIMITED_GAP = 1.0e-6
const MAX_ITER = 64
const GWL_CM = -2.25
const RESISTANCE_DAY = 1000.0

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

function physical_run(path, case_id; requested_signed_m3)
    model = BMI.initialize(Ribasim.Model, path)
    try
        # Override the configured vertical forcing for every iteration so the
        # request is explicit and every replay begins from the same model state.
        if requested_signed_m3 > 0.0
            v = BMI.get_value_ptr(model, "basin.drainage")
            require(length(v) == 1, "$case_id requires one drainage forcing")
            v[1] = requested_signed_m3 / DURATION
            inf = BMI.get_value_ptr(model, "basin.infiltration")
            inf[1] = 0.0
        else
            v = BMI.get_value_ptr(model, "basin.infiltration")
            require(length(v) == 1, "$case_id requires one infiltration forcing")
            v[1] = abs(requested_signed_m3) / DURATION
            drn = BMI.get_value_ptr(model, "basin.drainage")
            drn[1] = 0.0
        end

        initial_level = one(model, "basin.level")
        initial_storage = one(model, "basin.storage")
        initial_drain = one(model, "basin.cumulative_drainage")
        initial_inf = one(model, "basin.cumulative_infiltration")

        BMI.update_until(model, DURATION)
        require(isapprox(BMI.get_current_time(model), DURATION; atol=1e-8, rtol=0.0), "$case_id endpoint")

        final_storage = one(model, "basin.storage")
        drainage = one(model, "basin.cumulative_drainage") - initial_drain
        infiltration = one(model, "basin.cumulative_infiltration") - initial_inf
        signed_realized = drainage - infiltration
        residual = final_storage - initial_storage - drainage + infiltration

        require(abs(residual) <= MASS_TOL, "$case_id mass residual $residual")
        require(final_storage >= -STORAGE_TOL, "$case_id negative storage $final_storage")

        return (
            initial_level=initial_level,
            initial_storage=initial_storage,
            final_storage=final_storage,
            drainage=drainage,
            infiltration=infiltration,
            signed_realized=signed_realized,
            residual=residual,
        )
    finally
        BMI.finalize(model)
    end
end

function swap_head_for_request(requested_signed_m3)
    requested_cm = requested_signed_m3 / AREA_M2 * 100.0
    requested_rate_cm_day = requested_cm / DURATION_DAY
    return GWL_CM - requested_rate_cm_day * RESISTANCE_DAY
end

function emit_iteration(case_id, iteration, request, result, disposition)
    head_cm = swap_head_for_request(request)
    println(
        "G7_ITER,$case_id,$iteration,$head_cm,$request,$(result.signed_realized),$(result.residual),$disposition"
    )
end

function run_case(root, case)
    path = joinpath(root, case.id, "ribasim.toml")

    if case.kind != :limited
        result = physical_run(path, case.id; requested_signed_m3=case.requested)
        require(abs(result.signed_realized - case.requested) <= FULL_TOL,
            "$(case.id) full realization mismatch")
        emit_iteration(case.id, 1, case.requested, result, "COMMIT")
        println("SW_RIB_ADM01_G7_PHYSICAL_CASE_PASS=$(case.id)")
        return
    end

    request = case.requested
    first_recompose = false
    converged = false
    final_iteration = 0

    for iteration in 1:MAX_ITER
        result = physical_run(path, case.id; requested_signed_m3=request)
        difference = abs(result.signed_realized - request)

        if iteration == 1
            require(result.signed_realized < 0.0, "$(case.id) expected outward transfer")
            require(abs(result.signed_realized) < abs(request) - LIMITED_GAP,
                "$(case.id) first realization not availability limited")
        end

        if difference <= FIXED_POINT_TOL
            emit_iteration(case.id, iteration, request, result, "COMMIT")
            converged = true
            final_iteration = iteration
            break
        else
            emit_iteration(case.id, iteration, request, result, "RECOMPOSE")
            first_recompose |= iteration == 1
            request = result.signed_realized
        end
    end

    require(first_recompose, "$(case.id) first iteration did not require recomposition")
    require(converged, "$(case.id) failed to converge within $MAX_ITER same-origin iterations")
    require(final_iteration > 1, "$(case.id) unexpectedly converged without recomposition")
    println("SW_RIB_ADM01_G7_RIBASIM_SAME_ORIGIN_RECOMPOSITION=PASS iterations=$final_iteration")
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
