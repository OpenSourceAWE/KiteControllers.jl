using Pkg
if ! ("MakieControlPlots" ∈ keys(Pkg.project().dependencies))
    Pkg.activate(@__DIR__)
end

@info "Loading packages ..."
using BenchmarkTools, MakieControlPlots, KiteModels, KitePodModels, KiteUtils, KiteViewers,
      NLsolve, PackageCompiler, Parameters, StaticArrays, Statistics, StructTypes,
      WinchModels, WinchControllers, YAML

@info "Creating sysimage ..."
push!(LOAD_PATH,joinpath(pwd(),"src"))

GC.gc(true)
let mem = Sys.free_memory() / 1024^2
    @info "Free memory: $(round(mem; digits=1)) MB"
    if haskey(ENV, "JULIA_IMAGE_THREADS")
        @info "JULIA_IMAGE_THREADS: $(ENV["JULIA_IMAGE_THREADS"])"
    else
        @info "JULIA_IMAGE_THREADS not defined!"
    end
end

precompile_script = joinpath("test", "precompile_all.jl")
open(precompile_script, "w") do io
    println(io, """include("test_for_precompile.jl")""")
    println(io, """include("precompile_batch_plot.jl")""")
end

PackageCompiler.create_sysimage(
  [:KiteUtils, :NLsolve, :Parameters, :StaticArrays, :WinchModels, :WinchControllers,
   :KiteViewers, :KiteModels, :KitePodModels, :StructTypes, :YAML, :Statistics, :MakieControlPlots];
    sysimage_path="kps-image_tmp.so",
    include_transitive_dependencies=true,
    precompile_execution_file=precompile_script,
    # PackageCompiler 2.4.1+ defaults to the multi-target CPU list of the Julia binary on
    # Julia 1.13+, which compiles every function several times and needs more than twice
    # the memory and time (JuliaLang/julia#63141); build for this machine only, as on 1.12
    cpu_target="native"
)
