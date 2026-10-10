# activate the test environment if needed
using Pkg
if dirname(Pkg.project().path) != @__DIR__
    Pkg.activate(@__DIR__)
end
using KiteControllers, KiteModels
using Test

if realpath(pwd()) == realpath(@__DIR__)
    cd("..")
end
KiteUtils.set_data_path("") 

@testset verbose = true "Testing KiteControllers..." begin
    for file in sort(readdir(@__DIR__))
        if isnothing(match(r"^test-.*\.jl$", file))
            continue
        end
        title = titlecase(replace(splitext(file[6:end])[1], "-" => " "))
        title = rpad(title, 25)
        @testset "$title" begin
            Base.include(Module(), joinpath(@__DIR__, file))
        end
    end
end

