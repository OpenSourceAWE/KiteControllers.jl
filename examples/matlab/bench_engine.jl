# Measure the cost of calling Matlab from Julia through the Matlab engine (MATLAB.jl), as done in
# step 0 of PlanMatlab.md. Every engEvalString costs milliseconds, so the number of engine calls
# per Matlab call decides the speed. eval_string checks for Matlab exceptions by default, which
# needs another eval and two reads.
using Pkg
if dirname(Pkg.project().path) != @__DIR__
    Pkg.activate(@__DIR__)
end
using MATLAB, Statistics, Printf

const N = 500

matlab_dir = @__DIR__
mat"addpath($matlab_dir)"
println(mat"version")

p = Dict("gear_ratio" => 6.2, "drum_radius" => 0.1615, "inertia_total" => 0.024,
         "max_force" => 4000.0, "brake_acc" => -25.0)
x = [2.0, 1000.0, 2.1, 1.0, 0.0, 2.0]
mxcall(:bench_step_vec, 0, p)   # store the parameters once

function measure(f, n)
    f() # warm-up
    t = zeros(n)
    for i in 1:n
        t[i] = @elapsed f()
    end
    t .* 1e3
end

# one eval without the exception check of MATLAB.jl
function eval_unchecked(cmd)
    session = get_default_msession()
    MATLAB.disable_exception_check!(session)
    try
        eval_string(session, cmd)
    finally
        MATLAB.enable_exception_check!(session)
    end
end

literal = "[" * join(repr.(x), " ") * "]"
results = [
    "mxcall plus"                => measure(() -> mxcall(:plus, 1, 1.0, 2.0), N),
    "mxcall 7 in, 5 out"         => measure(() -> mxcall(:bench_step, 5, 2.0, 1000.0, 2.1, true, false, 2.0, p), N),
    "mxcall packed"              => measure(() -> mxcall(:bench_step_vec, 1, x), N),
    "eval_string only"           => measure(() -> eval_string("1;"), N),
    "eval_string literal + get"  => measure(() -> begin
        eval_string("y = bench_step_vec($literal);")
        jarray(get_mvariable(:y))
    end, N),
    # what the MatlabMachine does
    "unchecked literal + get"    => measure(() -> begin
        eval_unchecked("y = bench_step_vec($literal);")
        jarray(get_mvariable(:y))
    end, N),
]

for (name, t) in results
    @printf("%-26s median %7.3f ms  p99 %7.3f ms  max %7.3f ms\n",
            name, median(t), quantile(t, 0.99), maximum(t))
end
@printf("budget per time step at 4x real time (dt = 0.05 s): %.1f ms\n", 50 / 4)
eval_string("clear y;")
nothing
