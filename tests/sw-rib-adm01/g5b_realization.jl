using Ribasim
import BasicModelInterface as BMI

const DAY = 86400.0
const TRANSFER_TOL = 1.0e-6
const MASS_TOL = 1.0e-8
const STORAGE_TOL = 1.0e-10
const STRICT_DIFFERENCE = 1.0e-6

const CASES = [
    (id="E1_POSITIVE_DRAINAGE", initial_level=-0.5, requested=0.01, kind=:drainage),
    (id="E2_NEGATIVE_INFILTRATION_SUFFICIENT", initial_level=-0.5, requested=0.005, kind=:infiltration),
    (id="E3_NEGATIVE_INFILTRATION_LIMITED", initial_level=-0.998, requested=0.0051, kind=:limited_infiltration),
]

require(c::Bool,m::AbstractString)=c || error(m)
function value(model,name)
    x=BMI.get_value_ptr(model,name)
    require(length(x)==1,"G5B requires one Basin for $name")
    Float64(x[1])
end

function run_case(root,case)
    model=BMI.initialize(Ribasim.Model,joinpath(root,case.id,"ribasim.toml"))
    try
        h0=value(model,"basin.level")
        s0=value(model,"basin.storage")
        d0=value(model,"basin.cumulative_drainage")
        i0=value(model,"basin.cumulative_infiltration")
        require(abs(h0-case.initial_level)<=1e-10,"$(case.id) initial-level drift")

        BMI.update_until(model,DAY)
        require(isapprox(BMI.get_current_time(model),DAY;atol=1e-8,rtol=0.0),"$(case.id) endpoint")

        s1=value(model,"basin.storage")
        dr=value(model,"basin.cumulative_drainage")-d0
        inf=value(model,"basin.cumulative_infiltration")-i0
        residual=(s1-s0)-dr+inf
        require(abs(residual)<=MASS_TOL,"$(case.id) mass residual $residual")

        signed_realized=dr-inf
        signed_requested=case.kind==:drainage ? case.requested : -case.requested

        if case.kind==:drainage
            require(abs(dr-case.requested)<=TRANSFER_TOL,"E1 realization")
            require(abs(inf)<=TRANSFER_TOL,"E1 unexpected infiltration")
        elseif case.kind==:infiltration
            require(abs(inf-case.requested)<=TRANSFER_TOL,"E2 realization")
            require(abs(dr)<=TRANSFER_TOL,"E2 unexpected drainage")
        else
            require(abs(dr)<=TRANSFER_TOL,"E3 unexpected drainage")
            require(inf>=-STORAGE_TOL,"E3 negative infiltration")
            require(inf<case.requested-STRICT_DIFFERENCE,"E3 not availability limited")
            require(inf<=s0+STORAGE_TOL,"E3 exceeds storage")
            require(s1>=-STORAGE_TOL,"E3 negative final storage")
        end

        println("G5B_RECEIPT,$(case.id),$(100.0*h0),$(signed_requested),$(signed_realized),$(residual)")
        println("SW_RIB_ADM01_G5B_PHYSICAL_CASE_PASS=$(case.id)")
    finally
        BMI.finalize(model)
    end
end

length(ARGS)==1 || error("usage: g5b_realization.jl <model-root>")
root=abspath(ARGS[1])
for case in CASES
    run_case(root,case)
end
println("SW_RIB_ADM01_G5B_REAL_RIBASIM_REALIZATION=PASS")
