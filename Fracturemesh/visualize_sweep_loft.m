function visualize_sweep_loft(centerLine, V, F, upper_surface, lower_surface)
% VISUALIZE_SWEEP_LOFT 可视化扫掠生成的裂隙面，包括中心线
% 
% 输入:
%   centerLine - 中心线点集 (N×3)
%   V - 网格顶点矩阵
%   F - 三角面片索引矩阵
%   upper_surface - 上表面点集
%   lower_surface - 下表面点集

    % 创建图形窗口
%     figure('Position', [100, 100, 1200, 800]);
    figure
    % 绘制裂隙面网格（半透明）
    patch('Faces', F, 'Vertices', V, ...
          'FaceColor', [0.8, 0.8, 1.0], ...
          'EdgeColor', 'none', ...
          'FaceAlpha', 0.7, ...
          'DisplayName', '裂隙面网格');
    
    hold on;
    
    % 绘制中心线（红色粗线）
    plot3(centerLine(:,1), centerLine(:,2), centerLine(:,3), ...
          'r-', 'LineWidth', 3, 'DisplayName', '中心线');
    
    % 绘制中心线上的点（黑色圆点）
    plot3(centerLine(:,1), centerLine(:,2), centerLine(:,3), ...
          'ko', 'MarkerSize', 8, 'MarkerFaceColor', 'k', ...
          'DisplayName', '中心点');
    
    % 绘制上表面轮廓（蓝色点）
    if ~isempty(upper_surface)
        plot3(upper_surface(:,1), upper_surface(:,2), upper_surface(:,3), ...
              'b.', 'MarkerSize', 10, 'DisplayName', '上表面点');
    end
    
    % 绘制下表面轮廓（绿色点）
    if ~isempty(lower_surface)
        plot3(lower_surface(:,1), lower_surface(:,2), lower_surface(:,3), ...
              'g.', 'MarkerSize', 10, 'DisplayName', '下表面点');
    end
    
    % 绘制深度方向指示（在每个中心点处画法向箭头）
%     for i = 1:min(5, size(centerLine, 1))  % 只画前5个点作为示意
%         idx = round(i * size(centerLine, 1) / 5);
%         if idx > 0 && idx <= size(centerLine, 1)
%             % 计算该点的切向和法向
%             if idx == 1
%                 tangent = centerLine(2, :) - centerLine(1, :);
%             elseif idx == size(centerLine, 1)
%                 tangent = centerLine(end, :) - centerLine(end-1, :);
%             else
%                 tangent = centerLine(idx+1, :) - centerLine(idx-1, :);
%             end
%             tangent = tangent / norm(tangent);
%             
%             % 法向量需要从外部传入，这里用n_in的近似
%             % 假设n_in大致是全局z方向或自定义方向
%             n_in_approx = [0, 0, 1];  % 可以根据实际情况修改
%             
%             % 绘制法向箭头（深度方向）
%             quiver3(centerLine(idx,1), centerLine(idx,2), centerLine(idx,3), ...
%                     n_in_approx(1), n_in_approx(2), n_in_approx(3), 0.5, ...
%                     'Color', [0.5, 0, 0.5], 'LineWidth', 2, 'MaxHeadSize', 0.3);
%         end
%     end
    
    % 设置图形属性
%     xlabel('X', 'FontSize', 12);
%     ylabel('Y', 'FontSize', 12);
%     zlabel('Z', 'FontSize', 12);
%     title('裂隙面扫掠建模可视化', 'FontSize', 14, 'FontWeight', 'bold');
    
%     % 添加图例
%     legend('Location', 'best', 'FontSize', 10);
    % 设置视角为三维
    view(3)
    % 添加网格
    grid on;
    grid minor;
    
    % 使坐标轴比例相等
    axis equal;
    
    % 添加光照效果
    light('Position', [1, 1, 1], 'Style', 'infinite');
    lighting gouraud;
    
    hold off;
    grid off
    axis off;
    view([-1, -0.3, 0.3])
end

% 使用示例脚本
function demo_sweep_loft()
    % 生成示例中心线（一条弯曲的线）
    t = linspace(0, 2*pi, 20)';
    centerLine = [t, sin(t), cos(t)] * 2;
    
    % 设置参数
    N = size(centerLine, 1);
    seg_idx = ones(N, 1);  % 所有点属于同一个分段
    start_width = 1.0;     % 初始宽度
    seg_depth = 3.0;       % 深度
    n_in = [0, 0, 1];      % 法向（深度方向）
    densityTarget = 10;    % 网格密度
    
    % 调用主函数生成网格
    [V, F, upper_surface, lower_surface] = sweep_loft_mesh_variable(...
        centerLine, seg_idx, start_width, seg_depth, n_in, densityTarget);
    
    % 可视化结果
    visualize_sweep_loft(centerLine, V, F, upper_surface, lower_surface);
end

% 更复杂的示例：多个分段，不同宽度
function demo_multi_segment()
    % 生成中心线（直线）
    z = linspace(0, 10, 30)';
    centerLine = [zeros(size(z)), zeros(size(z)), z];
    
    % 分段：前10个点为分段1，中间10个点为分段2，后10个点为分段3
    N = size(centerLine, 1);
    seg_idx = [ones(10,1); 2*ones(10,1); 3*ones(10,1)];
    
    % 每个分段的初始宽度不同
    start_width = [1.5, 1.0, 0.5];
    
    % 每个分段的深度不同
    seg_depth = [2.0, 1.5, 1.0];
    
    % 法向（水平方向）
    n_in = [1, 0, 0];
    
    densityTarget = 15;
    
    % 生成网格
    [V, F, upper_surface, lower_surface] = sweep_loft_mesh_variable(...
        centerLine, seg_idx, start_width, seg_depth, n_in, densityTarget);
    
    % 可视化
    visualize_sweep_loft(centerLine, V, F, upper_surface, lower_surface);
    
    % 添加标题说明分段
    title('多分段裂隙面（不同颜色表示不同分段）', 'FontSize', 14, 'FontWeight', 'bold');
    
    % 用颜色标记分段
    hold on;
    colors = ['r', 'g', 'b'];
    unique_segs = unique(seg_idx);
    for k = 1:length(unique_segs)
        seg_k = unique_segs(k);
        idx_k = find(seg_idx == seg_k);
        if ~isempty(idx_k)
            plot3(centerLine(idx_k,1), centerLine(idx_k,2), centerLine(idx_k,3), ...
                  [colors(k), 'o-'], 'LineWidth', 2, 'MarkerSize', 8, ...
                  'MarkerFaceColor', colors(k), ...
                  'DisplayName', sprintf('分段 %d (宽度=%.1f)', seg_k, start_width(k)));
        end
    end
    hold off;
end