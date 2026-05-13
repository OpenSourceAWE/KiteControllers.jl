# activate the test environment if needed
using Pkg
if ! ("Test" ∈ keys(Pkg.project().dependencies))
    Pkg.activate(@__DIR__)
end
using Test, KiteControllers

using Aqua

@testset "Aqua.jl" begin
    kwargs = (
      stale_deps=(ignore=[:PyCall, :REPL, :Timers],),
      deps_compat=(ignore=[:PyCall],),                 # PyCall is needed for CI to recompile Python
      # piracies=false,                                # the norm function is doing piracy for performance reasons
    )
    if Sys.iswindows()
        kwargs = merge(kwargs, (persistent_tasks=false,))  # false positives on Windows CI
    end
    Aqua.test_all(KiteControllers; kwargs...)
end
