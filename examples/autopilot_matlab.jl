# Run autopilot.jl with the winch model implemented in Matlab (MatlabMachine, see examples/matlab)
# instead of the winch model of the selected project. Needs a Matlab installation.
#
# MATLAB.jl cannot be part of the examples environment, because it cannot be installed without
# Matlab. This script therefore runs in the environment examples/matlab. If another environment is
# active, it starts a new Julia process for it, without system image: the packages in the system
# image cannot be replaced by the versions the MatlabMachine needs.
const MATLAB_ENV = joinpath(@__DIR__, "matlab")

if dirname(Base.active_project()) != MATLAB_ENV
    julia_exe = joinpath(Sys.BINDIR, "julia")
    println("Starting a new Julia process for the environment examples/matlab...")
    run(`$julia_exe --project=$MATLAB_ENV -t auto --gcthreads=4,1 $(@__FILE__)`)
else
    # a macro like mat"" cannot be used here: the whole if block is expanded before `using MATLAB`
    # runs; invokelatest, because MATLAB is loaded while this block runs
    @eval using MATLAB
    Base.invokelatest(MATLAB.eval_string, "addpath('$(replace(MATLAB_ENV, "'" => "''"))');")
    WINCH_MODEL = "MatlabMachine"
    include("autopilot.jl")
end
nothing
