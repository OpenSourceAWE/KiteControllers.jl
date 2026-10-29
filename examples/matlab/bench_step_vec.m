function y = bench_step_vec(x)
% Packed variant of bench_step, with the interface of async_machine_step:
% x = [speed, force, set_speed, use_brake, brake, last_set_speed],
% y = [acc0, dacc_dv, dacc_dF, brake, last_set_speed]. bench_step_vec(p) stores the parameter
% struct p in a persistent variable. For timing the Matlab engine call only (bench_engine.jl).
    persistent p
    if isstruct(x)
        p = x;
        y = [];
        return
    end
    [acc0, dacc_dv, dacc_dF, brake, last_set_speed] = bench_step(x(1), x(2), x(3), x(4) ~= 0, x(5) ~= 0, x(6), p);
    y = [acc0, dacc_dv, dacc_dF, double(brake), last_set_speed];
end
