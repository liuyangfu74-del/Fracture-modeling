function visualize_7models_overlap(combined_meshes, ~)
    % 字体设置 (均减小5个字号)
    font_name = 'Times New Roman';
    title_fontsize = 22; % 原30
    label_fontsize = 22; % 原28
    tick_fontsize = 21;  % 原26
    
    model_indices = [1, 6, 7];
    model_names = {'95% lower confidence', '95% upper confidence', 'Maximum probability density'};
    model_colors = [
        0.0, 0.8, 0.8;
        0.0, 0.6, 0.8;
        1.0, 0.0, 0.0;
    ];
    
    % 收集所有顶点用于统一坐标范围
    all_vertices = [];
    for i = 1:3
        idx = model_indices(i);
        if ~isempty(combined_meshes{idx}) && ~isempty(combined_meshes{idx}.V)
            all_vertices = [all_vertices; combined_meshes{idx}.V];
        end
    end
    
    if isempty(all_vertices)
        error('No valid model data');
    end
    
    % 计算边界框和边距
    bbox_min = min(all_vertices, [], 1);
    bbox_max = max(all_vertices, [], 1);
    padding = max(bbox_max - bbox_min) * 0.1;
    if padding == 0, padding = 0.5; end
    
    % === 只生成第三组图：统计信息对比图 (横排3个子图) ===
    figure('Position', [100, 100, 1200, 500], 'Color', 'white');
    
    for i = 1:3
        idx = model_indices(i);
        model_name = model_names{i};
        color = model_colors(i, :);
        
        % 横排布局：subplot(1, 3, i)
        subplot(1, 3, i);
        
        if ~isempty(combined_meshes{idx}) && ~isempty(combined_meshes{idx}.V)
            V = combined_meshes{idx}.V;
            
            % 绘制模型散点图
            scatter3(V(:,1), V(:,2), V(:,3), ...
                    5, color, 'filled', 'MarkerFaceAlpha', 0.6);
            
            axis equal;
            grid off;
            view(45, 30);
            
            xlim([bbox_min(1)-padding, bbox_max(1)+padding]);
            ylim([bbox_min(2)-padding, bbox_max(2)+padding]);
            zlim([bbox_min(3)-padding, bbox_max(3)+padding]);
            
            set(gca, 'FontName', font_name, 'FontSize', tick_fontsize-6, 'LineWidth', 1);
            title(model_name, 'FontName', font_name, ...
                  'FontSize', title_fontsize-6, 'FontWeight', 'bold', 'Color', color);
            
            % 添加坐标轴标签
            xlabel('X (m)', 'FontName', font_name, 'FontSize', label_fontsize-6);
            ylabel('Y (m)', 'FontName', font_name, 'FontSize', label_fontsize-6);
            zlabel('Z (m)', 'FontName', font_name, 'FontSize', label_fontsize-6);
        end
    end
end