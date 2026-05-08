function [results, figs] = length_validation(measured_lengths, measured_apertures, predicted_lengths, options)
%LENGTH_VALIDATION Validate fracture length prediction accuracy based on aperture

% Default parameters
defaultOptions.alpha = 0.05;
defaultOptions.num_bootstrap = 1000;
defaultOptions.plot_results = true;
defaultOptions.data_names = {'Measured', 'Predicted'};

% Merge options
if nargin < 4
    options = defaultOptions;
else
    options = mergeStruct(defaultOptions, options);
end

% Initialize outputs
results = struct();
figs = struct();

fprintf('=== Fracture Length Prediction Validation ===\n');
fprintf('Measured data: %d, Predicted data: %d\n', length(measured_lengths), length(predicted_lengths));

%% 1. Basic statistics
results.basic_stats.measured_n = length(measured_lengths);
results.basic_stats.predicted_n = length(predicted_lengths);

% Length statistics
results.length_stats.measured_mean = mean(measured_lengths);
results.length_stats.measured_median = median(measured_lengths);
results.length_stats.measured_std = std(measured_lengths);

results.length_stats.predicted_mean = mean(predicted_lengths);
results.length_stats.predicted_median = median(predicted_lengths);
results.length_stats.predicted_std = std(predicted_lengths);

% Aperture statistics
results.aperture_stats.measured_mean = mean(measured_apertures);
results.aperture_stats.measured_median = median(measured_apertures);
results.aperture_stats.measured_std = std(measured_apertures);

%% 2. Distribution consistency test (K-S test)
[results.ks.h, results.ks.p, results.ks.stat] = kstest2(measured_lengths, predicted_lengths);
results.ks.passed = (results.ks.p > options.alpha);

%% 3. Bootstrap confidence interval analysis
boot_meas_mean = bootstrp(options.num_bootstrap, @mean, measured_lengths);
boot_pred_mean = bootstrp(options.num_bootstrap, @mean, predicted_lengths);

results.ci.measured_mean_ci = prctile(boot_meas_mean, [2.5, 97.5]);
results.ci.predicted_mean_ci = prctile(boot_pred_mean, [2.5, 97.5]);
results.ci.overlap = ~(results.ci.measured_mean_ci(2) < results.ci.predicted_mean_ci(1) || ...
                      results.ci.predicted_mean_ci(2) < results.ci.measured_mean_ci(1));

%% 4. Relative error calculation
results.errors.mean_abs_error = mean(abs(predicted_lengths - results.length_stats.measured_mean));
results.errors.mean_rel_error = abs(results.length_stats.predicted_mean - results.length_stats.measured_mean) / ...
                               results.length_stats.measured_mean * 100;
results.errors.median_rel_error = abs(results.length_stats.predicted_median - results.length_stats.measured_median) / ...
                                 results.length_stats.measured_median * 100;

%% 5. Length-aperture relationship analysis
results.relationship.measured_corr = corr(measured_lengths, measured_apertures, 'type', 'Spearman');
results.relationship.measured_slope = polyfit(measured_apertures, measured_lengths, 1);
results.relationship.measured_r2 = corr(measured_apertures, measured_lengths)^2;

%% 6. Quantile comparison
quantiles = [0.1, 0.25, 0.5, 0.75, 0.9];
results.qq.measured_quantiles = quantile(measured_lengths, quantiles);
results.qq.predicted_quantiles = quantile(predicted_lengths, quantiles);
results.qq.quantile_errors = abs(results.qq.predicted_quantiles - results.qq.measured_quantiles) ./ ...
                            results.qq.measured_quantiles * 100;

%% 7. Prediction bias analysis
results.bias.mean_bias = results.length_stats.predicted_mean - results.length_stats.measured_mean;
results.bias.relative_bias = results.bias.mean_bias / results.length_stats.measured_mean * 100;

%% 8. Comprehensive assessment
score_ks = double(results.ks.passed) * 30;
score_ci = double(results.ci.overlap) * 25;
score_error = max(0, 25 - results.errors.mean_rel_error/4);
score_quantile = max(0, 20 - mean(results.qq.quantile_errors)/10);

results.assessment.total_score = score_ks + score_ci + score_error + score_quantile;

if results.assessment.total_score >= 85
    results.assessment.grade = 'Excellent';
elseif results.assessment.total_score >= 70
    results.assessment.grade = 'Good';
elseif results.assessment.total_score >= 50
    results.assessment.grade = 'Fair';
else
    results.assessment.grade = 'Poor';
end

results.assessment.passed = results.assessment.total_score >= 70;
results.assessment.score_breakdown = [score_ks, score_ci, score_error, score_quantile];

%% 9. Generate plots
if options.plot_results
    figs = create_validation_plots(measured_lengths, measured_apertures, predicted_lengths, results, options);
end

%% 10. Display results
display_results(results, options);

fprintf('Validation completed!\n');
end

%% Subfunction: Merge struct
function s = mergeStruct(s1, s2)
    s = s1;
    fields = fieldnames(s2);
    for i = 1:length(fields)
        if isfield(s, fields{i}) && isstruct(s.(fields{i})) && isstruct(s2.(fields{i}))
            s.(fields{i}) = mergeStruct(s.(fields{i}), s2.(fields{i}));
        else
            s.(fields{i}) = s2.(fields{i});
        end
    end
end

%% Subfunction: Create plots
function figs = create_validation_plots(meas_len, meas_apt, pred_len, results, options)
    figs.fig1 = figure('Name', 'Length Prediction Validation', 'Position', [100, 100, 1200, 800]);
    
    % Font settings
    title_font = 16;
    label_font = 12;
    axis_font = 10;
    
    % Plot 1: CDF comparison
    subplot(2,3,1);
    [f_meas, x_meas] = ecdf(meas_len);
    [f_pred, x_pred] = ecdf(pred_len);
    plot(x_meas, f_meas, 'r-', 'LineWidth', 2); hold on;
    plot(x_pred, f_pred, 'b--', 'LineWidth', 2);
    xlabel('Fracture Length (m)', 'FontSize', label_font, 'FontName', 'Times New Roman');
    ylabel('Cumulative Probability', 'FontSize', label_font, 'FontName', 'Times New Roman');
    title('CDF Comparison', 'FontSize', title_font, 'FontName', 'Times New Roman');
    legend('Measured', 'Predicted', 'Location', 'southeast', 'FontSize', 10);
    grid on;
    set(gca, 'FontSize', axis_font, 'FontName', 'Times New Roman');
    
    % Plot 2: PDF comparison
    subplot(2,3,2);
    all_data = [meas_len; pred_len];
    bin_width = (max(all_data)-min(all_data))/20;
    histogram(meas_len, 'BinWidth', bin_width, 'Normalization', 'pdf', ...
              'FaceAlpha', 0.6, 'FaceColor', 'r');
    hold on;
    histogram(pred_len, 'BinWidth', bin_width, 'Normalization', 'pdf', ...
              'FaceAlpha', 0.6, 'FaceColor', 'b');
    xlabel('Fracture Length (m)', 'FontSize', label_font, 'FontName', 'Times New Roman');
    ylabel('Probability Density', 'FontSize', label_font, 'FontName', 'Times New Roman');
    title('PDF Comparison', 'FontSize', title_font, 'FontName', 'Times New Roman');
    legend('Predicted', 'Measured', 'FontSize', 10);
    set(gca, 'FontSize', axis_font, 'FontName', 'Times New Roman');
    
    % Plot 3: Measured length-aperture relationship
    subplot(2,3,3);
    scatter(meas_apt, meas_len, 40, 'r', 'filled');
    h = findobj(gca, 'Type', 'scatter');
    if ~isempty(h)
        set(h, 'MarkerFaceAlpha', 0.6, 'MarkerEdgeAlpha', 0.6);
    end
    
    xlabel('Aperture (mm)', 'FontSize', label_font, 'FontName', 'Times New Roman');
    ylabel('Length (m)', 'FontSize', label_font, 'FontName', 'Times New Roman');
    title('Measured Relationship', 'FontSize', title_font, 'FontName', 'Times New Roman');
    
    p = polyfit(meas_apt, meas_len, 1);
    hold on;
    x_range = [min(meas_apt), max(meas_apt)];
    plot(x_range, polyval(p, x_range), 'k-', 'LineWidth', 2);
    legend('Data', 'Trendline', 'Location', 'northwest', 'FontSize', 8);
    grid on;
    set(gca, 'FontSize', axis_font, 'FontName', 'Times New Roman');
    
    % Plot 4: Quantile comparison
    subplot(2,3,4);
    plot(1:5, results.qq.measured_quantiles, 'ro-', 'LineWidth', 2, 'MarkerSize', 8);
    hold on;
    plot(1:5, results.qq.predicted_quantiles, 'bs--', 'LineWidth', 2, 'MarkerSize', 8);
    xlabel('Quantile', 'FontSize', label_font, 'FontName', 'Times New Roman');
    ylabel('Fracture Length (m)', 'FontSize', label_font, 'FontName', 'Times New Roman');
    set(gca, 'XTick', 1:5, 'XTickLabel', {'P10', 'P25', 'P50', 'P75', 'P90'});
    title('Quantile Comparison', 'FontSize', title_font, 'FontName', 'Times New Roman');
    legend('Measured', 'Predicted', 'Location', 'northwest', 'FontSize', 10);
    grid on;
    set(gca, 'FontSize', axis_font, 'FontName', 'Times New Roman');
    
    % Plot 5: Error analysis
    subplot(2,3,5);
    errors = [results.errors.mean_rel_error, results.errors.median_rel_error, results.bias.relative_bias];
    bar(errors); 
    ylabel('Error (%)', 'FontSize', label_font, 'FontName', 'Times New Roman');
    title('Error Analysis', 'FontSize', title_font, 'FontName', 'Times New Roman');
    set(gca, 'XTickLabel', {'Mean', 'Median', 'Bias'}, 'FontSize', 8);
    grid on;
    for i = 1:length(errors)
        text(i, errors(i)+1, sprintf('%.1f%%', errors(i)), ...
             'HorizontalAlignment', 'center', 'FontWeight', 'bold', 'FontSize', 8);
    end
    set(gca, 'FontSize', axis_font, 'FontName', 'Times New Roman');
    
    % Plot 6: Score
    subplot(2,3,6);
    scores = results.assessment.score_breakdown;
    labels = {'K-S Test', 'CI', 'Error', 'Quantile'};
    pie(scores, labels);
    title(sprintf('Score: %.1f/100\nGrade: %s', results.assessment.total_score, results.assessment.grade), ...
          'FontSize', title_font, 'FontName', 'Times New Roman');
    
    sgtitle('Fracture Length Prediction Validation', 'FontSize', 18, 'FontName', 'Times New Roman', 'FontWeight', 'bold');
end

%% Subfunction: Display results
function display_results(results, options)
    fprintf('\n=== Detailed Results ===\n');
    
    fprintf('\n1. Basic Statistics:\n');
    fprintf('%-15s %12s %12s %12s\n', 'Statistic', 'Measured', 'Predicted', 'Difference');
    fprintf('%-15s %12.3f %12.3f %12.3f\n', 'Mean', ...
            results.length_stats.measured_mean, results.length_stats.predicted_mean, ...
            results.length_stats.predicted_mean - results.length_stats.measured_mean);
    fprintf('%-15s %12.3f %12.3f %12.3f\n', 'Median', ...
            results.length_stats.measured_median, results.length_stats.predicted_median, ...
            results.length_stats.predicted_median - results.length_stats.measured_median);
    fprintf('%-15s %12.3f %12.3f %12.3f\n', 'Std Dev', ...
            results.length_stats.measured_std, results.length_stats.predicted_std, ...
            results.length_stats.predicted_std - results.length_stats.measured_std);
    
    fprintf('\n2. Aperture Statistics (Measured):\n');
    fprintf('Mean: %.3f mm, Median: %.3f mm, Std: %.3f mm\n', ...
            results.aperture_stats.measured_mean, results.aperture_stats.measured_median, ...
            results.aperture_stats.measured_std);
    
    fprintf('\n3. K-S Test (¦Á=%.2f):\n', options.alpha);
    fprintf('p-value: %.4f, Statistic: %.4f\n', results.ks.p, results.ks.stat);
    fprintf('Result: %s\n', ternary(results.ks.passed, 'Pass', 'Fail'));
    
    fprintf('\n4. Confidence Intervals:\n');
    fprintf('Measured Mean 95%% CI: [%.3f, %.3f]\n', results.ci.measured_mean_ci);
    fprintf('Predicted Mean 95%% CI: [%.3f, %.3f]\n', results.ci.predicted_mean_ci);
    fprintf('CI Overlap: %s\n', ternary(results.ci.overlap, 'Yes', 'No'));
    
    fprintf('\n5. Error Analysis:\n');
    fprintf('Mean Relative Error: %.2f%%\n', results.errors.mean_rel_error);
    fprintf('Median Relative Error: %.2f%%\n', results.errors.median_rel_error);
    fprintf('Mean Absolute Error: %.3f m\n', results.errors.mean_abs_error);
    fprintf('Prediction Bias: %.3f m (%.2f%%)\n', results.bias.mean_bias, results.bias.relative_bias);
    
    fprintf('\n6. Length-Aperture Relationship:\n');
    fprintf('Spearman Correlation: ¦Ñ = %.3f\n', results.relationship.measured_corr);
    fprintf('R? = %.3f\n', results.relationship.measured_r2);
    fprintf('Relationship: Length = %.3f ¡Á Aperture + %.3f\n', results.relationship.measured_slope(1), results.relationship.measured_slope(2));
    
    fprintf('\n7. Quantile Errors:\n');
    fprintf('Quantile   Measured   Predicted   Error\n');
    quant_labels = {'P10', 'P25', 'P50', 'P75', 'P90'};
    for i = 1:5
        fprintf('%-8s %9.3f %9.3f %9.1f%%\n', quant_labels{i}, ...
                results.qq.measured_quantiles(i), results.qq.predicted_quantiles(i), ...
                results.qq.quantile_errors(i));
    end
    
    fprintf('\n8. Final Assessment:\n');
    fprintf('K-S Test: %.1f/30, CI: %.1f/25, Error: %.1f/25, Quantile: %.1f/20\n', ...
            results.assessment.score_breakdown);
    fprintf('Total Score: %.1f/100\n', results.assessment.total_score);
    fprintf('Grade: %s\n', results.assessment.grade);
    fprintf('Prediction Accuracy: %s\n', ternary(results.assessment.passed, 'Acceptable', 'Needs Improvement'));
end

%% Helper function
function result = ternary(condition, true_str, false_str)
    if condition
        result = true_str;
    else
        result = false_str;
    end
end