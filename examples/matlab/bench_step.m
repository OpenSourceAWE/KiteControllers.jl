function [acc0, dacc_dv, dacc_dF, brake, last_set_speed] = bench_step(speed, force, set_speed, use_brake, brake, last_set_speed, p)
% Dummy with seven inputs and five outputs, for timing the Matlab engine call only (bench_engine.jl).
    if use_brake && abs(set_speed) < 0.1
        brake = true;
    end
    last_set_speed = set_speed;
    omega   = p.gear_ratio / p.drum_radius * speed;
    acc0    = p.drum_radius / p.gear_ratio * (force * 4000.0 / p.max_force - 0.01 * omega) / p.inertia_total;
    dacc_dv = -0.01 / p.inertia_total;
    dacc_dF = p.drum_radius / p.gear_ratio * 4000.0 / p.max_force / p.inertia_total;
end
