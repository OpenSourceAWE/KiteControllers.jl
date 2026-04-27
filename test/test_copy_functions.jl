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
            @test !any(startswith(f, "Manifest") for f in files)
        end
    end
end

@testset "copy_control_settings" begin
    saved_data_path = KiteUtils.get_data_path()
    mktempdir() do tmpdir
        cd(tmpdir) do
            try
                @test !isdir("data")
                KiteControllers.copy_control_settings()
                @test isdir("data")
                files = readdir("data")
                @test "settings.yaml" in files
                @test "system.yaml" in files
                @test "fpc_settings.yaml" in files
                @test "fpp_settings.yaml" in files
                @test "wc_settings.yaml" in files
            finally
                KiteUtils.set_data_path(saved_data_path)
            end
        end
    end
end

@testset "copy_bin" begin
    mktempdir() do tmpdir
        cd(tmpdir) do
            @test !isdir("bin")
            KiteControllers.copy_bin()
            @test isdir("bin")
            files = readdir("bin")
            @test "run_julia" in files
            @test "setup_env" in files
            # run_julia must be executable (Unix only; Windows has no executable bits)
            if !Sys.iswindows()
                @test (filemode(joinpath("bin", "run_julia")) & 0o111) != 0
            end
        end
    end
end

@testset "install_examples" begin
    saved_data_path = KiteUtils.get_data_path()
    mktempdir() do tmpdir
        cd(tmpdir) do
            try
                # add_packages=false to avoid triggering Pkg operations in tests
                KiteControllers.install_examples(false)
                @test isdir("examples")
                @test isdir("data")
                @test isdir("bin")
                @test isdir("output")
                @test any(endswith(f, ".jl") for f in readdir("examples"))
                @test "settings.yaml" in readdir("data")
                @test "run_julia" in readdir("bin")
            finally
                KiteUtils.set_data_path(saved_data_path)
            end
        end
    end
end
