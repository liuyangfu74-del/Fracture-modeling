function addScaleAndNorthArrow(ax)
% 添加比例尺和指北针到3D图形
    % 获取坐标范围
    xlims = xlim(ax);
    ylims = ylim(ax);
    zlims = zlim(ax);
    
    % 比例尺位置（左下角）
    scale_x = xlims(1) + 0.1 * (xlims(2) - xlims(1));
    scale_y = ylims(1) + 0.1 * (ylims(2) - ylims(1));
    scale_z = zlims(1);
    
    % 绘制比例尺（10米）
    scale_length = 10; % 10米比例尺
    plot3([scale_x, scale_x + scale_length], ...
          [scale_y, scale_y], ...
          [scale_z, scale_z], ...
          'k-', 'LineWidth', 3);
    
    text(scale_x + scale_length/2, scale_y - 2, scale_z, ...
         '10 m', ...
         'FontSize', 10, 'FontName', 'Times New Roman', ...
         'HorizontalAlignment', 'center');
    
    % 指北针位置（右上角）
    north_x = xlims(2) - 0.15 * (xlims(2) - xlims(1));
    north_y = ylims(2) - 0.15 * (ylims(2) - ylims(1));
    
    % 绘制指北针
    plot3([north_x, north_x], ...
          [north_y, north_y + 5], ...
          [scale_z, scale_z], ...
          'k-', 'LineWidth', 2);
    
    text(north_x, north_y + 6, scale_z, 'N', ...
         'FontSize', 12, 'FontName', 'Times New Roman', ...
         'FontWeight', 'bold', 'HorizontalAlignment', 'center');
end