@testset "copy_files" begin
    mktempdir() do tmpdir
        cd(tmpdir) do
            # copy_files returns the list of files passed
            result = KiteControllers.copy_files("examples", readdir(joinpath(@__DIR__, "..", "examples")))
            @test result isa Vector
            @test length(result) > 0
            # destination directory must exist
            @test isdir("examples")
            # at least one .jl file must be present
            @test any(endswith(f, ".jl") for f in readdir("examples"))
        end
    end
end

@testset "copy_examples" begin
    mktempdir() do tmpdir
        cd(tmpdir) do
            @test !isdir("examples")
            KiteControllers.copy_examples()
            @test isdir("examples")
            files = readdir("examples")
            @test length(files) > 0
            @test any(endswith(f, ".jl") for f in files)
        end
    end
end

@testset "copy_control_settings" begin
    mktempdir() do tmpdir
        cd(tmpdir) do
            @test !isdir("data")
            KiteControllers.copy_control_settings()
            @test isdir("data")
            files = readdir("data")
            @test "settings.yaml" in files
            @test "system.yaml" in files
            @test "fpc_settings.yaml" in files
            @test "fpp_settings.yaml" in files
            @test "wc_settings.yaml" in files
        end
    end
end
