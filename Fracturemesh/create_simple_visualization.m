function create_simple_visualization(V, F, results, quantile_idx)
    % 为单个分位数创建简单的3D可视化
    % 移除了所有图例和注释
    
    % 定义字体设置
    font_name = 'Times New Roman';
    title_fontsize = 28;
    label_fontsize = 26;
    tick_fontsize = 24;
    
    % 分位数颜色定义
    quantile_colors = [...
        0.2 0.4 0.8;   % 35% - 蓝色
        0.0 0.6 0.0;   % 50% - 绿色
        0.9 0.6 0.2;   % 65% - 橙色
        0.9 0.4 0.2;   % 80% - 橙红色
        0.8 0.2 0.2;   % 95% - 红色
    ];
    
    % 获取当前分位数的颜色和名称
    current_color = quantile_colors(quantile_idx, :);
    quantile_name = results.quantile_names{quantile_idx};
    quantile_level = results.quantile_levels(quantile_idx);
    
    % 创建图形
    figure('Position', [100, 100, 1200, 900], ...
           'Name', sprintf('3D Fracture Model - %s Quantile', quantile_name), ...
           'Color', 'white');
    
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
    
    x_limits = [center_x - x_range/2 - padding_x, center_x + x_range/2 + padding_x];
    y_limits = [center_y - y_range/2 - padding_y, center_y + y_range/2 + padding_y];
    z_limits = [center_z - z_range/2 - padding_z, center_z + z_range/2 + padding_z];
    
    % 创建patch对象
    patch('Vertices', V, 'Faces', F, ...
          'FaceColor', current_color, ...
          'FaceAlpha', 0.8, ...
          'EdgeColor', 'none', ...
          'FaceLighting', 'gouraud', ...
          'AmbientStrength', 0.3, ...
          'DiffuseStrength', 0.6, ...
          'SpecularStrength', 0.2);
    
    % 设置轴属性
    axis equal;
    grid off;
    view(45, 30);
    
    % 设置轴限制
    xlim(x_limits);
    ylim(y_limits);
    zlim(z_limits);
    
    % 设置刻度标签
    set(gca, 'FontName', font_name, 'FontSize', tick_fontsize, 'LineWidth', 1.5);
    
    % 添加坐标轴标签
    xlabel('X (m)', 'FontName', font_name, 'FontSize', label_fontsize);
    ylabel('Y (m)', 'FontName', font_name, 'FontSize', label_fontsize);
    zlabel('Z (m)', 'FontName', font_name, 'FontSize', label_fontsize);
    
    % 添加简单的标题
    title(sprintf('3D Fracture Model - %s Quantile (%.0f%%)', ...
                  quantile_name, quantile_level*100), ...
          'FontName', font_name, 'FontSize', title_fontsize, 'FontWeight', 'bold');
    
    % 添加光照
    camlight('headlight');
    lighting gouraud;
    
    drawnow;
end