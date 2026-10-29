# Run autopilot.jl with the winch model implemented in Matlab (MatlabMachine, see examples/matlab)
# instead of the winch model of the selected project. Needs a Matlab installation.
#
# MATLAB.jl cannot be part of the examples environment, because it cannot be installed without
# Matlab. This script therefore runs in the environment examples/matlab. If another environment is
# active, it starts a new Julia process for it, without system image: the packages in the system
# image cannot be replaced by the versions the MatlabMachine needs. It also starts a new process if
# Downloads is already loaded (e.g. by Pkg or KiteUtils): the Matlab engine must be started before,
# because with Matlab R2025a starting it later crashes Julia (segmentation fault).
const MATLAB_ENV = joinpath(@__DIR__, "matlab")

downloads_loaded = any(id -> id.name == "Downloads", keys(Base.loaded_modules))

if get(ENV, "AUTOPILOT_MATLAB_CHILD", "") == "1" && downloads_loaded
    error("Downloads was loaded before the Matlab engine could be started, see the comment above.")
elseif dirname(Base.active_project()) != MATLAB_ENV || downloads_loaded
    julia_exe = joinpath(Sys.BINDIR, "julia")
    println("Starting a new Julia process for the environment examples/matlab...")
    # without startup file, which could load Downloads
    withenv("AUTOPILOT_MATLAB_CHILD" => "1") do
        run(`$julia_exe --startup-file=no --project=$MATLAB_ENV -t auto --gcthreads=4,1 $(@__FILE__)`)
    end
else
    # a macro like mat"" cannot be used here: the whole if block is expanded before `using MATLAB`
    # runs; invokelatest, because MATLAB is loaded while this block runs
    @eval using MATLAB
    Base.invokelatest(MATLAB.eval_string, "addpath('$(replace(MATLAB_ENV, "'" => "''"))');")
    WINCH_MODEL = "MatlabMachine"
    include("autopilot.jl")
end
nothing
