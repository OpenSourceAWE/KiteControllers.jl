# Clears the correction vector in the fpp_settings yaml file by writing a
# single-element zero vector (equivalent to no corrections applied).

using Pkg
if ! ("ControlPlots" ∈ keys(Pkg.project().dependencies))
    Pkg.activate(@__DIR__)
end
using KiteControllers, YAML

function read_project()
    config_file = joinpath(get_data_path(), "gui.yaml")
    dict = YAML.load_file(config_file)
    dict["gui"]["project"]
end

PROJECT = read_project()
KiteUtils.PROJECT = PROJECT

KiteControllers.save_corr([0.0])
println("Correction vector cleared (set to [0.0]) in $(KiteControllers.fpp_settings()).")
