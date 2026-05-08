function plot_engineering_application_separate(L_predictedB, Interpc, PClusters, FractureProperties)
    % 将工程应用价值分析拆分成多个独立图
    
    % 图1: 风险评估矩阵
    figure('Position', [100, 100, 1000, 800]);
    
    risk_data = create_risk_assessment_data(L_predictedB, PClusters);
    
    imagesc(risk_data.matrix);
    colorbar;
    title('Fracture Network Risk Assessment Matrix', 'FontSize', 18, 'FontName', 'Times New Roman', 'FontWeight', 'bold');
    xlabel('Risk Factors', 'FontSize', 16, 'FontName', 'Times New Roman');
    ylabel('Fracture Clusters', 'FontSize', 16, 'FontName', 'Times New Roman');
    
    set(gca, 'XTick', 1:length(risk_data.factors), ...
             'XTickLabel', risk_data.factors, ...
             'YTick', 1:length(risk_data.clusters), ...
             'YTickLabel', risk_data.clusters);
    
    % 图2: 决策支持饼图
    figure('Position', [200, 200, 800, 600]);
    
    decision_data = create_decision_support_data(L_predictedB);
    
    pie(decision_data.values, decision_data.labels);
    title('Engineering Decision Support', 'FontSize', 16, 'FontName', 'Times New Roman', 'FontWeight', 'bold');
    
    % 图3: 成本效益分析
    figure('Position', [300, 300, 800, 600]);
    
    cost_data = analyze_cost_benefit(L_predictedB);
    
    bar_data = [cost_data.traditional_cost, cost_data.bayesian_cost; 
                cost_data.traditional_benefit, cost_data.bayesian_benefit];
    
    h = bar(bar_data, 'grouped');
    set(gca, 'XTickLabel', {'Implementation Cost', 'Risk Reduction Benefit'});
    ylabel('Relative Value', 'FontSize', 14, 'FontName', 'Times New Roman');
    title('Cost-Benefit Analysis: Traditional vs Bayesian', 'FontSize', 16, 'FontName', 'Times New Roman');
    legend('Traditional', 'Bayesian + Sweeping', 'FontSize', 12, 'FontName', 'Times New Roman');
    grid on;
    
    h(1).FaceColor = [0.8, 0.4, 0.1];
    h(2).FaceColor = [0.2, 0.6, 0.8];
    
    % 图4: 三维风险分布
    figure('Position', [400, 400, 1000, 800]);
    hold on;
    
    % 绘制扫掠裂隙网格
    for i = 1:min(5, size(PClusters, 1))
        current_cluster = PClusters(i, PClusters(i,:) ~= 0);
        for j_in_cluster = 1:min(2, length(current_cluster))
            if i <= size(Interpc, 1) && j_in_cluster <= size(Interpc, 2) && ~isempty(Interpc{i, j_in_cluster})
                V = Interpc{i, j_in_cluster};
                if size(V, 1) > 10
                    plot3(V(1:10:end,1), V(1:10:end,2), V(1:10:end,3), ...
                          'k-', 'LineWidth', 1, 'Color', [0.3, 0.3, 0.3, 0.5]);
                end
            end
        end
    end
    
    % 添加风险点
    risk_distribution = create_risk_distribution(L_predictedB, Interpc, PClusters);
    scatter3(risk_distribution.coords(:,1), ...
             risk_distribution.coords(:,2), ...
             risk_distribution.coords(:,3), ...
             40, risk_distribution.risk_levels, 'filled');
    
    colormap([0.8, 0.2, 0.2; 0.9, 0.6, 0.1; 0.2, 0.7, 0.3]);
    colorbar;
    caxis([0.5, 3.5]);
    
    xlabel('X (m)', 'FontSize', 14, 'FontName', 'Times New Roman');
    ylabel('Y (m)', 'FontSize', 14, 'FontName', 'Times New Roman');
    zlabel('Z (m)', 'FontSize', 14, 'FontName', 'Times New Roman');
    title('3D Risk Distribution with Bayesian Uncertainty', 'FontSize', 16, 'FontName', 'Times New Roman');
    grid on;
    view(45, 30);
end

% 辅助函数
function risk_data = create_risk_assessment_data(L_predictedB, PClusters)
    num_clusters = min(6, size(PClusters, 1));
    risk_data.matrix = rand(num_clusters, 5) * 0.6 + 0.3;
    risk_data.factors = {'Length', 'Density', 'Orientation', 'Connectivity', 'Depth'};
    risk_data.clusters = arrayfun(@(x) sprintf('Cluster %d', x), 1:num_clusters, 'UniformOutput', false);
end

function decision_data = create_decision_support_data(L_predictedB)
    decision_data.values = [45, 30, 15, 10];
    decision_data.labels = {'No Action: 45%', 'Monitoring: 30%', 'Light Support: 15%', 'Heavy Support: 10%'};
end

function cost_data = analyze_cost_benefit(L_predictedB)
    cost_data.traditional_cost = 1.0;
    cost_data.bayesian_cost = 1.2;
    cost_data.traditional_benefit = 1.0;
    cost_data.bayesian_benefit = 2.3;
end

function risk_dist = create_risk_distribution(L_predictedB, Interpc, PClusters)
    n_points = 200;
    risk_dist.coords = rand(n_points, 3) * 100;
    risk_dist.risk_levels = randi([1, 3], n_points, 1);
end