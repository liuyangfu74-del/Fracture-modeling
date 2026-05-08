function visualize_merged_model_with_probability(merged_model, results)
    % VISUALIZE_MERGED_MODEL_WITH_PROBABILITY - 可视化合并的概率密度模型
    % 输入:
    %   merged_model: 合并的模型结构体
    %   results: MCMC反演结果
    
    fprintf('可视化合并的概率密度模型...\n');
    
    % 字体设置
    font_name = 'Times New Roman';
    title_fontsize = 28;
    label_fontsize = 26;
    tick_fontsize = 24;
    
    % 提取数据
    V = merged_model.vertices;
    F = merged_model.faces;
    vertex_colors = merged_model.vertex_colors;
    probabilities = merged_model.probabilities;
    
    % === 图1: 概率密度编码的3D模型 ===
    figure('Position', [100, 100, 1400, 900], ...
           'Name', '3D Fracture Model - Probability Density', ...
           'Color', 'white');
    
    % 使用概率密度调整透明度：概率越高越不透明
    face_alpha = 0.7 * probabilities;  % 基本透明度为0.7，乘以概率
    
    % 绘制模型，每个面使用顶点颜色插值
    patch('Vertices', V, 'Faces', F, ...
          'FaceVertexCData', vertex_colors, ...  % 顶点颜色
          'FaceColor', 'interp', ...             % 面颜色插值
          'FaceAlpha', 'flat', ...               % 使用每个面的透明度
          'AlphaDataMapping', 'none', ...
          'FaceVertexAlphaData', face_alpha, ... % 顶点透明度
          'EdgeColor', 'none', ...
          'FaceLighting', 'gouraud', ...
          'AmbientStrength', 0.3, ...
          'DiffuseStrength', 0.6, ...
          'SpecularStrength', 0.2);
    
    % 设置轴属性
    axis equal;
    grid off;
    view(45, 30);
    
    % 计算轴限制
    x_range = range(V(:,1));
    y_range = range(V(:,2));
    z_range = range(V(:,3));
    center_x = mean(V(:,1));
    center_y = mean(V(:,2));
    center_z = mean(V(:,3));
    padding_factor = 0.1;
    min_padding = 0.5;
    
    padding_x = max(x_range * padding_factor, min_padding);
    padding_y = max(y_range * padding_factor, min_padding);
    padding_z = max(z_range * padding_factor, min_padding);
    
    xlim([center_x - x_range/2 - padding_x, center_x + x_range/2 + padding_x]);
    ylim([center_y - y_range/2 - padding_y, center_y + y_range/2 + padding_y]);
    zlim([center_z - z_range/2 - padding_z, center_z + z_range/2 + padding_z]);
    
    % 设置刻度
    set(gca, 'FontName', font_name, 'FontSize', tick_fontsize, 'LineWidth', 1.5);
    
    % 坐标轴标签
    xlabel('X (m)', 'FontName', font_name, 'FontSize', label_fontsize);
    ylabel('Y (m)', 'FontName', font_name, 'FontSize', label_fontsize);
    zlabel('Z (m)', 'FontName', font_name, 'FontSize', label_fontsize);
    
    % 标题
    title('3D Fracture Model - Probability Density Encoding', ...
          'FontName', font_name, 'FontSize', title_fontsize, 'FontWeight', 'bold');
    
    % 添加光照
    camlight('headlight');
    lighting gouraud;
    
    % === 图2: 模型切片视图（显示内部结构） ===
    figure('Position', [100, 100, 1400, 900], ...
           'Name', 'Fracture Model - Cross Sections', ...
           'Color', 'white');
    
    % 计算模型边界
    x_min = min(V(:,1)); x_max = max(V(:,1));
    y_min = min(V(:,2)); y_max = max(V(:,2));
    z_min = min(V(:,3)); z_max = max(V(:,3));
    
    % 创建3个子图显示不同切面
    for plot_idx = 1:3
        subplot(1, 3, plot_idx);
        hold on;
        
        switch plot_idx
            case 1  % XY平面切片（Z方向）
                slice_z = linspace(z_min, z_max, 5);
                for i = 1:length(slice_z)
                    z_val = slice_z(i);
                    idx = abs(V(:,3) - z_val) < (z_max - z_min) * 0.02;  % 2%厚度
                    
                    if sum(idx) > 0
                        scatter3(V(idx,1), V(idx,2), V(idx,3), 30, ...
                                vertex_colors(idx,:), 'filled', 'MarkerFaceAlpha', 0.6);
                    end
                end
                view(0, 90);  % 俯视图
                zlabel('Z');
                
            case 2  % XZ平面切片（Y方向）
                slice_y = linspace(y_min, y_max, 5);
                for i = 1:length(slice_y)
                    y_val = slice_y(i);
                    idx = abs(V(:,2) - y_val) < (y_max - y_min) * 0.02;
                    
                    if sum(idx) > 0
                        scatter3(V(idx,1), V(idx,2), V(idx,3), 30, ...
                                vertex_colors(idx,:), 'filled', 'MarkerFaceAlpha', 0.6);
                    end
                end
                view(0, 0);  % 正视图
                ylabel('Y');
                
            case 3  % YZ平面切片（X方向）
                slice_x = linspace(x_min, x_max, 5);
                for i = 1:length(slice_x)
                    x_val = slice_x(i);
                    idx = abs(V(:,1) - x_val) < (x_max - x_min) * 0.02;
                    
                    if sum(idx) > 0
                        scatter3(V(idx,1), V(idx,2), V(idx,3), 30, ...
                                vertex_colors(idx,:), 'filled', 'MarkerFaceAlpha', 0.6);
                    end
                end
                view(90, 0);  % 侧视图
                xlabel('X');
        end
        
        axis equal;
        grid on;
        set(gca, 'FontName', font_name, 'FontSize', tick_fontsize-4, 'LineWidth', 1);
        title(sprintf('Cross Section %d', plot_idx), 'FontName', font_name, 'FontSize', title_fontsize-4);
    end
    
    sgtitle('Fracture Model - Cross Section Views', 'FontName', font_name, 'FontSize', title_fontsize, 'FontWeight', 'bold');
    
    % === 图3: 概率密度图例和统计 ===
    figure('Position', [100, 100, 1200, 800], ...
           'Name', 'Probability Density Legend', ...
           'Color', 'white');
    
    % 创建颜色条
    subplot(2, 1, 1);
    colormap(merged_model.base_colors);
    colorbar('Ticks', [0.1, 0.3, 0.5, 0.7, 0.9], ...
             'TickLabels', merged_model.quantile_names, ...
             'Direction', 'reverse');
    axis off;
    title('Probability Density Color Scale', 'FontName', font_name, 'FontSize', title_fontsize-4);
    
    % 统计信息
    subplot(2, 1, 2);
    axis off;
    
    % 显示统计信息
    stats_text = sprintf('MODEL STATISTICS\n\n');
    stats_text = [stats_text, sprintf('Total Vertices: %d\n', merged_model.stats.n_vertices)];
    stats_text = [stats_text, sprintf('Total Faces: %d\n\n', merged_model.stats.n_faces)];
    
    stats_text = [stats_text, sprintf('VERTEX DISTRIBUTION BY QUANTILE:\n')];
    for q = 1:5
        stats_text = [stats_text, sprintf('  %s: %d (%.1f%%)\n', ...
                     merged_model.quantile_names{q}, ...
                     merged_model.stats.vertex_counts(q), ...
                     merged_model.stats.vertex_distribution(q)*100)];
    end
    
    % 添加模型信息
    stats_text = [stats_text, sprintf('\nMODEL DIMENSIONS:\n')];
    stats_text = [stats_text, sprintf('  X: %.2f - %.2f m\n', x_min, x_max)];
    stats_text = [stats_text, sprintf('  Y: %.2f - %.2f m\n', y_min, y_max)];
    stats_text = [stats_text, sprintf('  Z: %.2f - %.2f m\n', z_min, z_max)];
    
    text(0.1, 0.9, stats_text, 'FontName', font_name, 'FontSize', tick_fontsize-4, ...
         'VerticalAlignment', 'top');
    title('Model Statistics', 'FontName', font_name, 'FontSize', title_fontsize-4);
    
    fprintf('可视化完成: 3个图已生成\n');
end