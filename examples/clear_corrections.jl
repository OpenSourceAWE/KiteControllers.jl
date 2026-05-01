# Clears the correction vector in the fpp_settings yaml file by writing a
# single-element zero vector (equivalent to no corrections applied).

using Pkg
if ! ("ControlPlots" ∈ keys(Pkg.project().dependencies))
    Pkg.activate(@__DIR__)
end
using KiteControllers, YAML

PROJECT = read_project()
KiteUtils.PROJECT = PROJECT

KiteControllers.save_corr([0.0])
println("Correction vector cleared (set to [0.0]) in $(KiteControllers.fpp_settings()).")
