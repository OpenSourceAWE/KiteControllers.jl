using Pkg
if !("Test" ∈ keys(Pkg.project().dependencies))
    Pkg.activate(@__DIR__)
end
using Test, KiteControllers, YAML

function write_gui_default(path::AbstractString; turbulence=0.0)
    open(path, "w") do io
        println(io, "gui:")
        println(io, "    project: hydra20_600.yml")
        println(io, "    default_turbulence: $(turbulence)")
    end
end

_old_data_path = KiteUtils.get_data_path()
try
    @testset "default_turbulence config" begin
        mktempdir() do tmpdir
            KiteUtils.set_data_path(tmpdir)

            gui_yaml = joinpath(tmpdir, "gui.yaml")
            gui_yaml_default = gui_yaml * ".default"
            write_gui_default(gui_yaml_default; turbulence=0.15)

            @test !isfile(gui_yaml)
            @test KiteControllers.get_default_turbulence() ≈ 0.15
            @test isfile(gui_yaml)

            dict = YAML.load_file(gui_yaml)
            @test dict["gui"]["project"] == "hydra20_600.yml"
            @test Float64(dict["gui"]["default_turbulence"]) ≈ 0.15

            @test KiteControllers.set_default_turbulence(0.35) ≈ 0.35

            updated = YAML.load_file(gui_yaml)
            @test updated["gui"]["project"] == "hydra20_600.yml"
            @test Float64(updated["gui"]["default_turbulence"]) ≈ 0.35
            @test KiteControllers.get_default_turbulence() ≈ 0.35
        end
    end
finally
    KiteUtils.set_data_path(_old_data_path)
end

nothing