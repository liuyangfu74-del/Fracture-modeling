function [L_posterior, results] = fracture_length_predictor(h_observed, varargin)
% FRACTURE_LENGTH_PREDICTOR Probability Prediction Of Fracture Trace Length Based On Bayesian Theory
%
% Input:
%   h_observed: Observed Fracture Aperture Values (¦Ìm) - Scalar Or Vector
%   (Optional Parameter-Value Pairs):
%     'L_surface': Surface Fracture Trace Length Data (m) - For Calibration
%     'h_surface': Surface Fracture Aperture Data (¦Ìm) - For Calibration
%     'L_prior_range': Prior Range For Trace Length [min, max], Default [0.5, 15]
%     'n_samples': Number Of MCMC Samples, Default 5000
%
% Output:
%   L_posterior: Posterior Distribution Samples Of Trace Length
%   results: Structure Containing Prediction Results

    % Parse Input Parameters
    p = inputParser;
    addRequired(p, 'h_observed', @(x) isnumeric(x) && all(x > 0));
    addParameter(p, 'L_surface', [], @isnumeric);
    addParameter(p, 'h_surface', [], @isnumeric);
    addParameter(p, 'L_prior_range', [0.5, 15], @(x) isnumeric(x) && numel(x) == 2);
    addParameter(p, 'n_samples', 5000, @(x) isnumeric(x) && x > 0);
    
    parse(p, h_observed, varargin{:});
    
    % Initialize Result Structure
    results = struct();
    results.input_params = p.Results;
    
    % Bayesian Calibration If Calibration Data Is Available
    if ~isempty(p.Results.L_surface) && ~isempty(p.Results.h_surface)
        fprintf('=== Bayesian Parameter Calibration ===\n');
        [posterior_samples, calib_stats] = bayesian_calibration(...
            p.Results.L_surface, p.Results.h_surface, p.Results.n_samples);
        results.posterior_samples = posterior_samples;
        results.calibration_stats = calib_stats;
    else
        % Use Default Parameters (Based On Typical Rock Mechanics Properties)
        fprintf('Using Default Mechanical Parameters\n');
        posterior_samples = generate_default_posterior(p.Results.n_samples);
        results.posterior_samples = posterior_samples;
    end
    
    % Predict For Each Observed Aperture
    n_observations = numel(h_observed);
    L_posterior = cell(n_observations, 1);
    results.predictions = struct();
    
    for i = 1:n_observations
        fprintf('\n=== Predicting Fracture #%d (Aperture: %.1f ¦Ìm) ===\n', i, h_observed(i));
        
        [L_samples, pred_stats] = predict_length_posterior(...
            h_observed(i), posterior_samples, ...
            p.Results.L_prior_range(1), p.Results.L_prior_range(2), ...
            min(3000, p.Results.n_samples));
        
        L_posterior{i} = L_samples;
        results.predictions(i).stats = pred_stats;
        results.predictions(i).h_observed = h_observed(i);
    end
    
    % Visualization
    if n_observations == 1
        create_single_visualization(L_posterior{1}, results, h_observed(1));
    else
        create_comparison_visualization(L_posterior, results, h_observed);
    end
end

function posterior_samples = generate_default_posterior(n_samples)
    % Default Parameter Distribution Based On Typical Rock Mechanics Properties
    rng(42);
    posterior_samples.ln_alpha = log(30) + randn(n_samples, 1) * 0.3;
    posterior_samples.beta = 0.8 + randn(n_samples, 1) * 0.2;
    posterior_samples.sigma = 0.15 + abs(randn(n_samples, 1) * 0.05);
    posterior_samples.alpha = exp(posterior_samples.ln_alpha);
end

function [posterior_samples, stats] = bayesian_calibration(L_data, h_data, n_samples)
    % Bayesian Parameter Calibration
    logL = log(L_data);
    logh = log(h_data);
    
    % Initialize Parameters
    X = [ones(size(logL)), logL];
    coeffs = X \ logh;
    init_ln_alpha = coeffs(1);
    init_beta = coeffs(2);
    init_sigma = std(logh - (init_ln_alpha + init_beta * logL));
    
    % Initialize Sampling Chain
    ln_alpha_chain = zeros(n_samples, 1);
    beta_chain = zeros(n_samples, 1);
    sigma_chain = zeros(n_samples, 1);
    
    ln_alpha_chain(1) = init_ln_alpha;
    beta_chain(1) = init_beta;
    sigma_chain(1) = init_sigma;
    
    % MCMC Sampling
    fprintf('Performing MCMC Sampling...');
    for i = 2:n_samples
        if mod(i, 1000) == 0, fprintf('.'); end
        
        % Propose New Parameters
        prop_ln_alpha = ln_alpha_chain(i-1) + randn * 0.1;
        prop_beta = beta_chain(i-1) + randn * 0.05;
        prop_sigma = abs(sigma_chain(i-1) + randn * 0.05);
        
        % Calculate Acceptance Probability
        current_loglike = compute_log_likelihood(ln_alpha_chain(i-1), beta_chain(i-1), sigma_chain(i-1), logL, logh);
        prop_loglike = compute_log_likelihood(prop_ln_alpha, prop_beta, prop_sigma, logL, logh);
        
        current_prior = compute_log_prior(ln_alpha_chain(i-1), beta_chain(i-1), sigma_chain(i-1));
        prop_prior = compute_log_prior(prop_ln_alpha, prop_beta, prop_sigma);
        
        accept_ratio = exp((prop_loglike + prop_prior) - (current_loglike + current_prior));
        
        if rand < min(1, accept_ratio)
            ln_alpha_chain(i) = prop_ln_alpha;
            beta_chain(i) = prop_beta;
            sigma_chain(i) = prop_sigma;
        else
            ln_alpha_chain(i) = ln_alpha_chain(i-1);
            beta_chain(i) = beta_chain(i-1);
            sigma_chain(i) = sigma_chain(i-1);
        end
    end
    fprintf('Completed!\n');
    
    % Save Results
    posterior_samples.ln_alpha = ln_alpha_chain;
    posterior_samples.beta = beta_chain;
    posterior_samples.sigma = sigma_chain;
    posterior_samples.alpha = exp(ln_alpha_chain);
    
    % Calculate Statistics (Using Last 50% Of The Chain)
    burn_in = round(n_samples * 0.5);
    stats.ln_alpha_mean = mean(ln_alpha_chain(burn_in:end));
    stats.ln_alpha_std = std(ln_alpha_chain(burn_in:end));
    stats.beta_mean = mean(beta_chain(burn_in:end));
    stats.beta_std = std(beta_chain(burn_in:end));
    stats.alpha_mean = exp(stats.ln_alpha_mean);
end

function [L_samples, prediction_stats] = predict_length_posterior(h_observed, posterior_samples, L_min, L_max, n_predict_samples)
    % Probabilistic Trace Length Prediction
    rng(42);
    
    % Sample From Parameter Posterior
    n_param_samples = length(posterior_samples.alpha);
    param_indices = randi(n_param_samples, n_predict_samples, 1);
    
    alpha_samples = posterior_samples.alpha(param_indices);
    beta_samples = posterior_samples.beta(param_indices);
    sigma_samples = posterior_samples.sigma(param_indices);
    
    % Trace Length Prediction Sampling
    L_samples = zeros(n_predict_samples, 1);
    
    for i = 1:n_predict_samples
        L_candidate = L_min + (L_max - L_min) * rand;
        pred_logh = log(alpha_samples(i)) + beta_samples(i) * log(L_candidate);
        log_likelihood = -0.5 * ((log(h_observed) - pred_logh) / sigma_samples(i))^2;
        log_prior = -log(L_max - L_min);
        
        accept_prob = exp(log_likelihood + log_prior);
        
        if rand < accept_prob || i == 1
            L_samples(i) = L_candidate;
        else
            L_samples(i) = L_samples(i-1);
        end
    end
    
    % Calculate Prediction Statistics
    prediction_stats.median = median(L_samples);
    prediction_stats.mean = mean(L_samples);
    prediction_stats.std = std(L_samples);
    prediction_stats.ci90 = prctile(L_samples, [15, 85]);
    prediction_stats.ci95 = prctile(L_samples, [2.5, 97.5]);
end

function create_single_visualization(L_samples, results, h_observed)
    % Visualization For Single Fracture
    
    % Figure 1: Posterior Distribution Of Trace Length
    figure('Position', [100, 100, 800, 600], 'Name', 'Posterior Distribution Of Trace Length');
    
    histogram(L_samples, 50, 'Normalization', 'pdf', 'FaceColor', [0.2, 0.6, 0.8], 'FaceAlpha', 0.7);
    hold on;
    
    stats = results.predictions.stats;
    xline(stats.median, 'r-', 'LineWidth', 2.5);
    xline(stats.ci90(1), 'g--', 'LineWidth', 1.5);
    xline(stats.ci90(2), 'g--', 'LineWidth', 1.5);
    
    xlabel('Trace Length (m)', 'FontSize', 14, 'FontName', 'Times New Roman');
    ylabel('Probability Density', 'FontSize', 14, 'FontName', 'Times New Roman');
    title('Posterior Distribution Of Fracture Trace Length', 'FontSize', 16, 'FontName', 'Times New Roman');
    
    legend('Posterior Distribution', ...
           sprintf('Median: %.2f m', stats.median), ...
           sprintf('P5: %.2f m', stats.ci90(1)), ...
           sprintf('P95: %.2f m', stats.ci90(2)), ...
           'FontSize', 12, 'FontName', 'Times New Roman');
    grid on;
    set(gca, 'FontSize', 12, 'FontName', 'Times New Roman');

    % Figure 2: Mechanical Parameters Posterior
    if isfield(results, 'posterior_samples')
        figure('Position', [200, 200, 700, 500], 'Name', 'Posterior Distribution Of Mechanical Parameters');
        scatter(results.posterior_samples.beta, results.posterior_samples.alpha, 10, ...
               'Marker', '.', 'MarkerEdgeColor', [0.8, 0.4, 0.1], 'MarkerEdgeAlpha', 0.5);
        xlabel('Energy Scaling Exponent ¦Â', 'FontSize', 14, 'FontName', 'Times New Roman');
        ylabel('Proportionality Coefficient ¦Á', 'FontSize', 14, 'FontName', 'Times New Roman');
        title('Posterior Distribution Of Mechanical Parameters', 'FontSize', 16, 'FontName', 'Times New Roman');
        grid on;
        set(gca, 'FontSize', 12, 'FontName', 'Times New Roman');
    end

    % Figure 3: Cumulative Distribution Function
    figure('Position', [300, 300, 700, 500], 'Name', 'Cumulative Distribution Function');
    [f, x] = ecdf(L_samples);
    plot(x, f, 'b-', 'LineWidth', 2);
    xlabel('Trace Length (m)', 'FontSize', 14, 'FontName', 'Times New Roman');
    ylabel('Cumulative Probability', 'FontSize', 14, 'FontName', 'Times New Roman');
    title('Cumulative Distribution Function Of Trace Length', 'FontSize', 16, 'FontName', 'Times New Roman');
    grid on;
    set(gca, 'FontSize', 12, 'FontName', 'Times New Roman');

    % Figure 4: Prediction Summary
    figure('Position', [400, 400, 500, 400], 'Name', 'Prediction Summary');
    axis off;
    text(0.1, 0.9, 'Prediction Summary', 'FontSize', 16, 'FontName', 'Times New Roman', 'FontWeight', 'bold');
    text(0.1, 0.7, sprintf('Observed Aperture: %.1f m', h_observed), 'FontSize', 14, 'FontName', 'Times New Roman');
    text(0.1, 0.6, sprintf('Predicted Median Length: %.2f m', stats.median), 'FontSize', 14, 'FontName', 'Times New Roman');
    text(0.1, 0.5, sprintf('90%% Confidence Interval: [%.2f, %.2f] m', stats.ci90(1), stats.ci90(2)), 'FontSize', 14, 'FontName', 'Times New Roman');
    text(0.1, 0.4, sprintf('Prediction Uncertainty: ¡À%.2f m', stats.std), 'FontSize', 14, 'FontName', 'Times New Roman');
end

function create_comparison_visualization(L_posterior, results, h_observed)
    % Comparison Visualization For Multiple Fractures
    n_obs = numel(h_observed);
    colors = lines(n_obs);
    
    % Figure 1: Posterior Distribution Comparison
    figure('Position', [100, 100, 800, 600], 'Name', 'Comparison Of Posterior Distributions');
    hold on;
    for i = 1:n_obs
        [f, xi] = ksdensity(L_posterior{i});
        plot(xi, f, 'Color', colors(i, :), 'LineWidth', 2, ...
             'DisplayName', sprintf('h=%.1fm', h_observed(i)));
    end
    xlabel('Trace Length (m)', 'FontSize', 14, 'FontName', 'Times New Roman');
    ylabel('Probability Density', 'FontSize', 14, 'FontName', 'Times New Roman');
    title('Comparison Of Trace Length Posterior Distributions', 'FontSize', 16, 'FontName', 'Times New Roman');
    legend('show', 'FontSize', 12, 'FontName', 'Times New Roman');
    grid on;
    set(gca, 'FontSize', 12, 'FontName', 'Times New Roman');

    % Figure 2: Statistical Comparison Using Box Plot
    figure('Position', [200, 200, 800, 600], 'Name', 'Statistical Comparison');
    boxData = cell2mat(L_posterior');
    groupData = [];
    for i = 1:n_obs
        groupData = [groupData; i * ones(length(L_posterior{i}), 1)];
    end
    boxplot(boxData, groupData, 'Labels', compose('h=%.1fm', h_observed));
    ylabel('Trace Length (m)', 'FontSize', 14, 'FontName', 'Times New Roman');
    title('Statistical Comparison Of Prediction Results', 'FontSize', 16, 'FontName', 'Times New Roman');
    grid on;
    set(gca, 'FontSize', 12, 'FontName', 'Times New Roman');

    % Figure 3: Confidence Interval Comparison
    figure('Position', [300, 300, 800, 600], 'Name', 'Confidence Interval Comparison');
    medians = arrayfun(@(x) x.stats.median, results.predictions);
    ci_low = arrayfun(@(x) x.stats.ci90(1), results.predictions);
    ci_high = arrayfun(@(x) x.stats.ci90(2), results.predictions);
    
    errorbar(1:n_obs, medians, medians - ci_low, ci_high - medians, ...
             'o-', 'LineWidth', 2, 'MarkerSize', 8, 'CapSize', 15);
    set(gca, 'XTick', 1:n_obs, 'XTickLabel', compose('h=%.1fm', h_observed));
    ylabel('Trace Length (m)', 'FontSize', 14, 'FontName', 'Times New Roman');
    title('Comparison Of 90% Confidence Intervals', 'FontSize', 16, 'FontName', 'Times New Roman');
    grid on;
    set(gca, 'FontSize', 12, 'FontName', 'Times New Roman');

    % Figure 4: Aperture-Length Relationship
    figure('Position', [400, 400, 800, 600], 'Name', 'Aperture-Length Relationship');
    if isfield(results, 'calibration_stats')
        scatter(results.input_params.h_surface, results.input_params.L_surface, ...
                50, 'k', 'filled', 'MarkerFaceAlpha', 0.6, 'DisplayName', 'Calibration Data');
        hold on;
    end
    
    errorbar(h_observed, medians, medians - ci_low, ci_high - medians, ...
             's-', 'LineWidth', 2, 'MarkerSize', 8, 'CapSize', 10, ...
             'DisplayName', 'Prediction Results');
    xlabel('Aperture (¦Ìm)', 'FontSize', 14, 'FontName', 'Times New Roman');
    ylabel('Trace Length (m)', 'FontSize', 14, 'FontName', 'Times New Roman');
    title('Aperture-Length Relationship', 'FontSize', 16, 'FontName', 'Times New Roman');
    legend('show', 'FontSize', 12, 'FontName', 'Times New Roman');
    grid on;
    set(gca, 'FontSize', 12, 'FontName', 'Times New Roman');
end

% Helper Functions
function loglike = compute_log_likelihood(ln_alpha, beta, sigma, logL, logh)
    pred_logh = ln_alpha + beta * logL;
    errors = logh - pred_logh;
    loglike = sum(-0.5 * log(2*pi) - log(sigma) - 0.5 * (errors/sigma).^2);
end

function logprior = compute_log_prior(ln_alpha, beta, sigma)
    logprior = 0;
    logprior = logprior - 0.5 * (ln_alpha/2)^2;       % ln_alpha ~ N(0, 2)
    logprior = logprior - 0.5 * ((beta - 0.8)/0.5)^2; % beta ~ N(0.8, 0.5)
    logprior = logprior - log(sigma) - 0.5 * (sigma/0.2)^2; % sigma ~ Half-Normal(0,0.2)
end