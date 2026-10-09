# MATLAB interface for a winch model / induction machine

Design notes for coupling a MATLAB (or Simulink) model of the winch, for example an
induction machine with gearbox and drum, to KiteControllers.jl.

## The existing contract

KiteControllers does not model the motor itself. The physics live in
[WinchModels.jl](https://github.com/OpenSourceAWE/WinchModels.jl), which defines
`abstract type AbstractWinchModel` with two implementations:

- `AsyncMachine`: induction machine with gearbox and brake
- `TorqueControlledMachine`: torque-controlled machine with gearbox, without brake

The rest of the stack only uses one function:

```julia
acc = calc_acceleration(wm, speed, force; set_speed=nothing, set_torque=nothing, use_brake=false)
```

The `Winch` component in WinchControllers.jl (`wc_components.jl`) wraps an
`AsyncMachine`, integrates `acc` to get the reel-out `speed`, and computes the dynamic
power `p_dyn`. A MATLAB model that provides the same signature works with the
controllers unchanged.

## Inputs and outputs

Use the same quantities as the Julia `AsyncMachine`, so the two models can be compared
directly:

| Direction | Signal | Unit | Notes |
|---|---|---|---|
| In  | `v_set` (synchronous speed), or `tau_set` | m/s, or Nm | Speed for an induction machine with a VFD; torque for a torque-controlled drive |
| In  | `force` | N | Tether force at the drum, from the kite/tether model |
| In  | `speed` | m/s | Current reel-out speed; only if Julia owns the state (option A) |
| In  | `dt` | s | `1/set.sample_freq` |
| In  | `brake` (optional) | bool | Currently derived from `v_min` inside the model |
| Out | `acc` | m/s² | Required; this is all `calc_acceleration` returns today |
| Out | `speed` | m/s | Only if MATLAB owns the state (option B) |
| Out (diagnostic) | `tau_m`, `omega_m`, slip, `i_s`, `P_mech`, `P_el`, efficiency | various | Useful for logging and validation; not needed by the controllers |

### Who owns the state?

- **Option A, stateless (Julia integrates):** MATLAB is a pure function
  `(v_set, speed, force) -> acc`. This matches `calc_acceleration` exactly, but limits
  the induction machine to a quasi-static model, like the current Julia model.
- **Option B, stateful (MATLAB integrates):** a function
  `step(v_set, force, dt) -> (speed, acc, diagnostics)`. Choose this if the MATLAB model
  has electrical dynamics (dq-axis currents, flux), an inverter/VFD model, or its own
  solver. Julia calls `step` once per sample.

## Ways to connect the two

1. **Julia calls MATLAB via [MATLAB.jl](https://github.com/JuliaInterop/MATLAB.jl).**
   This is the quickest way to build a prototype. Add a `MatlabMachine <: AbstractWinchModel` that
   holds an `MSession` and implements `calc_acceleration` by calling
   `mxcall(session, :winch_step, 1, v_set, speed, force, dt)`. It needs a local MATLAB
   licence, and each call costs roughly 50–200 µs. That is fine at `sample_freq = 20 Hz`,
   but slow for batch runs.

2. **Export the model as an FMU and load it with [FMI.jl](https://github.com/ThummeTo/FMI.jl).**
   This is the recommended route for a Simulink induction-machine model. It runs without
   MATLAB at runtime, can be shared, and is fast. The FMI inputs, outputs and
   `doStep(dt)` map directly onto option B. FMU export needs Simulink Compiler, or
   Simscape for physical models.

3. **Co-simulation over UDP or ZeroMQ.** Use this if a real-time or hardware-in-the-loop
   setup already exists in MATLAB. It is the loosest coupling but needs the most code,
   including synchronisation and timeouts.

## Suggested first step

1. Implement a `MatlabMachine` type using option A via MATLAB.jl.
2. Write a validation script that runs it side by side with `AsyncMachine` on the same
   `v_set` and `force` profile and compares `acc` and `speed`.
3. Once that works, swapping the backend for an FMU (option B) is a local change.

Where the code should live:

- Put the new type in WinchModels.jl, preferably as a package extension so that
  MATLAB.jl stays an optional dependency. It does not belong in KiteControllers.jl.
- `Winch` in WinchControllers.jl currently hard-codes `wm::AsyncMachine`. Change this
  field to `AbstractWinchModel` so other winch models can be used.

## Open questions

Answer these before picking a route:

- Is the model a MATLAB function or script, or a Simulink/Simscape model?
- Does it include electrical dynamics (option B), or only the steady-state torque–slip
  curve (option A)?
- Must it run on machines without MATLAB installed? If so, use an FMU.
