# Add Matlab interface and examples

For control research it would be nice to have a Matlab implementation of the winch model.

## Goal and scope
- Only the winch model (asynchronous machine) is implemented in Matlab.
- Everything else stays in Julia: kite and tether model (KiteModels), winch controller
  (WinchControllers), flight path control and the state machine `SystemStateControl`
  (KiteControllers).
- The Matlab winch model runs inside the Julia simulation. It is driven by `SystemStateControl`
  through the Julia winch controller (`calc_v_set` → `set_speed`) for the full power cycle
  (parking, power production, reel-in, depower).
- The Julia `AsyncMachine` stays the default. Matlab is opt-in: no package may require a Matlab
  installation to load, test or precompile.

## Calling mechanism
Use [MATLAB.jl](https://github.com/JuliaInterop/MATLAB.jl) (Matlab engine) as a weak dependency,
loaded through a package extension. Minimum Matlab version: R2020b. Matlab Coder is not available
and Octave is not supported, so the Matlab engine is the only calling mechanism; the Matlab code
may use any feature of R2020b.

Step 0 (spike, done): measure the cost of one call of the Matlab engine on the target machine.
The design below needs one call per time step (`dt = 0.05 s`); the mean time per step of the
pure-Julia simulation is about 0.8 ms (autopilot.jl, DFBDF).

Results (R2021a Update 8, MATLAB.jl, Linux):

| Call | median | p99 | max |
| --- | --- | --- | --- |
| `mxcall(:plus, 1, 1.0, 2.0)` | 17.0 ms | 18.9 ms | 21.9 ms |
| `mxcall(:spike_step, 5, ...)` (7 inputs incl. struct, 5 outputs) | 57.3 ms | 60.7 ms | 64.9 ms |
| `eval_string("1;")` | 4.0 ms | 4.7 ms | 4.9 ms |
| packed `mxcall` (one input vector, one output vector) | 12.9 ms | 14.5 ms | 14.8 ms |
| `eval_string` with the inputs as text + `get_mvariable` | 4.6 ms | 5.0 ms | 5.5 ms |

Conclusions:
- Each `engEvalString` costs about 4 ms; reading a variable costs about 0.6 ms. `mxcall` is slow
  because it needs several engine calls per Matlab call.
- Interface: one `eval_string` per time step, with all inputs written into the command as text,
  followed by one `get_mvariable` of a packed output vector. The parameters are passed once at
  initialization and kept in a persistent variable in Matlab.
- Numbers are formatted with Julia's `repr`/`string` (shortest representation that round-trips),
  so they arrive in Matlab unchanged; a test checks this, including `NaN` and `Inf`.
- About 5.4 ms per time step in total (Matlab call plus Julia simulation): real-time capable up to
  a time-lapse factor of 6 (8.3 ms budget per step), 9 is marginal (5.6 ms), 12 and more are not.
  The docs state this limit.

## Constraint: no Matlab call in the DAE residual
`calc_acceleration` is evaluated inside the DAE residual, many times per time step (Newton
iterations plus finite-difference Jacobians, about 70 residual calls per Jacobian for KPS4).
A Matlab call there would make the simulation orders of magnitude slower.

## Design: one Matlab call per time step
- KiteModels already calls `update_winch_state!(wm, set_speed; use_brake)` once per time step in
  `next_step!`. Extend it with the keywords `speed` and `force` (values at the start of the step).
- `MatlabMachine <: AbstractWinchModel` calls Matlab there once (see "Calling mechanism"):

  ```matlab
  % x = [speed, force, set_speed, use_brake, brake, last_set_speed]
  % y = [acc0, dacc_dv, dacc_dF, brake, last_set_speed]
  y = async_machine_step(x);
  ```

  At initialization `async_machine_step(p)` is called once with the parameter struct `p`, which
  the function stores in a persistent variable.

  This updates the brake and the rate-limited set speed, and returns the acceleration and its
  partial derivatives at the start of the step.
- In the residual, `calc_acceleration(::MatlabMachine, ...)` uses the first-order expansion
  `acc0 + dacc_dv*(speed - speed0) + dacc_dF*(force - force0)`, evaluated in Julia.
  While the brake is active it returns `brake_acc * speed`, as `AsyncMachine` does.
- Apart from the constant parameters, the Matlab function is stateless; brake and
  `last_set_speed` are stored in the Julia struct.
- Parameters `p`: `gear_ratio`, `drum_radius`, `inertia_total`, `max_force`, `f_coulomb`, `c_vf`,
  `max_acc`, `sample_freq` from `Settings`, plus `u_nom`, `omega_sn`, `omega_mn`, `tau_n`,
  `tau_b`, `v_min`, `brake_acc` from `AsyncMachine`. Port quirks exactly (e.g. the factor
  `4000.0 / max_force`).

## Where the code goes
- Matlab sources: `examples/matlab/` in KiteControllers.jl. The Julia side does not hard-code this
  location; the folder is added to the Matlab path from a setting (e.g. `matlab_path`, relative to
  the data path) or by the example script.
- Julia type `MatlabMachine`: package extension `ext/WinchModelsMATLABExt.jl` in WinchModels.jl
  (KiteModels creates the winch model, so it cannot live in KiteControllers).
- KiteModels:
  - `KPS4` and `KPS3` constructors: add the branch `winch_model == "MatlabMachine"`, and an `else`
    branch that throws an error. Today an unknown `winch_model` silently gives `wm = nothing`,
    which means no winch dynamics at all.
  - `next_step!`: pass `speed` and `force` to `update_winch_state!`.
- KiteUtils: document `"MatlabMachine"` as a valid value of `winch_model`.

## Testing
- Matlab unit tests (`examples/matlab/tests/`, `matlab.unittest`) against reference data exported
  from the Julia `AsyncMachine` (CSV).
- Julia tests of the extension, skipped when MATLAB.jl cannot start an engine:
  - Matlab `acc0` equal to Julia `calc_acceleration` to 1e-12 over a grid of speed, force and set
    speed, with and without brake;
  - Matlab partial derivatives equal to finite differences of the Julia model;
  - full power cycle with `MatlabMachine` compared against `AsyncMachine`.
- CI on GitHub has no Matlab: these tests run locally only, or via the MathWorks GitHub actions if a
  license is available.

## Examples and documentation
- `examples/autopilot_matlab.jl`: autopilot.jl with `winch_model: "MatlabMachine"`.
- Docs page: requirements (Matlab R2020b or newer, MATLAB.jl setup), settings, limitations
  (linearization within one time step, speed, no Octave support).

## Acceptance criteria
- `autopilot_matlab.jl` completes a full power cycle with the Matlab winch model.
- Energy `e_mech` differs by less than 1 % from the run with the Julia `AsyncMachine`.
- Measured time per step is reported; real-time capability is stated in the docs.

## Open questions
- Later: `TorqueControlledMachine` in Matlab, using the same per-step interface.
