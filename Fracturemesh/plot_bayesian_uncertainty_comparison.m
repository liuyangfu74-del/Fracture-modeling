function plot_bayesian_uncertainty_separate(L_predictedB, L_predicted, H_observed, PClusters)
    % 将贝叶斯不确定性分析拆分成多个独立图
    
    num_clusters = size(PClusters, 1);
    
    % 图1: 各聚类预测对比
    figure('Position', [100, 100, 1000, 800]);
    colors = [0.2, 0.6, 0.8; 0.8, 0.4, 0.1];
    
    valid_clusters = 0;
    for i = 1:num_clusters
        current_cluster = PClusters(i, PClusters(i,:) ~= 0);
        if isempty(current_cluster) || isempty(H_observed{i})
            continue;
        end
        valid_clusters = valid_clusters + 1;
        
        if valid_clusters > 3
            break;
        end
        
        % 为每个聚类创建单独的图
        figure('Position', [200+300*(valid_clusters-1), 100, 800, 600]);
        
        num_fractures_in_cluster = length(H_observed{i});
        L_bayesian = zeros(num_fractures_in_cluster, 1);
        L_ci_low = zeros(num_fractures_in_cluster, 1);
        L_ci_high = zeros(num_fractures_in_cluster, 1);
        L_traditional = zeros(num_fractures_in_cluster, 1);
        
        for j = 1:num_fractures_in_cluster
            if j <= length(L_predictedB{i}.predictions)
                L_bayesian(j) = L_predictedB{i}.predictions(j).stats.mean;
                ci = L_predictedB{i}.predictions(j).stats.ci90;
                L_ci_low(j) = ci(1);
                L_ci_high(j) = ci(2);
            end
            if j <= length(L_predicted{i})
                L_traditional(j) = L_predicted{i}(j);
            end
        end
        
        x_vals = 1:num_fractures_in_cluster;
        
        fill([x_vals, fliplr(x_vals)], ...
             [L_ci_low', fliplr(L_ci_high')], ...
             colors(1,:), 'FaceAlpha', 0.3, 'EdgeColor', 'none');
        hold on;
        
        plot(x_vals, L_bayesian, 'o-', 'Color', colors(1,:), ...
             'LineWidth', 2, 'MarkerSize', 6, 'MarkerFaceColor', colors(1,:));
        
        plot(x_vals, L_traditional, 's--', 'Color', colors(2,:), ...
             'LineWidth', 2, 'MarkerSize', 6, 'MarkerFaceColor', colors(2,:));
        
        xlabel('Fracture Index', 'FontSize', 14, 'FontName', 'Times New Roman');
        ylabel('Trace Length (m)', 'FontSize', 14, 'FontName', 'Times New Roman');
        title(sprintf('Cluster %d: Bayesian vs Traditional Prediction', i), ...
              'FontSize', 16, 'FontName', 'Times New Roman');
        legend('Bayesian 90% CI', 'Bayesian Mean', 'Traditional', ...
               'FontSize', 12, 'FontName', 'Times New Roman');
        grid on;
    end
    
    % 图4: 不确定性统计箱线图
    figure('Position', [100, 100, 800, 600]);
    
    all_uncertainties = [];
    all_traditional_errors = [];
    
    for i = 1:num_clusters
        current_cluster = PClusters(i, PClusters(i,:) ~= 0);
        if isempty(current_cluster) || isempty(H_observed{i})
            continue;
        end
        
        num_fractures_in_cluster = length(H_observed{i});
        for j = 1:num_fractures_in_cluster
            if j <= length(L_predictedB{i}.predictions) && j <= length(L_predicted{i})
                ci = L_predictedB{i}.predictions(j).stats.ci90;
                bayesian_mean = L_predictedB{i}.predictions(j).stats.mean;
                uncertainty = (ci(2) - ci(1)) / bayesian_mean;
                all_uncertainties = [all_uncertainties; uncertainty];
                
                traditional_pred = L_predicted{i}(j);
                traditional_error = abs(traditional_pred - bayesian_mean) / bayesian_mean;
                all_traditional_errors = [all_traditional_errors; traditional_error];
            end
        end
    end
    
    if ~isempty(all_uncertainties)
        box_data = [all_uncertainties*100, all_traditional_errors*100];
        boxplot(box_data, 'Labels', {'Bayesian Uncertainty', 'Traditional Error'});
        ylabel('Relative Value (%)', 'FontSize', 14, 'FontName', 'Times New Roman');
        title('Prediction Uncertainty Comparison', 'FontSize', 16, 'FontName', 'Times New Roman');
        grid on;
    end
end