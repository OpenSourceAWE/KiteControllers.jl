# Winch model in Matlab

`async_machine_step.m` is a Matlab implementation of the model of the winch with an asynchronous
machine (`AsyncMachine` of WinchModels.jl). With `winch_model: "MatlabMachine"` in the settings,
KiteModels uses it instead of the Julia model, called through the Matlab engine once per time
step. See [PlanMatlab.md](../../PlanMatlab.md) for the design.

## Requirements

- Matlab R2020b or newer, and a license that allows starting the Matlab engine
- Linux: `csh` (the Matlab engine is started with it)

## Setup

```julia
using Pkg
Pkg.activate("examples/matlab")
ENV["MATLAB_ROOT"] = "/usr/local/MATLAB/R2021a"   # only if the wrong Matlab is found
Pkg.instantiate()
Pkg.build("MATLAB")
```

Until the new versions of WinchModels.jl and KiteModels.jl are released, use the development
versions, e.g. `Pkg.develop(path="../WinchModels.jl")`.

## Test

```julia
include("examples/matlab/test_async_machine_step.jl")
```

compares the Matlab implementation with the Julia `AsyncMachine`: acceleration, partial
derivatives, brake and rate limit of the set speed, and measures the time per call.

## Full power cycles

```julia
include("examples/matlab/compare_full_cycle.jl")
```

flies the power cycles of `examples/autopilot.jl` twice, without viewer and turbulence, with the
Julia `AsyncMachine` and with the `MatlabMachine`, and compares the energy, the tether force, the
reel-out speed and the time per step. It needs KiteModels and WinchModels with support for the
`MatlabMachine`; until they are released, develop them in this environment.

By default, it uses the project `system.yaml`. To compare other projects, define `PROJECTS`
before including the script, e.g. `PROJECTS = ["hydra20_426.yml", "hydra20_600.yml"]`, or pass
them as arguments:

```bash
julia --project=examples/matlab examples/matlab/compare_full_cycle.jl hydra20_426.yml hydra20_600.yml
```

## Benchmark of the Matlab engine

```julia
include("examples/matlab/bench_engine.jl")
```

measures the time of one call of Matlab from Julia for different ways of calling it (step 0 of
PlanMatlab.md), using the dummy functions `bench_step.m` and `bench_step_vec.m`. Each
`engEvalString` costs milliseconds, and `mxcall` and the exception check of `eval_string` need
several of them; the `MatlabMachine` therefore uses one unchecked `eval_string` with the inputs as
text and reads back one vector.
