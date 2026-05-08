function create_final_visualization(V, F, predictions, results)
    % CREATE_FINAL_VISUALIZATION_INDIVIDUAL - Create individual figures for visualization
    % Inputs:
    %   V: Vertices matrix (N×3)
    %   F: Faces matrix (M×3)
    %   predictions: Fracture predictions data
    %   results: MCMC inversion results
    
    % Define font settings
    font_name = 'Times New Roman';
    title_fontsize = 28;
    label_fontsize = 26;
    tick_fontsize = 24;
    annotation_fontsize = 22;
    
%% FIGURE 1: 3D Fracture Model
figure('Position', [100, 100, 1400, 900], 'Name', '3D Fracture Model', 'Color', 'white');

% Calculate adaptive axis limits
if isempty(V)
    error('Vertex matrix V is empty');
end

% Get the range of vertex coordinates
x_range = range(V(:,1));
y_range = range(V(:,2));
z_range = range(V(:,3));

% Calculate center of the model
center_x = mean(V(:,1));
center_y = mean(V(:,2));
center_z = mean(V(:,3));

% Determine appropriate padding (5% of model size or fixed value if model is too small)
padding_factor = 0.1;  % 10% padding
min_padding = 0.5;     % Minimum padding in meters (for very small models)

padding_x = max(x_range * padding_factor, min_padding);
padding_y = max(y_range * padding_factor, min_padding);
padding_z = max(z_range * padding_factor, min_padding);

% Calculate axis limits
x_limits = [center_x - x_range/2 - padding_x, center_x + x_range/2 + padding_x];
y_limits = [center_y - y_range/2 - padding_y, center_y + y_range/2 + padding_y];
z_limits = [center_z - z_range/2 - padding_z, center_z + z_range/2 + padding_z];

% Ensure limits are not too small (minimum span)
min_span = 1.0;  % Minimum axis span in meters
if diff(x_limits) < min_span
    x_limits = [center_x - min_span/2, center_x + min_span/2];
end
if diff(y_limits) < min_span
    y_limits = [center_y - min_span/2, center_y + min_span/2];
end
if diff(z_limits) < min_span
    z_limits = [center_z - min_span/2, center_z + min_span/2];
end

% Create patch object for the 3D model
patch('Vertices', V, 'Faces', F, ...
      'FaceColor', [0.7, 0.8, 1.0], ...  % Light blue color
      'FaceAlpha', 0.8, ...
      'EdgeColor', 'none', ...
      'FaceLighting', 'gouraud', ...
      'AmbientStrength', 0.3, ...
      'DiffuseStrength', 0.6, ...
      'SpecularStrength', 0.2);

% Set axis properties BEFORE setting limits
axis equal;
grid on;
grid minor;
view(45, 30);

% Set the calculated axis limits
xlim(x_limits);
ylim(y_limits);
zlim(z_limits);

%% ==== 关键修改：确定是否需要科学计数法并计算缩放因子 ====
% 阈值：当坐标轴范围大于1000或小于0.001时使用科学计数法
use_sci_notation_threshold = 1000;  % 或者可以根据实际情况调整

% 检查每个坐标轴是否需要科学计数法
need_sci_x = max(abs(x_limits)) >= use_sci_notation_threshold;
need_sci_y = max(abs(y_limits)) >= use_sci_notation_threshold;
need_sci_z = max(abs(z_limits)) >= use_sci_notation_threshold;

% 计算缩放因子（10的幂次）
if need_sci_x
    x_exponent = floor(log10(max(abs(x_limits))));
    x_scale_factor = 10^x_exponent;
else
    x_exponent = 0;
    x_scale_factor = 1;
end

if need_sci_y
    y_exponent = floor(log10(max(abs(y_limits))));
    y_scale_factor = 10^y_exponent;
else
    y_exponent = 0;
    y_scale_factor = 1;
end

if need_sci_z
    z_exponent = floor(log10(max(abs(z_limits))));
    z_scale_factor = 10^z_exponent;
else
    z_exponent = 0;
    z_scale_factor = 1;
end

%% ==== 设置刻度标签（简化显示） ====
% 设置每个坐标轴的刻度（5个刻度）
num_ticks = 5;
x_ticks = linspace(x_limits(1), x_limits(2), num_ticks);
y_ticks = linspace(y_limits(1), y_limits(2), num_ticks);
z_ticks = linspace(z_limits(1), z_limits(2), num_ticks);

% 简化刻度标签：直接显示缩放后的值
if need_sci_x
    % X轴需要科学计数法：显示缩放后的值
    scaled_x_ticks = x_ticks / x_scale_factor;
    x_tick_labels = arrayfun(@(x) sprintf('%.2f', x), scaled_x_ticks, 'UniformOutput', false);
else
    % X轴不需要科学计数法：显示原始值，三位有效数字
    x_tick_labels = arrayfun(@(x) format_simple(x, 3), x_ticks, 'UniformOutput', false);
end

if need_sci_y
    % Y轴需要科学计数法：显示缩放后的值
    scaled_y_ticks = y_ticks / y_scale_factor;
    y_tick_labels = arrayfun(@(y) sprintf('%.2f', y), scaled_y_ticks, 'UniformOutput', false);
else
    % Y轴不需要科学计数法：显示原始值，三位有效数字
    y_tick_labels = arrayfun(@(y) format_simple(y, 3), y_ticks, 'UniformOutput', false);
end

if need_sci_z
    % Z轴需要科学计数法：显示缩放后的值
    scaled_z_ticks = z_ticks / z_scale_factor;
    z_tick_labels = arrayfun(@(z) sprintf('%.2f', z), scaled_z_ticks, 'UniformOutput', false);
else
    % Z轴不需要科学计数法：显示原始值，三位有效数字
    z_tick_labels = arrayfun(@(z) format_simple(z, 3), z_ticks, 'UniformOutput', false);
end

% 应用刻度标签
ax = gca;
ax.XTick = x_ticks;
ax.YTick = y_ticks;
ax.ZTick = z_ticks;
ax.XTickLabel = x_tick_labels;
ax.YTickLabel = y_tick_labels;
ax.ZTickLabel = z_tick_labels;

%% ==== 设置坐标轴标题（包含科学计数法） ====
% 构建坐标轴标签
if need_sci_x
    x_label_str = sprintf('X (m) \\times 10^{%d}', x_exponent);
else
    x_label_str = 'X (m)';
end

if need_sci_y
    y_label_str = sprintf('Y (m) \\times 10^{%d}', y_exponent);
else
    y_label_str = 'Y (m)';
end

if need_sci_z
    z_label_str = sprintf('Z (m) \\times 10^{%d}', z_exponent);
else
    z_label_str = 'Z (m)';
end

% 添加坐标轴标签
xlabel(x_label_str, 'FontName', font_name, 'FontSize', label_fontsize);
ylabel(y_label_str, 'FontName', font_name, 'FontSize', label_fontsize);
zlabel(z_label_str, 'FontName', font_name, 'FontSize', label_fontsize);

% Add title
title('3D Fracture network model', ...
      'FontName', font_name, 'FontSize', title_fontsize, 'FontWeight', 'bold');

% Set tick font properties
ax.FontName = font_name;
ax.FontSize = tick_fontsize;
ax.LineWidth = 1.5;

% Add lighting for better 3D visualization
camlight('headlight');
lighting gouraud;

% Update model statistics annotation with proper formatting
if need_sci_x || need_sci_y || need_sci_z
    model_stats_text = sprintf(['Model Dimensions:\n']);
    
    if need_sci_x
        model_stats_text = [model_stats_text, ...
            sprintf('X: %.2f - %.2f \\times 10^{%d} m\n', ...
                    x_limits(1)/x_scale_factor, x_limits(2)/x_scale_factor, x_exponent)];
    else
        model_stats_text = [model_stats_text, ...
            sprintf('X: %s - %s m\n', ...
                    format_simple(x_limits(1), 3), format_simple(x_limits(2), 3))];
    end
    
    if need_sci_y
        model_stats_text = [model_stats_text, ...
            sprintf('Y: %.2f - %.2f \\times 10^{%d} m\n', ...
                    y_limits(1)/y_scale_factor, y_limits(2)/y_scale_factor, y_exponent)];
    else
        model_stats_text = [model_stats_text, ...
            sprintf('Y: %s - %s m\n', ...
                    format_simple(y_limits(1), 3), format_simple(y_limits(2), 3))];
    end
    
    if need_sci_z
        model_stats_text = [model_stats_text, ...
            sprintf('Z: %.2f - %.2f \\times 10^{%d} m\n\n', ...
                    z_limits(1)/z_scale_factor, z_limits(2)/z_scale_factor, z_exponent)];
    else
        model_stats_text = [model_stats_text, ...
            sprintf('Z: %s - %s m\n\n', ...
                    format_simple(z_limits(1), 3), format_simple(z_limits(2), 3))];
    end
    
    model_stats_text = [model_stats_text, ...
        sprintf('Vertices: %d\nFaces: %d', size(V,1), size(F,1))];
else
    model_stats_text = sprintf(['Model Dimensions:\n' ...
                                'X: %s - %s m\n' ...
                                'Y: %s - %s m\n' ...
                                'Z: %s - %s m\n\n' ...
                                'Vertices: %d\nFaces: %d'], ...
                               format_simple(x_limits(1), 3), ...
                               format_simple(x_limits(2), 3), ...
                               format_simple(y_limits(1), 3), ...
                               format_simple(y_limits(2), 3), ...
                               format_simple(z_limits(1), 3), ...
                               format_simple(z_limits(2), 3), ...
                               size(V,1), size(F,1));
end

grid off
% Force update of the display
drawnow;


    
    %% FIGURE 2: Posterior Parameter Distribution
    figure('Position', [100, 100, 1000, 800], 'Name', 'Posterior Parameters', 'Color', 'white');
    
    % Extract parameters
    param_names = {'\eta', '\beta_I', '\beta_{II}'};
    param_values = [results.params_mean.eta, ...
                    results.params_mean.beta_I, ...
                    results.params_mean.beta_II];
    
    % Create bar plot
    bar_handle = bar(param_values, 'FaceColor', [0.2, 0.4, 0.8], ...
                     'EdgeColor', 'none', 'BarWidth', 0.6);
    
    % Set axis properties
    set(gca, 'XTickLabel', param_names, ...
             'FontName', font_name, ...
             'FontSize', tick_fontsize, ...
             'LineWidth', 1.5);
    
    grid on;
    grid minor;
    
    % Add labels
    ylabel('Parameter Value', 'FontName', font_name, 'FontSize', label_fontsize);
    
    % Add title
    title('Posterior Parameter Estimates', ...
          'FontName', font_name, 'FontSize', title_fontsize, 'FontWeight', 'bold');
    
    % Add value labels on top of bars
    for i = 1:length(param_values)
        text(i, param_values(i) + 0.02*max(param_values), ...
             sprintf('%.3f', param_values(i)), ...
             'HorizontalAlignment', 'center', ...
             'VerticalAlignment', 'bottom', ...
             'FontName', font_name, ...
             'FontSize', tick_fontsize-2, ...
             'FontWeight', 'bold');
    end
    
    % Adjust y-axis limits
    y_limits = ylim;
    ylim([0, y_limits(2)*1.1]);
    
    % Add theoretical range lines for beta parameters
    hold on;
    
    % Theoretical range for β_I (0.5-1.0)
    line([1.5, 2.5], [0.5, 0.5], 'Color', 'r', 'LineStyle', '--', 'LineWidth', 2);
    line([1.5, 2.5], [1.0, 1.0], 'Color', 'r', 'LineStyle', '--', 'LineWidth', 2);
    
    % Theoretical range for β_II (0.3-0.7)
    line([2.5, 3.5], [0.3, 0.3], 'Color', 'g', 'LineStyle', '--', 'LineWidth', 2);
    line([2.5, 3.5], [0.7, 0.7], 'Color', 'g', 'LineStyle', '--', 'LineWidth', 2);
    
    % Add legend for theoretical ranges
    legend_handles = [bar_handle, ...
                      plot(NaN, NaN, 'r--', 'LineWidth', 2), ...
                      plot(NaN, NaN, 'g--', 'LineWidth', 2)];
    
    legend(legend_handles, {'Estimated', '\beta_I Range [0.5,1.0]', '\beta_{II} Range [0.3,0.7]'}, ...
           'Location', 'northwest', ...
           'FontName', font_name, ...
           'FontSize', annotation_fontsize);
    
    %% FIGURE 3: Model Performance Metrics
    figure('Position', [100, 100, 1000, 800], 'Name', 'Model Performance', 'Color', 'white');
    
    % Extract performance metrics
    metric_names = {'R^2', 'RMSE (m)', '90% CI Coverage'};
    metric_values = [results.performance.R2, ...
                     results.performance.RMSE, ...
                     results.performance.ci90_coverage/100];
    
    % Create bar plot for performance metrics
    bar_handle2 = bar(metric_values, 'FaceColor', [0.8, 0.2, 0.2], ...
                      'EdgeColor', 'none', 'BarWidth', 0.6);
    
    % Set axis properties
    set(gca, 'XTickLabel', metric_names, ...
             'FontName', font_name, ...
             'FontSize', tick_fontsize, ...
             'LineWidth', 1.5);
    
    grid on;
    grid minor;
    
    % Add labels
    ylabel('Metric Value', 'FontName', font_name, 'FontSize', label_fontsize);
    
    % Add title
    title('Model Performance Evaluation', ...
          'FontName', font_name, 'FontSize', title_fontsize, 'FontWeight', 'bold');
    
    % Add value labels on top of bars
    for i = 1:length(metric_values)
        if i == 1
            label_text = sprintf('%.3f', metric_values(i));
        elseif i == 2
            label_text = sprintf('%.3f', metric_values(i));
        else
            label_text = sprintf('%.1f%%', metric_values(i)*100);
        end
        
        text(i, metric_values(i) + 0.02, label_text, ...
             'HorizontalAlignment', 'center', ...
             'VerticalAlignment', 'bottom', ...
             'FontName', font_name, ...
             'FontSize', tick_fontsize-2, ...
             'FontWeight', 'bold');
    end
    
    % Adjust y-axis limits
    ylim([0, max(metric_values)*1.2]);
    
    % Add performance classification
    if results.performance.R2 > 0.7
        performance_level = 'EXCELLENT';
        level_color = [0, 0.6, 0];
    elseif results.performance.R2 > 0.5
        performance_level = 'GOOD';
        level_color = [0, 0.8, 0];
    elseif results.performance.R2 > 0.3
        performance_level = 'FAIR';
        level_color = [1, 0.5, 0];
    else
        performance_level = 'POOR';
        level_color = [0.8, 0, 0];
    end
    
    % Add performance annotation
    annotation_text = sprintf('Performance Level: %s\n(R^2 = %.3f)', ...
                              performance_level, results.performance.R2);
    
    annotation('textbox', [0.15, 0.75, 0.3, 0.1], ...
               'String', annotation_text, ...
               'FontName', font_name, ...
               'FontSize', annotation_fontsize, ...
               'FontWeight', 'bold', ...
               'Color', level_color, ...
               'BackgroundColor', [1, 1, 1, 0.9], ...
               'EdgeColor', level_color, ...
               'LineWidth', 2);
    
    %% FIGURE 4: Uncertainty Visualization
    figure('Position', [100, 100, 1200, 800], 'Name', 'Prediction Uncertainty', 'Color', 'white');
    
    % Check if validation predictions exist
    if isfield(results, 'validation_predictions')
        L_val = results.validation_predictions.L_val;
        L_pred = results.validation_predictions.L_pred_median;
        L_ci90 = results.validation_predictions.L_pred_ci90;
        
        % Sort by predicted length for better visualization
        [L_pred_sorted, sort_idx] = sort(L_pred);
        L_val_sorted = L_val(sort_idx);
        L_ci90_sorted = L_ci90(sort_idx, :);
        
        % Create uncertainty plot
        hold on;
        
        % Fill area for 90% confidence interval
        x_fill = [1:length(L_pred_sorted), length(L_pred_sorted):-1:1];
        y_fill = [L_ci90_sorted(:,1); flipud(L_ci90_sorted(:,2))];
        fill_handle = fill(x_fill, y_fill, [0.8, 0.9, 1.0], ...
                           'EdgeColor', 'none', ...
                           'FaceAlpha', 0.5, ...
                           'DisplayName', '90% Confidence Interval');
        
        % Plot median predictions
        pred_handle = plot(L_pred_sorted, 'b-', 'LineWidth', 3, ...
                           'DisplayName', 'Median Prediction');
        
        % Plot true values
        true_handle = scatter(1:length(L_val_sorted), L_val_sorted, 80, ...
                              'r', 'filled', 'MarkerEdgeColor', 'k', ...
                              'LineWidth', 1.5, ...
                              'DisplayName', 'True Values');
        
        % Set axis properties
        set(gca, 'FontName', font_name, ...
                 'FontSize', tick_fontsize, ...
                 'LineWidth', 1.5);
        
        grid on;
        grid minor;
        
        % Add labels
        xlabel('Sample Index (Sorted by Prediction)', ...
               'FontName', font_name, 'FontSize', label_fontsize);
        ylabel('Trace Length (m)', ...
               'FontName', font_name, 'FontSize', label_fontsize);
        
        % Add title
        title('Prediction Uncertainty with 90% Confidence Intervals', ...
              'FontName', font_name, 'FontSize', title_fontsize, 'FontWeight', 'bold');
        
        % Add legend
        legend([true_handle, pred_handle, fill_handle], ...
               'Location', 'northwest', ...
               'FontName', font_name, ...
               'FontSize', annotation_fontsize);
        
        % Add coverage information
        coverage_text = sprintf('Coverage: %.1f%%', results.performance.ci90_coverage);
        
        annotation('textbox', [0.7, 0.8, 0.2, 0.1], ...
                   'String', coverage_text, ...
                   'FontName', font_name, ...
                   'FontSize', annotation_fontsize, ...
                   'FontWeight', 'bold', ...
                   'BackgroundColor', [1, 1, 1, 0.9], ...
                   'EdgeColor', 'blue', ...
                   'LineWidth', 2);
    end
    
    %% FIGURE 5: Model Summary Statistics
    figure('Position', [100, 100, 900, 700], 'Name', 'Model Summary', 'Color', 'white');
    
    % Create text display for summary statistics
    axis off;
    
    % Title
    text(0.1, 0.95, 'FRACTURE MODELING SYSTEM - SUMMARY', ...
         'FontName', font_name, ...
         'FontSize', title_fontsize, ...
         'FontWeight', 'bold', ...
         'Color', [0, 0, 0.6]);
    
    % Section 1: Inversion Parameters
    text(0.1, 0.85, 'INVERSION PARAMETERS:', ...
         'FontName', font_name, ...
         'FontSize', label_fontsize, ...
         'FontWeight', 'bold');
    
    param_text = {sprintf('\\eta = %.3f', results.params_mean.eta), ...
                  sprintf('\\alpha_I = %.4f', results.params_mean.alpha_I), ...
                  sprintf('\\beta_I = %.3f', results.params_mean.beta_I), ...
                  sprintf('\\alpha_{II} = %.4f', results.params_mean.alpha_II), ...
                  sprintf('\\beta_{II} = %.3f', results.params_mean.beta_II), ...
                  sprintf('\\sigma = %.4f', results.params_mean.sigma)};
    
    for i = 1:length(param_text)
        text(0.15, 0.78 - (i-1)*0.05, param_text{i}, ...
             'FontName', font_name, ...
             'FontSize', annotation_fontsize);
    end
    
    % Section 2: Performance Metrics
    text(0.1, 0.55, 'PERFORMANCE METRICS:', ...
         'FontName', font_name, ...
         'FontSize', label_fontsize, ...
         'FontWeight', 'bold');
    
    perf_text = {sprintf('R^2 = %.3f', results.performance.R2), ...
                 sprintf('RMSE = %.3f m', results.performance.RMSE), ...
                 sprintf('MAE = %.3f m', results.performance.MAE), ...
                 sprintf('MAPE = %.1f%%', results.performance.MAPE), ...
                 sprintf('90%% CI Coverage = %.1f%%', results.performance.ci90_coverage)};
    
    for i = 1:length(perf_text)
        text(0.15, 0.48 - (i-1)*0.05, perf_text{i}, ...
             'FontName', font_name, ...
             'FontSize', annotation_fontsize);
    end
    
    % Section 3: Model Statistics
    text(0.1, 0.25, 'MODEL STATISTICS:', ...
         'FontName', font_name, ...
         'FontSize', label_fontsize, ...
         'FontWeight', 'bold');
    
    model_text = {sprintf('Fractures: %d', length(predictions)), ...
                  sprintf('Vertices: %d', size(V,1)), ...
                  sprintf('Faces: %d', size(F,1)), ...
                  sprintf('Volume: %.3f m^3', calculate_mesh_volume(V, F)), ...
                  sprintf('Surface Area: %.3f m^2', calculate_mesh_area(V, F))};
    
    for i = 1:length(model_text)
        text(0.15, 0.18 - (i-1)*0.05, model_text{i}, ...
             'FontName', font_name, ...
             'FontSize', annotation_fontsize);
    end
    
    % Add timestamp
    timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');
    text(0.1, 0.02, ['Generated: ' timestamp], ...
         'FontName', font_name, ...
         'FontSize', annotation_fontsize-2, ...
         'Color', [0.5, 0.5, 0.5]);
    
    fprintf('Visualization completed: 5 individual figures generated\n');
end

%% Helper functions for volume and area calculation
function volume = calculate_mesh_volume(V, F)
    % Simplified volume calculation for triangular mesh
    volume = 0;
    for i = 1:size(F, 1)
        % Get triangle vertices
        v1 = V(F(i, 1), :);
        v2 = V(F(i, 2), :);
        v3 = V(F(i, 3), :);
        
        % Calculate signed volume of tetrahedron with origin
        volume = volume + abs(det([v1; v2; v3])) / 6;
    end
end

function area = calculate_mesh_area(V, F)
    % Calculate total surface area of triangular mesh
    area = 0;
    for i = 1:size(F, 1)
        % Get triangle vertices
        v1 = V(F(i, 1), :);
        v2 = V(F(i, 2), :);
        v3 = V(F(i, 3), :);
        
        % Calculate triangle area using cross product
        a = v2 - v1;
        b = v3 - v1;
        triangle_area = 0.5 * norm(cross(a, b));
        area = area + triangle_area;
    end
end
%% 辅助函数：简单格式化（三位有效数字）
function str = format_simple(value, sig_figs)
    % 简化版格式化，不包含科学计数法
    if nargin < 2
        sig_figs = 3;
    end
    
    if isnan(value) || isinf(value) || value == 0
        str = sprintf('%.0f', value);
        return;
    end
    
    abs_value = abs(value);
    
    % 根据数值大小确定格式
    if abs_value >= 1000
        % 大数字：取整
        str = sprintf('%.0f', value);
    elseif abs_value >= 100
        % 100-1000：0位小数
        str = sprintf('%.0f', value);
    elseif abs_value >= 10
        % 10-100：1位小数
        str = sprintf('%.1f', value);
    elseif abs_value >= 1
        % 1-10：2位小数
        str = sprintf('%.2f', value);
    elseif abs_value >= 0.1
        % 0.1-1：3位小数
        str = sprintf('%.3f', value);
    elseif abs_value >= 0.01
        % 0.01-0.1：4位小数
        str = sprintf('%.4f', value);
    else
        % 小于0.01：5位小数
        str = sprintf('%.5f', value);
    end
    
    % 移除不必要的末尾零
    if contains(str, '.')
        str = regexprep(str, '0+$', '');
        str = regexprep(str, '\.$', '');
    end
end