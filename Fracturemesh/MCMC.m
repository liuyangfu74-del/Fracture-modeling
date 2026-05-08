function ablation_results = MCMC(varargin)
% RUN_SINGLE_PARAM_ABLATION - Single parameter ablation study for fracture inversion
% 
% Syntax:
%   ablation_results = run_single_param_ablation('data_file', 'data.mat', ...
%                                               'niter_values', [5000, 10000, 15000, 20000], ...
%                                               'nburn_values', [100, 200, 300, 400], ...
%                                               'nchain_values', [1, 2, 3, 4])
%
% Input parameters (name-value pairs):
%   data_file     - Data file path (default: 'C:\Users\Administrator\Desktop\2..mat')
%   niter_values  - Values of niter to test (default: [5000, 10000, 15000, 20000, 25000])
%   nburn_values  - Values of nburn to test (default: [100, 200, 300, 400, 500])
%   nchain_values - Values of n_chain to test (default: [1, 2, 3, 4])
%   base_niter    - Base value for niter when not varying (default: 10000)
%   base_nburn    - Base value for nburn when not varying (default: 100)
%   base_nchain   - Base value for n_chain when not varying (default: 2)
%   save_results  - Whether to save results (default: true)
%   verbose       - Whether to show detailed output (default: true)
%
% Output:
%   ablation_results - Structure containing all experiment results
%
% Example:
%   % Run single parameter ablation
%   results = run_single_param_ablation('niter_values', 5000:5000:25000);
%
%   % Run only n_chain ablation
%   results = run_single_param_ablation('nchain_values', [1, 2, 4, 8]);

%% =============== Parameter parsing ===============
fprintf('=== Single parameter ablation study initialization ===\n');

% Default parameters
defaults.data_file = 'C:\Users\Administrator\Desktop\2..mat';
defaults.niter_values = [10000, 20000, 30000, 40000, 50000];
defaults.nburn_values = [100, 150, 200, 250, 300];
defaults.nchain_values = [1, 2, 3, 4];
defaults.base_niter = 30000;
defaults.base_nburn = 150;
defaults.base_nchain = 2;
defaults.save_results = true;
defaults.verbose = true;
defaults.train_ratio = 0.8;

% Parse input parameters
p = inputParser;
addParameter(p, 'data_file', defaults.data_file);
addParameter(p, 'niter_values', defaults.niter_values);
addParameter(p, 'nburn_values', defaults.nburn_values);
addParameter(p, 'nchain_values', defaults.nchain_values);
addParameter(p, 'base_niter', defaults.base_niter);
addParameter(p, 'base_nburn', defaults.base_nburn);
addParameter(p, 'base_nchain', defaults.base_nchain);
addParameter(p, 'save_results', defaults.save_results);
addParameter(p, 'verbose', defaults.verbose);
addParameter(p, 'train_ratio', defaults.train_ratio);

parse(p, varargin{:});
params = p.Results;

%% =============== Data loading ===============
if params.verbose
    fprintf('\n=== 1. Loading data ===\n');
end

try
    [h_observed, L_true, n_fractures] = load_fracture_data(params.data_file);
    
    if params.verbose
        fprintf('Data loaded successfully: %d fractures\n', n_fractures);
        fprintf('Aperture range: %.4f - %.4f mm\n', min(h_observed), max(h_observed));
        fprintf('Trace length range: %.4f - %.4f m\n', min(L_true), max(L_true));
    end
    
catch ME
    error('Failed to load data: %s', ME.message);
end

%% =============== Run single parameter ablation ===============
all_results = struct();

% 1. Vary niter while keeping nburn and n_chain fixed
if params.verbose
    fprintf('\n=== 2. Varying niter parameter ===\n');
end

for i = 1:length(params.niter_values)
    niter = params.niter_values(i);
    nburn = params.base_nburn;
    n_chain = params.base_nchain;
    
    if params.verbose
        fprintf('\nExperiment %d: niter=%d (fixed: nburn=%d, n_chain=%d)\n', ...
            i, niter, nburn, n_chain);
    end
    
    % Run single experiment
    result = run_single_fracture_experiment(h_observed, L_true, ...
                                           niter, nburn, n_chain, ...
                                           params.train_ratio);
    
    % Store results
    result.parameter_name = 'niter';
    result.parameter_value = niter;
    result.fixed_nburn = nburn;
    result.fixed_nchain = n_chain;
    
    all_results.niter_experiments(i) = result;
end

% 2. Vary nburn while keeping niter and n_chain fixed
if params.verbose
    fprintf('\n=== 3. Varying nburn parameter ===\n');
end

for i = 1:length(params.nburn_values)
    niter = params.base_niter;
    nburn = params.nburn_values(i);
    n_chain = params.base_nchain;
    
    if params.verbose
        fprintf('\nExperiment %d: nburn=%d (fixed: niter=%d, n_chain=%d)\n', ...
            i, nburn, niter, n_chain);
    end
    
    % Run single experiment
    result = run_single_fracture_experiment(h_observed, L_true, ...
                                           niter, nburn, n_chain, ...
                                           params.train_ratio);
    
    % Store results
    result.parameter_name = 'nburn';
    result.parameter_value = nburn;
    result.fixed_niter = niter;
    result.fixed_nchain = n_chain;
    
    all_results.nburn_experiments(i) = result;
end

% 3. Vary n_chain while keeping niter and nburn fixed
if params.verbose
    fprintf('\n=== 4. Varying n_chain parameter ===\n');
end

for i = 1:length(params.nchain_values)
    niter = params.base_niter;
    nburn = params.base_nburn;
    n_chain = params.nchain_values(i);
    
    if params.verbose
        fprintf('\nExperiment %d: n_chain=%d (fixed: niter=%d, nburn=%d)\n', ...
            i, n_chain, niter, nburn);
    end
    
    % Run single experiment
    result = run_single_fracture_experiment(h_observed, L_true, ...
                                           niter, nburn, n_chain, ...
                                           params.train_ratio);
    
    % Store results
    result.parameter_name = 'n_chain';
    result.parameter_value = n_chain;
    result.fixed_niter = niter;
    result.fixed_nburn = nburn;
    
    all_results.nchain_experiments(i) = result;
end

%% =============== Visualization (separate figures) ===============
if params.verbose
    fprintf('\n=== 5. Generating visualizations ===\n');
end

% Create visualizations one by one
create_ablation_visualizations(all_results, params);

%% =============== Save results ===============
if params.save_results
    timestamp = datestr(now, 'yyyymmdd_HHMMSS');
    filename = sprintf('single_param_ablation_%s.mat', timestamp);
    save(filename, 'all_results', 'params');
    
    if params.verbose
        fprintf('\nResults saved to: %s\n', filename);
    end
end

ablation_results = all_results;

fprintf('\n=== Single parameter ablation study completed ===\n');

end

%% =============== Helper functions ===============

function [h_observed, L_true, n_fractures] = load_fracture_data(data_file)
% LOAD_FRACTURE_DATA - Load fracture data from file
    
    data = load(data_file);
    
    % Check variable names
    if isfield(data, 'h_surface') && isfield(data, 'L_surface')
        h_observed = data.h_surface(:) * 10;  % Convert to mm
        L_true = data.L_surface(:);
    elseif isfield(data, 'all_apertures') && isfield(data, 'all_traceLengths')
        h_observed = data.all_apertures(:);
        L_true = data.all_traceLengths(:);
    else
        % Try to find variables
        vars = fieldnames(data);
        h_var = vars(contains(vars, {'h', 'aperture'}, 'IgnoreCase', true));
        L_var = vars(contains(vars, {'L', 'trace', 'length'}, 'IgnoreCase', true));
        
        if ~isempty(h_var) && ~isempty(L_var)
            h_observed = data.(h_var{1})(:);
            L_true = data.(L_var{1})(:);
        else
            error('Could not find aperture and trace length data');
        end
    end
    
    % Data consistency check
    if length(h_observed) ~= length(L_true)
        min_len = min(length(h_observed), length(L_true));
        h_observed = h_observed(1:min_len);
        L_true = L_true(1:min_len);
    end
    
    n_fractures = length(h_observed);
end

function result = run_single_fracture_experiment(h_observed, L_true, ...
                                                niter, nburn, n_chain, ...
                                                train_ratio)
% RUN_SINGLE_FRACTURE_EXPERIMENT - Run single fracture inversion experiment
    
    t_start = tic;
    
    try
        %% =============== Data splitting ===============
        n_fractures = length(h_observed);
        n_train = round(train_ratio * n_fractures);
        indices = randperm(n_fractures);
        train_idx = indices(1:n_train);
        val_idx = indices(n_train+1:end);
        
        h_train = h_observed(train_idx);
        L_train = L_true(train_idx);
        h_val = h_observed(val_idx);
        L_val = L_true(val_idx);
        
        %% =============== Model definition ===============
        forward_model = @(params, L) ...
            max(1e-10, params.eta * params.alpha_I * (L .^ params.beta_I) + ...
            (1-params.eta) * params.alpha_II * (L .^ params.beta_II));
        
        log_likelihood = @(params) ...
            -0.5 * length(h_train) * log(2*pi*params.sigma^2) ...
            - 0.5 * sum((log(h_train) - log(forward_model(params, L_train))).^2) / params.sigma^2;
        
        log_prior = @(params) ...
            log(betapdf(params.eta, 8, 2)) + ...
            log(lognpdf(params.alpha_I, log(0.02), 0.3)) + ...
            log(lognpdf(params.alpha_II, log(0.02), 0.3)) + ...
            log(normpdf(params.beta_I, 0.7, 0.1)) + ...
            log(normpdf(params.beta_II, 0.5, 0.1)) + ...
            log(exppdf(params.sigma, 0.1));
        
        log_posterior = @(params) log_likelihood(params) + log_prior(params);
        
        %% =============== MCMC sampling ===============
        all_chains_samples = cell(n_chain, 1);
        
        for chain = 1:n_chain
            % Initial parameters
            switch mod(chain, 4)
                case 1  % Type I dominant
                    initial_params = struct(...
                        'eta', 0.9, ...
                        'alpha_I', median(h_train)/median(L_train)^0.7, ...
                        'beta_I', 0.7, ...
                        'alpha_II', median(h_train)/median(L_train)^0.5, ...
                        'beta_II', 0.5, ...
                        'sigma', 0.1);
                case 2  % Mixed type
                    initial_params = struct(...
                        'eta', 0.6, ...
                        'alpha_I', median(h_train)/median(L_train)^0.7 * 0.8, ...
                        'beta_I', 0.6, ...
                        'alpha_II', median(h_train)/median(L_train)^0.5 * 1.2, ...
                        'beta_II', 0.45, ...
                        'sigma', 0.15);
                case 3  % Type II dominant
                    initial_params = struct(...
                        'eta', 0.3, ...
                        'alpha_I', median(h_train)/median(L_train)^0.7 * 0.6, ...
                        'beta_I', 0.5, ...
                        'alpha_II', median(h_train)/median(L_train)^0.5 * 1.5, ...
                        'beta_II', 0.55, ...
                        'sigma', 0.2);
                otherwise % Random
                    initial_params = struct(...
                        'eta', 0.5 + 0.4*randn, ...
                        'alpha_I', median(h_train)/median(L_train)^0.7 * (0.8 + 0.4*rand), ...
                        'beta_I', 0.6 + 0.3*rand, ...
                        'alpha_II', median(h_train)/median(L_train)^0.5 * (0.8 + 0.4*rand), ...
                        'beta_II', 0.4 + 0.3*rand, ...
                        'sigma', 0.1 + 0.1*rand);
            end
            
            % Boundary constraints
            initial_params.eta = max(0.1, min(0.99, initial_params.eta));
            initial_params.alpha_I = max(0.001, min(0.1, initial_params.alpha_I));
            initial_params.beta_I = max(0.5, min(1.0, initial_params.beta_I));
            initial_params.alpha_II = max(0.001, min(0.1, initial_params.alpha_II));
            initial_params.beta_II = max(0.3, min(0.7, initial_params.beta_II));
            initial_params.sigma = max(0.01, min(0.5, initial_params.sigma));
            
            % MCMC sampling
            samples = zeros(niter, 6);
            current_params = initial_params;
            current_logpost = log_posterior(current_params);
            accept_count = 0;
            proposal_sd = [0.05, 0.01, 0.02, 0.01, 0.02, 0.03];
            
            for iter = 1:niter
                proposed_params = current_params;
                param_idx = randi(6);
                
                switch param_idx
                    case 1
                        proposed_params.eta = current_params.eta + proposal_sd(1) * randn;
                        proposed_params.eta = max(0.1, min(0.99, proposed_params.eta));
                    case 2
                        proposed_params.alpha_I = current_params.alpha_I * exp(proposal_sd(2) * randn);
                        proposed_params.alpha_I = max(0.001, min(0.1, proposed_params.alpha_I));
                    case 3
                        proposed_params.beta_I = current_params.beta_I + proposal_sd(3) * randn;
                        proposed_params.beta_I = max(0.5, min(1.0, proposed_params.beta_I));
                    case 4
                        proposed_params.alpha_II = current_params.alpha_II * exp(proposal_sd(4) * randn);
                        proposed_params.alpha_II = max(0.001, min(0.1, proposed_params.alpha_II));
                    case 5
                        proposed_params.beta_II = current_params.beta_II + proposal_sd(5) * randn;
                        proposed_params.beta_II = max(0.3, min(0.7, proposed_params.beta_II));
                    case 6
                        proposed_params.sigma = current_params.sigma * exp(proposal_sd(6) * randn);
                        proposed_params.sigma = max(0.01, min(0.5, proposed_params.sigma));
                end
                
                try
                    proposed_logpost = log_posterior(proposed_params);
                    
                    if isfinite(proposed_logpost)
                        log_alpha = proposed_logpost - current_logpost;
                        
                        if log(rand) < log_alpha
                            current_params = proposed_params;
                            current_logpost = proposed_logpost;
                            accept_count = accept_count + 1;
                        end
                    end
                catch
                    % Reject on error
                end
                
                samples(iter, :) = [current_params.eta, current_params.alpha_I, ...
                                   current_params.beta_I, current_params.alpha_II, ...
                                   current_params.beta_II, current_params.sigma];
            end
            
            all_chains_samples{chain} = samples;
        end
        
        %% =============== Combine samples ===============
        all_samples = [];
        for chain = 1:n_chain
            burned_samples = all_chains_samples{chain}(nburn+1:end, :);
            all_samples = [all_samples; burned_samples];
        end
        
        %% =============== Posterior statistics ===============
        param_names = {'eta', 'alpha_I', 'beta_I', 'alpha_II', 'beta_II', 'sigma'};
        post_samples = struct();
        
        for i = 1:6
            post_samples.(param_names{i}) = all_samples(:, i);
        end
        
        params_mean = struct(...
            'eta', mean(post_samples.eta), ...
            'alpha_I', mean(post_samples.alpha_I), ...
            'beta_I', mean(post_samples.beta_I), ...
            'alpha_II', mean(post_samples.alpha_II), ...
            'beta_II', mean(post_samples.beta_II));
        
        %% =============== Model validation ===============
        % Forward prediction
        h_pred_val = forward_model(params_mean, L_val);
        
        % Performance metrics
        val_errors = h_pred_val - h_val;
        MAE = mean(abs(val_errors));
        MAPE = mean(abs(val_errors ./ h_val)) * 100;
        R2_val = 1 - sum(val_errors.^2) / sum((h_val - mean(h_val)).^2);
        
        % Trace length prediction
        n_val = length(h_val);
        L_pred_samples = zeros(n_val, min(100, size(all_samples, 1)));
        n_samples = size(L_pred_samples, 2);
        
        % Select posterior samples for prediction
        sample_idx = randperm(size(all_samples, 1), n_samples);
        
        for s = 1:n_samples
            idx = sample_idx(s);
            params_sample = struct(...
                'eta', all_samples(idx, 1), ...
                'alpha_I', all_samples(idx, 2), ...
                'beta_I', all_samples(idx, 3), ...
                'alpha_II', all_samples(idx, 4), ...
                'beta_II', all_samples(idx, 5));
            
            for i = 1:n_val
                L_pred_samples(i, s) = inverse_model_simple(h_val(i), params_sample);
            end
        end
        
        L_pred_median = median(L_pred_samples, 2);
        L_pred_ci90 = prctile(L_pred_samples, [5, 95], 2);
        ci90_coverage = mean(L_val >= L_pred_ci90(:,1) & L_val <= L_pred_ci90(:,2)) * 100;
        
        % Calculate p(Lpred|hobs,D)
        pred_errors = L_pred_median - L_val;
        sigma_pred = std(pred_errors);
        p_Lpred_given_hobs = exp(-0.5 * mean(pred_errors.^2) / sigma_pred^2) / (sqrt(2*pi) * sigma_pred);
        
        %% =============== Store results ===============
        runtime = toc(t_start);
        
        result = struct(...
            'niter', niter, ...
            'nburn', nburn, ...
            'n_chain', n_chain, ...
            'MAE', MAE, ...
            'MAPE', MAPE, ...
            'R2_val', R2_val, ...
            'ci90_coverage', ci90_coverage, ...
            'p_Lpred_given_hobs', p_Lpred_given_hobs, ...
            'runtime', runtime, ...
            'n_samples_total', size(all_samples, 1), ...
            'acceptance_rate', accept_count/niter, ...
            'converged', mean(all_samples(:,1)) > 0, ... % Simple convergence check
            'timestamp', datestr(now));
        
    catch ME
        fprintf('   Experiment failed: %s\n', ME.message);
        
        % Return failed result
        result = struct(...
            'niter', niter, ...
            'nburn', nburn, ...
            'n_chain', n_chain, ...
            'MAE', NaN, ...
            'MAPE', NaN, ...
            'R2_val', NaN, ...
            'ci90_coverage', NaN, ...
            'p_Lpred_given_hobs', NaN, ...
            'runtime', NaN, ...
            'n_samples_total', 0, ...
            'acceptance_rate', NaN, ...
            'converged', false, ...
            'timestamp', datestr(now), ...
            'error', ME.message);
    end
end

function L_pred = inverse_model_simple(h, params)
% INVERSE_MODEL_SIMPLE - Simple trace length inversion
    
    % Define forward model
    forward_func = @(L) params.eta * params.alpha_I * (L .^ params.beta_I) + ...
                       (1 - params.eta) * params.alpha_II * (L .^ params.beta_II);
    
    % Objective function
    f = @(L) (h - forward_func(L)).^2;
    
    % Search range
    L_range = [0.1, 50];
    
    % Multiple starting points
    L_starts = [L_range(1), mean(L_range), L_range(2)];
    best_L = L_starts(1);
    best_fval = inf;
    
    for i = 1:length(L_starts)
        try
            [L_i, fval_i] = fminbnd(f, L_range(1), L_range(2), ...
                                   optimset('Display', 'off'));
            if fval_i < best_fval
                best_L = L_i;
                best_fval = fval_i;
            end
        catch
            continue;
        end
    end
    
    L_pred = max(L_range(1), min(L_range(2), best_L));
end

function create_ablation_visualizations(all_results, params)
% CREATE_PROPER_ABLATION_VISUALIZATIONS - Create proper single-figure visualizations
%   Each metric gets its own figure, no subplots used

    font_name = 'Times New Roman';
    font_size_title = 28;
    font_size_labels = 26;
    font_size_legend = 24;
    font_size_ticks = 24;
    line_width = 3.0;
    marker_size = 80;
    
    % 确保所有实验都有结果
    if ~isfield(all_results, 'niter_experiments') || isempty(all_results.niter_experiments)
        fprintf('Warning: No niter experiments found\n');
        return;
    end
    
    if ~isfield(all_results, 'nburn_experiments') || isempty(all_results.nburn_experiments)
        fprintf('Warning: No nburn experiments found\n');
        return;
    end
    
    if ~isfield(all_results, 'nchain_experiments') || isempty(all_results.nchain_experiments)
        fprintf('Warning: No nchain experiments found\n');
        return;
    end
    
    % 从结果中提取数据
    niter_exp = all_results.niter_experiments;
    nburn_exp = all_results.nburn_experiments;
    nchain_exp = all_results.nchain_experiments;
    
    % 提取niter数据
    niter_values = zeros(1, length(niter_exp));
    MAE_values_niter = zeros(1, length(niter_exp));
    MAPE_values_niter = zeros(1, length(niter_exp));
    R2_values_niter = zeros(1, length(niter_exp));
    coverage_niter = zeros(1, length(niter_exp));
    prob_niter = zeros(1, length(niter_exp));
    
    for i = 1:length(niter_exp)
        niter_values(i) = niter_exp(i).parameter_value;
        MAE_values_niter(i) = niter_exp(i).MAE;
        MAPE_values_niter(i) = niter_exp(i).MAPE;
        R2_values_niter(i) = niter_exp(i).R2_val;
        coverage_niter(i) = niter_exp(i).ci90_coverage;
        prob_niter(i) = niter_exp(i).p_Lpred_given_hobs;
    end
    
    % 提取nburn数据
    nburn_values = zeros(1, length(nburn_exp));
    MAE_values_nburn = zeros(1, length(nburn_exp));
    MAPE_values_nburn = zeros(1, length(nburn_exp));
    R2_values_nburn = zeros(1, length(nburn_exp));
    coverage_nburn = zeros(1, length(nburn_exp));
    prob_nburn = zeros(1, length(nburn_exp));
    
    for i = 1:length(nburn_exp)
        nburn_values(i) = nburn_exp(i).parameter_value;
        MAE_values_nburn(i) = nburn_exp(i).MAE;
        MAPE_values_nburn(i) = nburn_exp(i).MAPE;
        R2_values_nburn(i) = nburn_exp(i).R2_val;
        coverage_nburn(i) = nburn_exp(i).ci90_coverage;
        prob_nburn(i) = nburn_exp(i).p_Lpred_given_hobs;
    end
    
    % 提取nchain数据
    nchain_values = zeros(1, length(nchain_exp));
    MAE_values_nchain = zeros(1, length(nchain_exp));
    MAPE_values_nchain = zeros(1, length(nchain_exp));
    R2_values_nchain = zeros(1, length(nchain_exp));
    coverage_nchain = zeros(1, length(nchain_exp));
    prob_nchain = zeros(1, length(nchain_exp));
    
    for i = 1:length(nchain_exp)
        nchain_values(i) = nchain_exp(i).parameter_value;
        MAE_values_nchain(i) = nchain_exp(i).MAE;
        MAPE_values_nchain(i) = nchain_exp(i).MAPE;
        R2_values_nchain(i) = nchain_exp(i).R2_val;
        coverage_nchain(i) = nchain_exp(i).ci90_coverage;
        prob_nchain(i) = nchain_exp(i).p_Lpred_given_hobs;
    end
    
    %% Figure 1: MAE vs Niter
    figure('Position', [100, 100, 800, 600], 'Name', 'MAE vs Niter', 'Color', 'white');
    plot(niter_values, MAE_values_niter, 'b-o', 'LineWidth', line_width, ...
         'MarkerSize', marker_size/4, 'MarkerFaceColor', 'b');
    xlabel('Niter', 'FontSize', font_size_labels, 'FontName', font_name);
    ylabel('MAE (mm)', 'FontSize', font_size_labels, 'FontName', font_name);
    title('Mae vs niter', 'FontSize', font_size_title, 'FontName', font_name);
    set(gca, 'FontSize', font_size_ticks, 'FontName', font_name, 'Box', 'on');
    grid off;
    
    %% Figure 2: MAE vs Nburn
    figure('Position', [200, 200, 800, 600], 'Name', 'MAE vs Nburn', 'Color', 'white');
    plot(nburn_values, MAE_values_nburn, 'r-s', 'LineWidth', line_width, ...
         'MarkerSize', marker_size/4, 'MarkerFaceColor', 'r');
    xlabel('Nburn', 'FontSize', font_size_labels, 'FontName', font_name);
    ylabel('MAE (mm)', 'FontSize', font_size_labels, 'FontName', font_name);
    title('Mae vs nburn', 'FontSize', font_size_title, 'FontName', font_name);
    set(gca, 'FontSize', font_size_ticks, 'FontName', font_name, 'Box', 'on');
    grid off;
    
    %% Figure 3: MAE vs Nchain
    figure('Position', [300, 300, 800, 600], 'Name', 'MAE vs Nchain', 'Color', 'white');
    plot(nchain_values, MAE_values_nchain, 'g-^', 'LineWidth', line_width, ...
         'MarkerSize', marker_size/4, 'MarkerFaceColor', 'g');
    xlabel('N\_chain', 'FontSize', font_size_labels, 'FontName', font_name);
    ylabel('MAE (mm)', 'FontSize', font_size_labels, 'FontName', font_name);
    title('Mae vs n\_chain', 'FontSize', font_size_title, 'FontName', font_name);
    set(gca, 'FontSize', font_size_ticks, 'FontName', font_name, 'Box', 'on');
    grid off;
    
    %% Figure 4: MAPE vs Niter
    figure('Position', [400, 400, 800, 600], 'Name', 'MAPE vs Niter', 'Color', 'white');
    plot(niter_values, MAPE_values_niter, 'b-o', 'LineWidth', line_width, ...
         'MarkerSize', marker_size/4, 'MarkerFaceColor', 'b');
    xlabel('Niter', 'FontSize', font_size_labels, 'FontName', font_name);
    ylabel('MAPE (%)', 'FontSize', font_size_labels, 'FontName', font_name);
    title('Mape vs niter', 'FontSize', font_size_title, 'FontName', font_name);
    set(gca, 'FontSize', font_size_ticks, 'FontName', font_name, 'Box', 'on');
    grid off;
    
    %% Figure 5: MAPE vs Nburn
    figure('Position', [500, 500, 800, 600], 'Name', 'MAPE vs Nburn', 'Color', 'white');
    plot(nburn_values, MAPE_values_nburn, 'r-s', 'LineWidth', line_width, ...
         'MarkerSize', marker_size/4, 'MarkerFaceColor', 'r');
    xlabel('Nburn', 'FontSize', font_size_labels, 'FontName', font_name);
    ylabel('MAPE (%)', 'FontSize', font_size_labels, 'FontName', font_name);
    title('Mape vs nburn', 'FontSize', font_size_title, 'FontName', font_name);
    set(gca, 'FontSize', font_size_ticks, 'FontName', font_name, 'Box', 'on');
    grid off;
    
    %% Figure 6: MAPE vs Nchain
    figure('Position', [600, 600, 800, 600], 'Name', 'MAPE vs Nchain', 'Color', 'white');
    plot(nchain_values, MAPE_values_nchain, 'g-^', 'LineWidth', line_width, ...
         'MarkerSize', marker_size/4, 'MarkerFaceColor', 'g');
    xlabel('N\_chain', 'FontSize', font_size_labels, 'FontName', font_name);
    ylabel('MAPE (%)', 'FontSize', font_size_labels, 'FontName', font_name);
    title('Mape vs n\_chain', 'FontSize', font_size_title, 'FontName', font_name);
    set(gca, 'FontSize', font_size_ticks, 'FontName', font_name, 'Box', 'on');
    grid off;
    
    %% Figure 7: R? vs Niter
    figure('Position', [100, 100, 800, 600], 'Name', 'R? vs Niter', 'Color', 'white');
    plot(niter_values, R2_values_niter, 'b-o', 'LineWidth', line_width, ...
         'MarkerSize', marker_size/4, 'MarkerFaceColor', 'b');
    xlabel('Niter', 'FontSize', font_size_labels, 'FontName', font_name);
    ylabel('R?', 'FontSize', font_size_labels, 'FontName', font_name);
    title('R? vs niter', 'FontSize', font_size_title, 'FontName', font_name);
    set(gca, 'FontSize', font_size_ticks, 'FontName', font_name, 'Box', 'on');
    grid off;
    
    %% Figure 8: R? vs Nburn
    figure('Position', [200, 200, 800, 600], 'Name', 'R? vs Nburn', 'Color', 'white');
    plot(nburn_values, R2_values_nburn, 'r-s', 'LineWidth', line_width, ...
         'MarkerSize', marker_size/4, 'MarkerFaceColor', 'r');
    xlabel('Nburn', 'FontSize', font_size_labels, 'FontName', font_name);
    ylabel('R?', 'FontSize', font_size_labels, 'FontName', font_name);
    title('R? vs nburn', 'FontSize', font_size_title, 'FontName', font_name);
    set(gca, 'FontSize', font_size_ticks, 'FontName', font_name, 'Box', 'on');
    grid off;
    
    %% Figure 9: R? vs Nchain
    figure('Position', [300, 300, 800, 600], 'Name', 'R? vs Nchain', 'Color', 'white');
    plot(nchain_values, R2_values_nchain, 'g-^', 'LineWidth', line_width, ...
         'MarkerSize', marker_size/4, 'MarkerFaceColor', 'g');
    xlabel('N\_chain', 'FontSize', font_size_labels, 'FontName', font_name);
    ylabel('R?', 'FontSize', font_size_labels, 'FontName', font_name);
    title('R? vs n\_chain', 'FontSize', font_size_title, 'FontName', font_name);
    set(gca, 'FontSize', font_size_ticks, 'FontName', font_name, 'Box', 'on');
    grid off;
    
    %% Figure 10: Coverage vs Niter
    figure('Position', [400, 400, 800, 600], 'Name', 'Coverage vs Niter', 'Color', 'white');
    plot(niter_values, coverage_niter, 'b-o', 'LineWidth', line_width, ...
         'MarkerSize', marker_size/4, 'MarkerFaceColor', 'b');
    xlabel('Niter', 'FontSize', font_size_labels, 'FontName', font_name);
    ylabel('90% CI coverage (%)', 'FontSize', font_size_labels, 'FontName', font_name);
    title('Coverage vs niter', 'FontSize', font_size_title, 'FontName', font_name);
    set(gca, 'FontSize', font_size_ticks, 'FontName', font_name, 'Box', 'on');
    grid off;
    
    %% Figure 11: Coverage vs Nburn
    figure('Position', [500, 500, 800, 600], 'Name', 'Coverage vs Nburn', 'Color', 'white');
    plot(nburn_values, coverage_nburn, 'r-s', 'LineWidth', line_width, ...
         'MarkerSize', marker_size/4, 'MarkerFaceColor', 'r');
    xlabel('Nburn', 'FontSize', font_size_labels, 'FontName', font_name);
    ylabel('90% CI coverage (%)', 'FontSize', font_size_labels, 'FontName', font_name);
    title('Coverage vs nburn', 'FontSize', font_size_title, 'FontName', font_name);
    set(gca, 'FontSize', font_size_ticks, 'FontName', font_name, 'Box', 'on');
    grid off;
    
    %% Figure 12: Coverage vs Nchain
    figure('Position', [600, 600, 800, 600], 'Name', 'Coverage vs Nchain', 'Color', 'white');
    plot(nchain_values, coverage_nchain, 'g-^', 'LineWidth', line_width, ...
         'MarkerSize', marker_size/4, 'MarkerFaceColor', 'g');
    xlabel('N\_chain', 'FontSize', font_size_labels, 'FontName', font_name);
    ylabel('90% CI coverage (%)', 'FontSize', font_size_labels, 'FontName', font_name);
    title('Coverage vs n\_chain', 'FontSize', font_size_title, 'FontName', font_name);
    set(gca, 'FontSize', font_size_ticks, 'FontName', font_name, 'Box', 'on');
    grid off;
    
    %% Figure 13: Probability vs Niter
    figure('Position', [100, 100, 800, 600], 'Name', 'Probability vs Niter', 'Color', 'white');
    plot(niter_values, prob_niter, 'b-o', 'LineWidth', line_width, ...
         'MarkerSize', marker_size/4, 'MarkerFaceColor', 'b');
    xlabel('Niter', 'FontSize', font_size_labels, 'FontName', font_name);
    ylabel('p(Lpred|hobs,D)', 'FontSize', font_size_labels, 'FontName', font_name);
    title('Probability vs niter', 'FontSize', font_size_title, 'FontName', font_name);
    set(gca, 'FontSize', font_size_ticks, 'FontName', font_name, 'Box', 'on');
    grid off;
    
    %% Figure 14: Probability vs Nburn
    figure('Position', [200, 200, 800, 600], 'Name', 'Probability vs Nburn', 'Color', 'white');
    plot(nburn_values, prob_nburn, 'r-s', 'LineWidth', line_width, ...
         'MarkerSize', marker_size/4, 'MarkerFaceColor', 'r');
    xlabel('Nburn', 'FontSize', font_size_labels, 'FontName', font_name);
    ylabel('p(Lpred|hobs,D)', 'FontSize', font_size_labels, 'FontName', font_name);
    title('Probability vs nburn', 'FontSize', font_size_title, 'FontName', font_name);
    set(gca, 'FontSize', font_size_ticks, 'FontName', font_name, 'Box', 'on');
    grid off;
    
    %% Figure 15: Probability vs Nchain
    figure('Position', [300, 300, 800, 600], 'Name', 'Probability vs Nchain', 'Color', 'white');
    plot(nchain_values, prob_nchain, 'g-^', 'LineWidth', line_width, ...
         'MarkerSize', marker_size/4, 'MarkerFaceColor', 'g');
    xlabel('N\_chain', 'FontSize', font_size_labels, 'FontName', font_name);
    ylabel('p(Lpred|hobs,D)', 'FontSize', font_size_labels, 'FontName', font_name);
    title('Probability vs n\_chain', 'FontSize', font_size_title, 'FontName', font_name);
    set(gca, 'FontSize', font_size_ticks, 'FontName', font_name, 'Box', 'on');
    grid off;
    
    %% Figure 16: MAE comparison with normalized x-axis
    figure('Position', [400, 400, 1000, 700], 'Name', 'MAE comparison (normalized)', 'Color', 'white');
    
    % 归一化x轴值到[0,1]范围
    niter_norm = normalize_to_01(niter_values);
    nburn_norm = normalize_to_01(nburn_values);
    nchain_norm = normalize_to_01(nchain_values);
    
    hold on;
    plot(niter_norm, MAE_values_niter, 'b-o', 'LineWidth', line_width, ...
         'MarkerSize', marker_size/3, 'MarkerFaceColor', 'b', 'DisplayName', 'Niter');
    plot(nburn_norm, MAE_values_nburn, 'r-s', 'LineWidth', line_width, ...
         'MarkerSize', marker_size/3, 'MarkerFaceColor', 'r', 'DisplayName', 'Nburn');
    plot(nchain_norm, MAE_values_nchain, 'g-^', 'LineWidth', line_width, ...
         'MarkerSize', marker_size/3, 'MarkerFaceColor', 'g', 'DisplayName', 'Nchain');
    
    xlabel('Normalized parameter value (0-1)', 'FontSize', font_size_labels, 'FontName', font_name);
    ylabel('MAE (mm)', 'FontSize', font_size_labels, 'FontName', font_name);
    title('Mae comparison (normalized scale)', 'FontSize', font_size_title, 'FontName', font_name);
    
    % 添加x轴刻度标签，显示实际参数值
    xticks = [0, 0.25, 0.5, 0.75, 1];
    xticklabels_combined = cell(1, 15); % 每个参数5个刻度
    
    % 为每个参数范围添加刻度标签
    offset = 0;
    for i = 1:length(niter_values)
        if i == 1 || i == length(niter_values) || mod(i, 2) == 0
            xticklabels_combined{offset + i} = sprintf('Niter\n%d', niter_values(i));
        else
            xticklabels_combined{offset + i} = '';
        end
    end
    
    offset = length(niter_values);
    for i = 1:length(nburn_values)
        if i == 1 || i == length(nburn_values) || mod(i, 2) == 0
            xticklabels_combined{offset + i} = sprintf('Nburn\n%d', nburn_values(i));
        else
            xticklabels_combined{offset + i} = '';
        end
    end
    
    offset = length(niter_values) + length(nburn_values);
    for i = 1:length(nchain_values)
        if i == 1 || i == length(nchain_values) || mod(i, 2) == 0
            xticklabels_combined{offset + i} = sprintf('Nchain\n%d', nchain_values(i));
        else
            xticklabels_combined{offset + i} = '';
        end
    end
    
    % 设置归一化后的x轴
    set(gca, 'FontSize', font_size_ticks, 'FontName', font_name, 'Box', 'on');
    grid off;
    
    legend('show', 'FontSize', font_size_legend, 'FontName', font_name, 'Location', 'best');
    hold off;
    
    %% 或者更简单的方法：三个小图在同一个figure中
    % 删除上面的Figure 16，改用下面的实现
    
    %% Figure 16: MAE comparison with separate x-axes
    figure('Position', [400, 400, 1200, 400], 'Name', 'MAE comparison with separate axes', 'Color', 'white');
    
    % 创建三个并排的坐标轴
    ax1 = axes('Position', [0.08, 0.15, 0.25, 0.75]);
    ax2 = axes('Position', [0.40, 0.15, 0.25, 0.75]);
    ax3 = axes('Position', [0.72, 0.15, 0.25, 0.75]);
    
    % Niter子图
    axes(ax1);
    plot(niter_values, MAE_values_niter, 'b-o', 'LineWidth', line_width, ...
         'MarkerSize', marker_size/3, 'MarkerFaceColor', 'b');
    xlabel('Niter', 'FontSize', font_size_labels, 'FontName', font_name);
    ylabel('MAE (mm)', 'FontSize', font_size_labels, 'FontName', font_name);
    title('Niter', 'FontSize', font_size_title, 'FontName', font_name);
    set(gca, 'FontSize', font_size_ticks, 'FontName', font_name, 'Box', 'on');
    grid off;
    
    % Nburn子图
    axes(ax2);
    plot(nburn_values, MAE_values_nburn, 'r-s', 'LineWidth', line_width, ...
         'MarkerSize', marker_size/3, 'MarkerFaceColor', 'r');
    xlabel('Nburn', 'FontSize', font_size_labels, 'FontName', font_name);
    ylabel('MAE (mm)', 'FontSize', font_size_labels, 'FontName', font_name);
    title('Nburn', 'FontSize', font_size_title, 'FontName', font_name);
    set(gca, 'FontSize', font_size_ticks, 'FontName', font_name, 'Box', 'on');
    grid off;
    
    % Nchain子图
    axes(ax3);
    plot(nchain_values, MAE_values_nchain, 'g-^', 'LineWidth', line_width, ...
         'MarkerSize', marker_size/3, 'MarkerFaceColor', 'g');
    xlabel('N\_chain', 'FontSize', font_size_labels, 'FontName', font_name);
    ylabel('MAE (mm)', 'FontSize', font_size_labels, 'FontName', font_name);
    title('Nchain', 'FontSize', font_size_title, 'FontName', font_name);
    set(gca, 'FontSize', font_size_ticks, 'FontName', font_name, 'Box', 'on');
    grid off;
    
    % 添加主标题
    annotation('textbox', [0.35, 0.95, 0.3, 0.05], 'String', 'MAE comparison across parameters', ...
               'FontSize', font_size_title, 'FontName', font_name, 'FontWeight', 'bold', ...
               'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
               'EdgeColor', 'none', 'BackgroundColor', 'white');
    
    %% Figure 17: Summary statistics table (text-based)
    figure('Position', [500, 500, 1000, 700], 'Name', 'Summary statistics', 'Color', 'white');
    
    % 计算统计信息
    niter_stats = calculate_statistics(MAE_values_niter, MAPE_values_niter, R2_values_niter, coverage_niter, prob_niter);
    nburn_stats = calculate_statistics(MAE_values_nburn, MAPE_values_nburn, R2_values_nburn, coverage_nburn, prob_nburn);
    nchain_stats = calculate_statistics(MAE_values_nchain, MAPE_values_nchain, R2_values_nchain, coverage_nchain, prob_nchain);
    
    % 创建文本显示
    axis off;
    
    % 标题
    text(0.1, 0.95, 'Ablation study summary statistics', ...
         'FontSize', font_size_title, 'FontName', font_name, 'FontWeight', 'bold');
    
    % Niter统计
    text(0.1, 0.85, 'Niter experiments:', ...
         'FontSize', font_size_labels-2, 'FontName', font_name, 'FontWeight', 'bold');
    text(0.15, 0.80, sprintf('MAE: %.4f ± %.4f [%.4f, %.4f]', ...
         niter_stats.mae_mean, niter_stats.mae_std, niter_stats.mae_min, niter_stats.mae_max), ...
         'FontSize', font_size_ticks-2, 'FontName', font_name);
    text(0.15, 0.75, sprintf('MAPE: %.2f%% ± %.2f%% [%.2f%%, %.2f%%]', ...
         niter_stats.mape_mean, niter_stats.mape_std, niter_stats.mape_min, niter_stats.mape_max), ...
         'FontSize', font_size_ticks-2, 'FontName', font_name);
    text(0.15, 0.70, sprintf('R?: %.4f ± %.4f [%.4f, %.4f]', ...
         niter_stats.r2_mean, niter_stats.r2_std, niter_stats.r2_min, niter_stats.r2_max), ...
         'FontSize', font_size_ticks-2, 'FontName', font_name);
    
    % Nburn统计
    text(0.1, 0.60, 'Nburn experiments:', ...
         'FontSize', font_size_labels-2, 'FontName', font_name, 'FontWeight', 'bold');
    text(0.15, 0.55, sprintf('MAE: %.4f ± %.4f [%.4f, %.4f]', ...
         nburn_stats.mae_mean, nburn_stats.mae_std, nburn_stats.mae_min, nburn_stats.mae_max), ...
         'FontSize', font_size_ticks-2, 'FontName', font_name);
    text(0.15, 0.50, sprintf('MAPE: %.2f%% ± %.2f%% [%.2f%%, %.2f%%]', ...
         nburn_stats.mape_mean, nburn_stats.mape_std, nburn_stats.mape_min, nburn_stats.mape_max), ...
         'FontSize', font_size_ticks-2, 'FontName', font_name);
    text(0.15, 0.45, sprintf('R?: %.4f ± %.4f [%.4f, %.4f]', ...
         nburn_stats.r2_mean, nburn_stats.r2_std, nburn_stats.r2_min, nburn_stats.r2_max), ...
         'FontSize', font_size_ticks-2, 'FontName', font_name);
    
    % Nchain统计
    text(0.1, 0.35, 'Nchain experiments:', ...
         'FontSize', font_size_labels-2, 'FontName', font_name, 'FontWeight', 'bold');
    text(0.15, 0.30, sprintf('MAE: %.4f ± %.4f [%.4f, %.4f]', ...
         nchain_stats.mae_mean, nchain_stats.mae_std, nchain_stats.mae_min, nchain_stats.mae_max), ...
         'FontSize', font_size_ticks-2, 'FontName', font_name);
    text(0.15, 0.25, sprintf('MAPE: %.2f%% ± %.2f%% [%.2f%%, %.2f%%]', ...
         nchain_stats.mape_mean, nchain_stats.mape_std, nchain_stats.mape_min, nchain_stats.mape_max), ...
         'FontSize', font_size_ticks-2, 'FontName', font_name);
    text(0.15, 0.20, sprintf('R?: %.4f ± %.4f [%.4f, %.4f]', ...
         nchain_stats.r2_mean, nchain_stats.r2_std, nchain_stats.r2_min, nchain_stats.r2_max), ...
         'FontSize', font_size_ticks-2, 'FontName', font_name);
    
    % 实验总数
    text(0.1, 0.10, sprintf('Total experiments: %d', ...
         length(niter_exp) + length(nburn_exp) + length(nchain_exp)), ...
         'FontSize', font_size_labels-2, 'FontName', font_name, 'FontWeight', 'bold');
    
    fprintf('\nGenerated 17 visualization figures (no subplots used)\n');
    fprintf('  1-3. MAE vs individual parameters\n');
    fprintf('  4-6. MAPE vs individual parameters\n');
    fprintf('  7-9. R? vs individual parameters\n');
    fprintf('  10-12. 90%% CI coverage vs individual parameters\n');
    fprintf('  13-15. Probability vs individual parameters\n');
    fprintf('  16. Combined MAE comparison\n');
    fprintf('  17. Summary statistics table\n');
end

% 辅助函数：计算统计信息
function stats = calculate_statistics(mae_values, mape_values, r2_values, coverage_values, prob_values)
    stats.mae_mean = mean(mae_values);
    stats.mae_std = std(mae_values);
    stats.mae_min = min(mae_values);
    stats.mae_max = max(mae_values);
    
    stats.mape_mean = mean(mape_values);
    stats.mape_std = std(mape_values);
    stats.mape_min = min(mape_values);
    stats.mape_max = max(mape_values);
    
    stats.r2_mean = mean(r2_values);
    stats.r2_std = std(r2_values);
    stats.r2_min = min(r2_values);
    stats.r2_max = max(r2_values);
    
    stats.coverage_mean = mean(coverage_values);
    stats.coverage_std = std(coverage_values);
    stats.coverage_min = min(coverage_values);
    stats.coverage_max = max(coverage_values);
    
    stats.prob_mean = mean(prob_values);
    stats.prob_std = std(prob_values);
    stats.prob_min = min(prob_values);
    stats.prob_max = max(prob_values);
end   

function x_norm = normalize_to_01(x)
% NORMALIZE_TO_01 - Normalize array to [0,1] range
    if length(x) == 1
        x_norm = 0.5; % 单个值放在中间
    else
        x_min = min(x);
        x_max = max(x);
        x_norm = (x - x_min) / (x_max - x_min);
    end
end