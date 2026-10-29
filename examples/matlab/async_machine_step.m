function y = async_machine_step(x)
%ASYNC_MACHINE_STEP One time step of the model of a winch with an asynchronous machine.
%
%   Matlab implementation of the AsyncMachine of WinchModels.jl, called from Julia (MatlabMachine)
%   once per time step.
%
%   async_machine_step(p) stores the parameter struct p. Required fields:
%     gear_ratio, drum_radius [m], inertia_total [kgm²], max_force [N], f_coulomb [N],
%     c_vf [Ns/m], max_acc [m/s²], sample_freq [Hz], u_nom [V], omega_sn [rad/s],
%     omega_mn [rad/s], tau_n [Nm], tau_b [Nm], v_min [m/s], brake_acc [1/s²]
%
%   y = async_machine_step(x) with
%     x = [speed, force, set_speed, use_brake, brake, last_set_speed]
%     y = [acc0, dacc_dv, dacc_dF, brake, last_set_speed]
%   speed: reel-out speed at the start of the time step [m/s]
%   force: tether force at the start of the time step [N]
%   set_speed: set value of the reel-out speed [m/s], NaN if there is none
%   use_brake, brake: 0 or 1
%   last_set_speed: rate limited set speed of the last time step [m/s]
%   acc0: acceleration [m/s²] at speed and force; dacc_dv [1/s] and dacc_dF [m/(s²N)] are its
%   partial derivatives. brake and last_set_speed are the new state of the winch.
%
%   Like update_winch_state! of WinchModels.jl, the brake and the rate limited set speed are
%   updated once, before the acceleration is calculated.

    persistent p
    if isstruct(x)
        fields = {'gear_ratio', 'drum_radius', 'inertia_total', 'max_force', 'f_coulomb', ...
                  'c_vf', 'max_acc', 'sample_freq', 'u_nom', 'omega_sn', 'omega_mn', 'tau_n', ...
                  'tau_b', 'v_min', 'brake_acc'};
        missing_fields = fields(~isfield(x, fields));
        if ~isempty(missing_fields)
            error('WinchModels:params', 'missing parameters: %s', strjoin(missing_fields, ', '));
        end
        p = x;
        y = [];
        return
    end
    if isempty(p)
        error('WinchModels:params', 'call async_machine_step(p) with the parameters first');
    end

    speed          = x(1);
    force          = x(2);
    set_speed      = x(3);
    use_brake      = x(4) ~= 0;
    brake          = x(5) ~= 0;
    last_set_speed = x(6);

    % update_winch_state!: brake with hysteresis, then rate limit of the set speed
    if ~isnan(set_speed)
        if use_brake
            if abs(set_speed) < 0.9 * p.v_min
                brake = true;
            elseif abs(set_speed) > 1.1 * p.v_min
                brake = false;
            end
        end
        if ~(use_brake && brake)
            max_step = p.max_acc / p.sample_freq;
            last_set_speed = min(max(set_speed, last_set_speed - max_step), last_set_speed + max_step);
        end
    end

    if use_brake && brake
        % if the brake is active the acceleration is proportional to the speed
        acc0    = p.brake_acc * speed;
        dacc_dv = p.brake_acc;
        dacc_dF = 0.0;
    else
        r = p.drum_radius;
        n = p.gear_ratio;
        % motor resistance R2 [Ohm] and inductance L [H] from the nameplate data
        R2 = (p.u_nom^2 * (p.omega_sn - p.omega_mn)) / (2 * p.omega_sn^2) * ...
             (1 / p.tau_n + sqrt(1 / p.tau_n^2 - 1 / p.tau_b^2));
        L  = p.u_nom^2 / (2 * p.omega_sn * p.tau_b) / p.omega_sn;
        omega      = n / r * speed;
        omega_sync = n / r * last_set_speed;
        delta      = omega_sync - omega;
        if abs(omega_sync) <= p.omega_sn
            c = p.omega_sn^2;
        else
            c = omega_sync^2;
        end
        den       = R2^2 + L^2 * delta^2;
        tau_motor = (p.u_nom^2 * R2 * delta) / (c * den);
        dtau_motor_ddelta = p.u_nom^2 * R2 * (R2^2 - L^2 * delta^2) / (c * den^2);
        % friction: Coulomb (smooth sign) and viscous
        EPSILON = 6;
        tau_c = p.f_coulomb * r / n;
        c_v   = p.c_vf * r^2 / n^2;
        smooth_sign   = omega / sqrt(omega^2 + EPSILON^2);
        d_smooth_sign = EPSILON^2 / (omega^2 + EPSILON^2)^1.5;
        tau_friction  = tau_c * smooth_sign + c_v * omega;
        dtau_friction_domega = tau_c * d_smooth_sign + c_v;

        k_force = r / n * 4000.0 / p.max_force;
        omega_dot_m = (tau_motor + k_force * force - tau_friction) / p.inertia_total;
        acc0    = r / n * omega_dot_m;
        % d(delta)/d(speed) = d(omega)/d(speed) * -1 = -n/r
        dacc_dv = r / n / p.inertia_total * (-dtau_motor_ddelta - dtau_friction_domega) * n / r;
        dacc_dF = r / n / p.inertia_total * k_force;
    end
    y = [acc0, dacc_dv, dacc_dF, double(brake), last_set_speed];
end
