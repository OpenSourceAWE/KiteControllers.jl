% WINCH_EXAMPLE Simulate the winch model async_machine_step.m in Matlab, without Julia.
%
%   The winch, an asynchronous machine with gearbox, drum, friction and brake, follows a profile of
%   the set speed while the tether force is prescribed: start with the brake engaged, reel out,
%   reel in and stop. The model is called once per time step, as in the Julia simulation; within
%   the time step, the speed is integrated with the linearized implicit Euler method, using the
%   partial derivative dacc_dv that async_machine_step returns.
%
%   Run it in the folder examples/matlab, or with this folder on the Matlab path:
%       winch_example

clear async_machine_step   % forget the parameters of an earlier run

%% Parameters, as loaded by Julia for data/system.yaml (settings.yaml) and the AsyncMachine
p.gear_ratio    = 6.2;             % gear ratio of the winch                      [-]
p.drum_radius   = 0.1615;          % radius of the drum                           [m]
p.inertia_total = 0.204;           % total inertia, as seen from the motor        [kgm²]
p.max_force     = 4000;            % maximal (nominal) tether force               [N]
p.f_coulomb     = 122.0;           % coulomb friction                             [N]
p.c_vf          = 30.6;            % coefficient for the viscous friction         [Ns/m]
p.max_acc       = 4.0;             % maximal acceleration of the set speed        [m/s²]
p.sample_freq   = 20;              % sample frequency                             [Hz]
p.u_nom         = 400 / sqrt(3);   % nominal motor voltage                        [V]
p.omega_sn      = 1500 / 60 * 2*pi;% rated synchronous motor speed                [rad/s]
p.omega_mn      = 1460 / 60 * 2*pi;% rated nominal motor speed                    [rad/s]
p.tau_n         = 121;             % rated torque at nominal motor speed          [Nm]
p.tau_b         = 363;             % rated maximum torque                         [Nm]
p.v_min         = 0.2;             % below this set speed the brake is engaged    [m/s]
p.brake_acc     = -25.0;           % linear acceleration of the brake             [1/s²]
async_machine_step(p);

%% Profile of the set speed and of the tether force
dt = 1 / p.sample_freq;
t  = (0:dt:20)';
n  = numel(t);
set_speed = zeros(n, 1);
force     = 1000 * ones(n, 1);
reel_out  = t >= 2  & t < 8;     % reel out against a high tether force
reel_in   = t >= 8  & t < 14;    % reel in against a low tether force
set_speed(reel_out) = 4.0;   force(reel_out) = 3000;
set_speed(reel_in)  = -6.0;  force(reel_in)  = 800;

%% Simulation
speed  = zeros(n, 1);   % reel-out speed [m/s]
len    = zeros(n, 1);   % reeled out tether length, relative to the start [m]
acc    = zeros(n, 1);   % acceleration during the time step [m/s²]
brake  = zeros(n, 1);   % 1 if the brake is engaged
v_sync = zeros(n, 1);   % rate limited set speed (synchronous speed) [m/s]
use_brake      = 1;
brake_state    = 1;
last_set_speed = 0;
for i = 1:n-1
    x = [speed(i), force(i), set_speed(i), use_brake, brake_state, last_set_speed];
    y = async_machine_step(x);
    acc0 = y(1); dacc_dv = y(2);
    brake_state = y(4); last_set_speed = y(5);
    % linearized implicit Euler: acc(v) = acc0 + dacc_dv * (v - speed(i)), evaluated at the end of
    % the time step; stable even for the stiff torque-slip curve of the machine
    speed(i+1) = speed(i) + dt * acc0 / (1 - dt * dacc_dv);
    len(i+1)   = len(i) + dt * speed(i+1);
    acc(i)     = (speed(i+1) - speed(i)) / dt;
    brake(i)   = brake_state;
    v_sync(i)  = last_set_speed;
end
acc(n) = acc(n-1); brake(n) = brake(n-1); v_sync(n) = v_sync(n-1);

%% Plot of the time series
% While the brake is engaged, the rate limited set speed keeps its last value.
figure('Name', 'Winch simulation');
subplot(4, 1, 1);
plot(t, set_speed, '--', t, v_sync, ':', t, speed, 'LineWidth', 1.2); grid on;
ylabel('speed [m/s]'); ylim([-7, 5]);
legend('set speed', 'rate limited set speed', 'reel-out speed', 'Location', 'best');
subplot(4, 1, 2);
plot(t, acc, 'LineWidth', 1.2); grid on; ylabel('acc [m/s²]');
subplot(4, 1, 3);
plot(t, force, 'LineWidth', 1.2); grid on; ylabel('force [N]'); ylim([0, 3500]);
subplot(4, 1, 4);
stairs(t, brake, 'LineWidth', 1.2); grid on; ylim([-0.1, 1.1]);
ylabel('brake'); xlabel('time [s]');

%% Acceleration as a function of the reel-out speed, for a synchronous speed of 4 m/s
% set_speed = NaN keeps the state: the brake and the synchronous speed last_set_speed
v = linspace(0, 8, 401)';
figure('Name', 'Acceleration over reel-out speed');
hold on; grid on;
for f = [0, 1000, 3000]
    a = zeros(size(v));
    for k = 1:numel(v)
        y = async_machine_step([v(k), f, NaN, 0, 0, 4.0]);
        a(k) = y(1);
    end
    plot(v, a, 'LineWidth', 1.2, 'DisplayName', sprintf('force = %d N', f));
end
xline(4.0, ':', 'synchronous speed', 'HandleVisibility', 'off');
xlabel('reel-out speed [m/s]'); ylabel('acceleration [m/s²]');
legend('Location', 'best');
title('Asynchronous machine, synchronous speed 4 m/s');

fprintf('final tether length change: %.2f m, max |speed - set speed| while reeling out: %.3f m/s\n', ...
        len(end), max(abs(speed(reel_out & t > 4) - set_speed(reel_out & t > 4))));
