%% =============== Proposal Step Size Ablation Experiment ===============
clear; clc; close all;

%% =============== 1. Data Loading and Preprocessing ===============
fprintf('=== 1. Fracture data loading and preprocessing ===\n');

% Load actual data
load('C:\Users\Administrator\Desktop\2..mat');
h_surface = h_surface.*10;
% Check variable names and extract data
if exist('h_surface', 'var') && exist('L_surface', 'var')
    h_observed = h_surface(:)*1;  % Ensure column vector
    L_true = L_surface(:);      % Ensure column vector
    
    % Check data length consistency
    if length(h_observed) ~= length(L_true)
        fprintf('Warning: Aperture data (%d) and trace length data (%d) length mismatch!\n', ...
                length(h_observed), length(L_true));
        % Use minimum length
        min_len = min(length(h_observed), length(L_true));
        h_observed = h_observed(1:min_len);
        L_true = L_true(1:min_len);
    end
    
    n_fractures = length(h_observed);
    fprintf('Successfully loaded actual data: %d fractures\n', n_fractures);
    
elseif exist('all_apertures', 'var') && exist('all_traceLengths', 'var')
    % Use variable names from previous code
    h_observed = all_apertures(:);
    L_true = all_traceLengths(:);
    
    % Check data length consistency
    if length(h_observed) ~= length(L_true)
        fprintf('Warning: Data length mismatch, performing matching...\n');
        min_len = min(length(h_observed), length(L_true));
        h_observed = h_observed(1:min_len);
        L_true = L_true(1:min_len);
    end
    
    n_fractures = length(h_observed);
    fprintf('Successfully loaded actual data: %d fractures\n', n_fractures);
    
else
    fprintf('Error: Could not find aperture (h_surface) and trace length (L_surface) data!\n');
    fprintf('Variables in file:\n');
    whos
    
    % Try to find similar variables
    vars = who;
    h_var = vars(contains(vars, {'h', 'aperture'}, 'IgnoreCase', true));
    L_var = vars(contains(vars, {'L', 'trace', 'length'}, 'IgnoreCase', true));

    fprintf('Found possible aperture variable: %s\n', h_var{1});
    fprintf('Found possible trace length variable: %s\n', L_var{1});
        
    eval(sprintf('h_observed = %s(:);', h_var{1}));
    eval(sprintf('L_true = %s(:);', L_var{1}));
        
    % Check data length
    if length(h_observed) ~= length(L_true)
        min_len = min(length(h_observed), length(L_true));
        h_observed = h_observed(1:min_len);
        L_true = L_true(1:min_len);
    end
        
    n_fractures = length(h_observed);
    fprintf('Using variables %s and %s, total %d data points\n', h_var{1}, L_var{1}, n_fractures);
end

% Data quality check
fprintf('\nData quality check:\n');
fprintf('Aperture range: %.4f - %.4f mm\n', min(h_observed), max(h_observed));
fprintf('Trace length range: %.4f - %.4f m\n', min(L_true), max(L_true));
fprintf('Aperture median: %.4f mm, trace length median: %.4f m\n', median(h_observed), median(L_true));

fprintf('Final valid data: %d fractures\n', n_fractures);

%% =============== 2. Physical Model Definition (Mixed Fracture Model) ===============
fprintf('\n=== 2. Physical model definition ===\n');
fprintf('Mixed fracture mechanics model:\n');
fprintf('  h = η × α_I × L^{β_I} + (1-η) × α_II × L^{β_II}\n');

% Define model functions
forward_model = @(params, L) ...
    max(1e-10, params.eta * params.alpha_I * (L .^ params.beta_I) + ...
    (1-params.eta) * params.alpha_II * (L .^ params.beta_II));

% Inverse model for trace length prediction (as in your formula)
inverse_model = @(params, h_obs) fminbnd(@(L) abs(h_obs - forward_model(params, L)), ...
    min(L_true), max(L_true));

%% =============== 3. Step Size Ablation Experiment Design ===============
fprintf('\n=== 3. Step size ablation experiment ===\n');

% Define different step size configurations
% Each row: [eta_step, alpha_I_step, beta_I_step, alpha_II_step, beta_II_step, sigma_step]
% step_configs = {
%     % Conservative small steps (0.1x)
%     [0.005, 0.001, 0.002, 0.001, 0.002, 0.003];
%     
%     % Moderate small steps (0.25x)
%     [0.0125, 0.0025, 0.005, 0.0025, 0.005, 0.0075];
%     
%     % Default steps (0.5x)
%     [0.025, 0.005, 0.01, 0.005, 0.01, 0.015];
%     
%     % Optimal theoretical steps (0.75x)
%     [0.0375, 0.0075, 0.015, 0.0075, 0.015, 0.0225];
%     
%     % Baseline steps (1.0x)
%     [0.05, 0.01, 0.02, 0.01, 0.02, 0.03];
%     
%     % Aggressive steps (1.5x)
%     [0.075, 0.015, 0.03, 0.015, 0.03, 0.045];
%     
%     % Very aggressive steps (2.0x)
%     [0.1, 0.02, 0.04, 0.02, 0.04, 0.06];
%     
%     % Extremely aggressive steps (3.0x)
%     [0.15, 0.03, 0.06, 0.03, 0.06, 0.09];
% };
%% =============== 3. Step Size Ablation Experiment Design ===============
fprintf('\n=== 3. Step size ablation experiment ===\n');

% 定义不同步长配置 (12个：0.5到6.0，间隔0.5)
scale_factors = 0.5:0.5:8;  % [0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 4.5, 5.0, 5.5, 6.0]
n_experiments = length(scale_factors);

% 基准步长
base_steps = [0.05, 0.01, 0.02, 0.01, 0.02, 0.03];

% 生成12个配置
step_configs = cell(n_experiments, 1);
for i = 1:n_experiments
    step_configs{i} = base_steps * scale_factors(i);
end

fprintf('Testing %d different step size configurations:\n', n_experiments);
for i = 1:n_experiments
    fprintf('Config %d (scale: %.1fx): [%.4f, %.4f, %.4f, %.4f, %.4f, %.4f]\n', ...
        i, scale_factors(i), step_configs{i});
end
fprintf('\n');

% Data splitting (fixed for all experiments)
train_ratio = 0.8;
n_train = round(train_ratio * n_fractures);
indices = randperm(n_fractures);
train_idx = indices(1:n_train);
val_idx = indices(n_train+1:end);

h_train = h_observed(train_idx);
L_train = L_true(train_idx);
h_val = h_observed(val_idx);
L_val = L_true(val_idx);

% Initialize result storage
experiment_results = cell(n_experiments, 1);

% Define model functions
log_likelihood = @(params, h_data, L_data) ...
    -0.5 * length(h_data) * log(2*pi*params.sigma^2) ...
    - 0.5 * sum((log(h_data) - log(forward_model(params, L_data))).^2) / params.sigma^2;

log_prior = @(params) ...
    log(betapdf(params.eta, 8, 2)) + ...
    log(lognpdf(params.alpha_I, log(0.02), 0.3)) + ...
    log(lognpdf(params.alpha_II, log(0.02), 0.3)) + ...
    log(normpdf(params.beta_I, 0.7, 0.1)) + ...
    log(normpdf(params.beta_II, 0.5, 0.1)) + ...
    log(exppdf(params.sigma, 0.1));

log_posterior = @(params, h_data, L_data) ...
    log_likelihood(params, h_data, L_data) + log_prior(params);

%% =============== 4. Main Ablation Experiment Loop ===============
for exp_idx = 1:n_experiments
    fprintf('\n=== Experiment %d/%d: Scale factor = %.1f ===\n', ...
        exp_idx, n_experiments, scale_factors(exp_idx));
    
    proposal_sd = step_configs{exp_idx};
    
    % MCMC settings
    n_iter = 30000;
    n_chains = 4;
    n_burn = 30;
    n_thin = max(1, round(n_iter / 1000));
    
    % Initialize chains
    initial_params = cell(n_chains, 1);
    for chain = 1:n_chains
        switch chain
            case 1  % Mode I dominant
                initial_params{chain} = struct(...
                    'eta', 0.9, ...
                    'alpha_I', median(h_train)/median(L_train)^0.7, ...
                    'beta_I', 0.7, ...
                    'alpha_II', median(h_train)/median(L_train)^0.5, ...
                    'beta_II', 0.5, ...
                    'sigma', 0.1);
            case 2  % Mixed
                initial_params{chain} = struct(...
                    'eta', 0.6, ...
                    'alpha_I', median(h_train)/median(L_train)^0.7 * 0.8, ...
                    'beta_I', 0.6, ...
                    'alpha_II', median(h_train)/median(L_train)^0.5 * 1.2, ...
                    'beta_II', 0.45, ...
                    'sigma', 0.15);
            case 3  % Mode II dominant
                initial_params{chain} = struct(...
                    'eta', 0.3, ...
                    'alpha_I', median(h_train)/median(L_train)^0.7 * 0.6, ...
                    'beta_I', 0.5, ...
                    'alpha_II', median(h_train)/median(L_train)^0.5 * 1.5, ...
                    'beta_II', 0.55, ...
                    'sigma', 0.2);
            case 4  % Random exploration
                initial_params{chain} = struct(...
                    'eta', 0.5 + 0.4*randn, ...
                    'alpha_I', median(h_train)/median(L_train)^0.7 * (0.8 + 0.4*rand), ...
                    'beta_I', 0.6 + 0.3*rand, ...
                    'alpha_II', median(h_train)/median(L_train)^0.5 * (0.8 + 0.4*rand), ...
                    'beta_II', 0.4 + 0.3*rand, ...
                    'sigma', 0.1 + 0.1*rand);
        end
        
        % Apply bounds
        fields = fieldnames(initial_params{chain});
        for f = 1:length(fields)
            param = initial_params{chain}.(fields{f});
            if strcmp(fields{f}, 'eta')
                param = max(0.1, min(0.99, param));
            elseif strcmp(fields{f}, 'alpha_I') || strcmp(fields{f}, 'alpha_II')
                param = max(0.001, min(0.1, param));
            elseif strcmp(fields{f}, 'beta_I')
                param = max(0.5, min(1.0, param));
            elseif strcmp(fields{f}, 'beta_II')
                param = max(0.3, min(0.7, param));
            elseif strcmp(fields{f}, 'sigma')
                param = max(0.01, min(0.5, param));
            end
            initial_params{chain}.(fields{f}) = param;
        end
    end
    
    % Run chains
    all_chains_samples = cell(n_chains, 1);
    all_chains_accept = zeros(n_chains, 1);
    all_chains_logpost = cell(n_chains, 1);
    
    fprintf('Running %d MCMC chains...\n', n_chains);
    
    for chain = 1:n_chains
        fprintf('--- Chain %d/%d ---\n', chain, n_chains);
        
        current_params = initial_params{chain};
        current_logpost = log_posterior(current_params, h_train, L_train);
        
        samples = zeros(n_iter, 6);
        logpost_trace = zeros(n_iter, 1);
        accept_count = 0;
        
        for iter = 1:n_iter
            % Propose new parameters
            proposed_params = current_params;
            param_idx = randi(6);
            
            switch param_idx
                case 1  % η
                    proposed_raw = current_params.eta + proposal_sd(1) * randn;
                    proposed_params.eta = reflect_boundary(proposed_raw, 0.1, 0.99);
                case 2  % α_I
                    proposed_raw = current_params.alpha_I * exp(proposal_sd(2) * randn);
                    proposed_params.alpha_I = reflect_boundary(proposed_raw, 0.001, 0.1);
                case 3  % β_I
                    proposed_raw = current_params.beta_I + proposal_sd(3) * randn;
                    proposed_params.beta_I = reflect_boundary(proposed_raw, 0.5, 1.0);  
                case 4  % α_II
                    proposed_raw = current_params.alpha_II * exp(proposal_sd(4) * randn);
                    proposed_params.alpha_II = reflect_boundary(proposed_raw, 0.001, 0.1);
                case 5  % β_II
                    proposed_raw = current_params.beta_II + proposal_sd(5) * randn;
                    proposed_params.beta_II = reflect_boundary(proposed_raw, 0.3, 0.7);
                case 6  % σ
                    proposed_raw = current_params.sigma * exp(proposal_sd(6) * randn);
                    proposed_params.sigma = reflect_boundary(proposed_raw, 0.01, 0.5);
            end
            
            % Calculate acceptance probability
            try
                proposed_logpost = log_posterior(proposed_params, h_train, L_train);
                
                if isfinite(proposed_logpost)
                    log_alpha = proposed_logpost - current_logpost;
                    
                    if log(rand) < log_alpha
                        current_params = proposed_params;
                        current_logpost = proposed_logpost;
                        accept_count = accept_count + 1;
                    end
                end
            catch
                % Reject if error
            end
            
            % Store
            samples(iter, :) = [current_params.eta, current_params.alpha_I, ...
                               current_params.beta_I, current_params.alpha_II, ...
                               current_params.beta_II, current_params.sigma];
            logpost_trace(iter) = current_logpost;
            
            % Progress display
            if mod(iter, max(1, floor(n_iter/20))) == 0
                fprintf('  Iter %d/%d, accept: %.2f%%, η: %.3f\n', ...
                    iter, n_iter, accept_count/iter*100, current_params.eta);
            end
        end
        
        all_chains_samples{chain} = samples;
        all_chains_accept(chain) = accept_count / n_iter;
        all_chains_logpost{chain} = logpost_trace;
        
        fprintf('Chain %d complete: final accept rate = %.2f%%\n', ...
            chain, all_chains_accept(chain)*100);
    end
    
    % Combine samples from all chains
    all_samples = [];
    for chain = 1:n_chains
        burned_samples = all_chains_samples{chain}(n_burn+1:n_thin:end, :);
        all_samples = [all_samples; burned_samples];
    end
    
    % Calculate convergence metrics
    % 1. Gelman-Rubin R-hat
    r_hat_values = zeros(1, 6);
    for p = 1:6
        chain_means = zeros(n_chains, 1);
        chain_vars = zeros(n_chains, 1);
        chain_sizes = zeros(n_chains, 1);
        
        for chain = 1:n_chains
            chain_samples = all_chains_samples{chain}(n_burn+1:end, p);
            chain_means(chain) = mean(chain_samples);
            chain_vars(chain) = var(chain_samples);
            chain_sizes(chain) = length(chain_samples);
        end
        
        n = min(chain_sizes);
        m = n_chains;
        overall_mean = mean(chain_means);
        B = n/(m-1) * sum((chain_means - overall_mean).^2);
        W = mean(chain_vars);
        
        if W > 0
            var_plus = (n-1)/n * W + B/n;
            r_hat_values(p) = sqrt(var_plus / W);
        else
            r_hat_values(p) = Inf;
        end
    end
    
    % 2. ESS (Effective Sample Size)
    ess_values = zeros(1, 6);
    for p = 1:6
        combined_samples = [];
        for chain = 1:n_chains
            combined_samples = [combined_samples; all_chains_samples{chain}(n_burn+1:end, p)];
        end
        ess_values(p) = effective_sample_size(combined_samples);
    end
    
    % 3. Convergence time (iterations to reach R-hat < 1.1)
    conv_time = zeros(1, 6);
    for p = 1:6
        for check_iter = 1000:500:n_iter
            temp_r_hat = zeros(1, n_chains);
            for chain = 1:n_chains
                temp_chain_samples = all_chains_samples{chain}(1:check_iter, p);
                temp_r_hat(chain) = var(temp_chain_samples);
            end
            temp_r_hat_mean = mean(temp_r_hat);
            temp_r_hat_var = var(temp_r_hat);
            
            if temp_r_hat_var/temp_r_hat_mean < 0.1 && check_iter > 2000
                conv_time(p) = check_iter;
                break;
            end
        end
        if conv_time(p) == 0
            conv_time(p) = n_iter;
        end
    end
    
    % Calculate posterior statistics
    param_names = {'eta', 'alpha_I', 'beta_I', 'alpha_II', 'beta_II', 'sigma'};
    post_mean = mean(all_samples, 1);
    post_std = std(all_samples, 0, 1);
    
    params_mean = struct(...
        'eta', post_mean(1), ...
        'alpha_I', post_mean(2), ...
        'beta_I', post_mean(3), ...
        'alpha_II', post_mean(4), ...
        'beta_II', post_mean(5), ...
        'sigma', post_mean(6));
    
    %% =============== 5. Performance Evaluation ===============
    % A. Prediction performance on validation set
    n_val = length(h_val);
    h_pred_val = forward_model(params_mean, L_val);
    
    % Calculate performance metrics (from your image)
    R2_val = 1 - sum((h_val - h_pred_val).^2) / sum((h_val - mean(h_val)).^2);
    MAE_val = mean(abs(h_val - h_pred_val));
    RMSE_val = sqrt(mean((h_val - h_pred_val).^2));
    MAPE_val = 100 * mean(abs((h_val - h_pred_val) ./ h_val));
    
    % B. Inverse prediction (trace length from aperture)
    n_test = min(20, n_val);
    test_indices = randperm(n_val, n_test);
    L_pred_inverse = zeros(n_test, 1);
    
    for i = 1:n_test
        h_test = h_val(test_indices(i));
        % Use numerical optimization to find L
        L_pred_inverse(i) = fminbnd(@(L) abs(h_test - forward_model(params_mean, L)), ...
            min(L_true), max(L_true));
    end
    
    % C. Convergence quality metrics
    % 1. Mixing efficiency (autocorrelation time)
    acf_lag1 = zeros(1, 6);
    for p = 1:6
        sample_chain = all_samples(:, p);
        if length(sample_chain) > 100
            acf = autocorr(sample_chain, 1);
            acf_lag1(p) = abs(acf(2));
        else
            acf_lag1(p) = NaN;
        end
    end
    
    % 2. Exploration efficiency (parameter space coverage)
    param_ranges = zeros(1, 6);
    for p = 1:6
        param_ranges(p) = range(all_samples(:, p)) / post_std(p);
    end
    
    % 3. Chain consistency (between-chain variance)
    chain_var_ratio = zeros(1, 6);
    for p = 1:6
        chain_vars = zeros(n_chains, 1);
        for chain = 1:n_chains
            chain_samples = all_chains_samples{chain}(n_burn+1:end, p);
            chain_vars(chain) = var(chain_samples);
        end
        chain_var_ratio(p) = max(chain_vars) / min(chain_vars);
    end
    
    % Store results
    experiment_results{exp_idx} = struct();
    experiment_results{exp_idx}.scale_factor = scale_factors(exp_idx);
    experiment_results{exp_idx}.proposal_sd = proposal_sd;
    experiment_results{exp_idx}.accept_rate = mean(all_chains_accept);
    experiment_results{exp_idx}.R2_val = R2_val;
    experiment_results{exp_idx}.MAE_val = MAE_val;
    experiment_results{exp_idx}.RMSE_val = RMSE_val;
    experiment_results{exp_idx}.MAPE_val = MAPE_val;
    experiment_results{exp_idx}.r_hat_mean = mean(r_hat_values);
    experiment_results{exp_idx}.r_hat_max = max(r_hat_values);
    experiment_results{exp_idx}.ess_min = min(ess_values);
    experiment_results{exp_idx}.ess_mean = mean(ess_values);
    experiment_results{exp_idx}.conv_time_mean = mean(conv_time);
    experiment_results{exp_idx}.acf_lag1_mean = mean(acf_lag1(~isnan(acf_lag1)));
    experiment_results{exp_idx}.param_range_mean = mean(param_ranges);
    experiment_results{exp_idx}.chain_var_ratio_mean = mean(chain_var_ratio);
    experiment_results{exp_idx}.params_mean = params_mean;
    experiment_results{exp_idx}.n_samples = size(all_samples, 1);
    
    fprintf('Experiment results:\n');
    fprintf('  Accept rate: %.2f%%, R2: %.3f, RMSE: %.3f\n', ...
        mean(all_chains_accept)*100, R2_val, RMSE_val);
    fprintf('  R-hat mean: %.3f, ESS min: %.0f, Conv time: %.0f\n', ...
        mean(r_hat_values), min(ess_values), mean(conv_time));
end

%% =============== 6. Acceptance Rate Visualization ===============
fprintf('\n=== 6. Acceptance rate vs step size scale factor ===\n');

% Extract acceptance rates
scale_factors_array = zeros(n_experiments, 1);
accept_rate_array = zeros(n_experiments, 1);

for i = 1:n_experiments
    scale_factors_array(i) = experiment_results{i}.scale_factor;
    accept_rate_array(i) = experiment_results{i}.accept_rate * 100;
end

% Create single figure for acceptance rate
figure('Position', [100, 100, 800, 600], 'Color', 'white');

% Plot acceptance rate vs step size scale factor
plot(scale_factors_array, accept_rate_array, 'b-o', 'LineWidth', 3, ...
    'MarkerSize', 10, 'MarkerFaceColor', 'b');
hold on;

% Add target acceptance rate lines
plot([min(scale_factors_array), max(scale_factors_array)], [50, 50], ...
    'r--', 'LineWidth', 2, 'DisplayName', 'Single-param optimal (60%)');
plot([min(scale_factors_array), max(scale_factors_array)], [45, 45], ...
    'g--', 'LineWidth', 2, 'DisplayName', 'Multi-param optimal (45%)');

xlabel('Step size scale factor', 'FontSize', 24, 'FontName', 'Times New Roman');
ylabel('Acceptance rate (%)', 'FontSize', 24, 'FontName', 'Times New Roman');
title('MCMC acceptance rate vs step size', 'FontSize', 28, 'FontName', 'Times New Roman', 'FontWeight', 'bold');
legend('Actual acceptance rate', 'Acceptance rate (50%)', 'Acceptance rate (45%)', ...
    'FontSize', 18, 'Location', 'best', 'FontName', 'Times New Roman');
grid on;
set(gca, 'FontSize', 20, 'FontName', 'Times New Roman', 'LineWidth', 1.5);
ylim([40, 90]);

% Add text annotation for optimal points
[~, idx_max] = max(accept_rate_array);
[~, idx_min] = min(accept_rate_array);

% Find point closest to 44%
[~, idx_closest_44] = min(abs(accept_rate_array - 44));


for i = 1:n_experiments
    fprintf('%-8.1f %-12.1f [%.4f, %.4f, %.4f, %.4f, %.4f, %.4f]\n', ...
        scale_factors_array(i), ...
        accept_rate_array(i), ...
        experiment_results{i}.proposal_sd);
end
grid off
%% =============== 7. Results Summary and Analysis ===============
fprintf('\n=== 7. Step size ablation results summary ===\n');

fprintf('\n%-8s %-10s %-8s %-8s %-8s %-8s %-8s %-8s %-8s\n', ...
    'Scale', 'Accept%', 'R2', 'RMSE', 'MAPE%', 'R-hat', 'ESS', 'ConvTime', 'ACF');
fprintf('%s\n', repmat('-', 90, 1));

for i = 1:n_experiments
    fprintf('%-8.1f %-10.1f %-8.3f %-8.3f %-8.1f %-8.3f %-8.0f %-8.0f %-8.3f\n', ...
        experiment_results{i}.scale_factor, ...
        experiment_results{i}.accept_rate * 100, ...
        experiment_results{i}.R2_val, ...
        experiment_results{i}.RMSE_val, ...
        experiment_results{i}.MAPE_val, ...
        experiment_results{i}.r_hat_mean, ...
        experiment_results{i}.ess_mean, ...
        experiment_results{i}.conv_time_mean, ...
        experiment_results{i}.acf_lag1_mean);
end

%% Helper function: Effective Sample Size calculation
function ess = effective_sample_size(samples)
    n = length(samples);
    if n < 100
        ess = n;
        return;
    end
    
    % Calculate autocorrelations
    max_lag = min(1000, floor(n/4));
    acf = zeros(max_lag, 1);
    for lag = 1:max_lag
        acf(lag) = corr(samples(1:end-lag), samples(lag+1:end));
        if isnan(acf(lag))
            acf(lag) = 0;
        end
    end
    
    % Find truncation point
    m = 1;
    while m < max_lag && acf(m) + acf(m+1) > 0
        m = m + 1;
    end
    
    % Calculate ESS
    tau = 1 + 2 * sum(acf(1:m));
    ess = n / tau;
end

function value = reflect_boundary(value, lower, upper)
    % 反射边界函数：当值超出边界时进行反射
    while value < lower || value > upper
        if value < lower
            value = 2*lower - value;  % 从下边界反射
        elseif value > upper
            value = 2*upper - value;  % 从上边界反射
        end
    end
end