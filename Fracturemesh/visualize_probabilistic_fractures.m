function visualize_probabilistic_fractures(all_models, all_predictions, results)
    % 可视化不同分位数的裂隙面
    
    figure('Position', [100, 100, 1400, 600], 'Name', '概率裂隙面模型');
    
    % 颜色映射（5种分位数对应5种颜色）
    colors = [...
        0.2 0.4 0.8;   % 35% - 深蓝（保守）
        0.0 0.6 0.0;   % 50% - 绿色（最可能）
        0.9 0.6 0.2;   % 65% - 橙色（较可能）
        0.9 0.4 0.2;   % 80% - 橙红（较乐观）
        0.8 0.2 0.2;   % 95% - 红色（乐观）
    ];
    
    for cluster_idx = 1:min(2, length(all_models))  % 显示前两个聚类
        cluster_models = all_models{cluster_idx};
        
        for f_idx = 1:min(3, length(cluster_models))  % 每个聚类显示前3条裂隙
            model = cluster_models{f_idx};
            if isempty(model) || ~isfield(model, 'vertices') || isempty(model.vertices)
                continue;
            end
            
            subplot(2, 3, (cluster_idx-1)*3 + f_idx);
            hold on;
            grid on;
            axis equal;
            xlabel('X'); ylabel('Y'); zlabel('Z');
            title(sprintf('裂隙 %d - 三维模型', all_predictions{cluster_idx}.fracture_ids(f_idx)));
            
            % === 第1处修改：绘制三维模型 ===
            if isfield(model, 'faces') && ~isempty(model.faces) && ...
               isfield(model, 'vertices') && ~isempty(model.vertices)
                
                % 绘制三维网格
                trisurf(model.faces, ...
                    model.vertices(:,1), model.vertices(:,2), model.vertices(:,3), ...
                    'FaceColor', colors(2,:), 'FaceAlpha', 0.6, 'EdgeColor', 'none');
                
                % 如果有上下表面，分开显示
                if isfield(model, 'upper_surface') && ~isempty(model.upper_surface)
                    % 可以额外显示上下表面
                end
            end
            
            % === 第2处修改：简化显示分位数信息 ===
            if isfield(model, 'L_quantiles') && ~isempty(model.L_quantiles)
                L_quantiles = model.L_quantiles(1, :);  % 取第一个开度点的迹长预测
                
                % 在图上添加文本说明
                text_x = mean(model.vertices(:,1));
                text_y = mean(model.vertices(:,2));
                text_z = max(model.vertices(:,3)) + 0.1;
                
                info_str = sprintf('迹长预测:\n');
                for q = 1:length(L_quantiles)
                    info_str = sprintf('%s%.0f%%: %.2fm\n', info_str, ...
                        results.quantile_levels(q)*100, L_quantiles(q));
                end
                
                text(text_x, text_y, text_z, info_str, ...
                    'FontSize', 8, 'BackgroundColor', 'white', ...
                    'VerticalAlignment', 'bottom');
            end
            
            % 绘制中心线（可选）
            if isfield(model, 'centerline') && ~isempty(model.centerline)
                plot3(model.centerline(:,1), model.centerline(:,2), model.centerline(:,3), ...
                    'r-', 'LineWidth', 1, 'DisplayName', '中心线');
            end
            
            hold off;
        end
    end
    
    % === 第3处修改：添加总图例 ===
    subplot(2, 3, 6);
    axis off;
    hold on;
    
    % 创建示例图例项
    legend_items = {};
    for q = 1:length(results.quantile_levels)
        % 创建颜色方块
        rectangle('Position', [0.1, 0.8-0.15*q, 0.1, 0.1], ...
                 'FaceColor', colors(q,:), 'EdgeColor', 'k');
        
        % 添加文本
        text(0.25, 0.85-0.15*q, ...
            sprintf('%s (%.0f%%)', results.quantile_names{q}, results.quantile_levels(q)*100), ...
            'FontSize', 10, 'VerticalAlignment', 'middle');
        
        legend_items{end+1} = sprintf('%s (%.0f%%)', ...
            results.quantile_names{q}, results.quantile_levels(q)*100);
    end
    
    % 添加模型颜色说明
    rectangle('Position', [0.1, 0.2, 0.1, 0.1], ...
             'FaceColor', colors(2,:), 'FaceAlpha', 0.6, 'EdgeColor', 'k');
    text(0.25, 0.25, '三维裂隙模型 (50%分位数)', ...
        'FontSize', 10, 'VerticalAlignment', 'middle');
    
    title('图例说明');
    xlim([0, 1]); ylim([0, 1]);
    hold off;
end