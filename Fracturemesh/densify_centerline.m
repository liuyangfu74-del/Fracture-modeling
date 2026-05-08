function dense_centerline = densify_centerline(centerline, min_points_per_meter)
    % SEGMENT_DENSIFY_CENTERLINE 分段加密中心线
    % 在每个线段间独立插值，确保每段都满足密度要求
    
    if nargin < 2
        min_points_per_meter = 10;
    end
    
    n_points = size(centerline, 1);
    all_segments = cell(n_points - 1, 1);
    
    % 处理每一段
    for i = 1:n_points - 1
        p1 = centerline(i, :);
        p2 = centerline(i + 1, :);
        
        % 计算这段的长度
        segment_length = norm(p2 - p1);
        
        % 计算这段需要插入的点数
        if segment_length == 0
            points_in_segment = p1;
        else
            n_insert = max(2, ceil(segment_length * min_points_per_meter) + 1);
            t = linspace(0, 1, n_insert)';
            points_in_segment = (1 - t) * p1 + t * p2;
        end
        
        % 如果是第一段，保留所有点；否则去掉第一个点（避免重复）
        if i == 1
            all_segments{i} = points_in_segment;
        else
            all_segments{i} = points_in_segment(2:end, :);
        end
    end
    
    % 合并所有段
    dense_centerline = vertcat(all_segments{:});
    
    % 显示信息
    total_length = sum(sqrt(sum(diff(centerline).^2, 2)));
    new_density = (size(dense_centerline, 1) - 1) / total_length;
    fprintf('分段加密完成:\n');
    fprintf('  原始点数: %d, 加密后点数: %d\n', n_points, size(dense_centerline, 1));
    fprintf('  加密后密度: %.2f 点/米\n', new_density);
    visualize_densification(centerline, dense_centerline)
end

function visualize_densification(original, dense)
    % VISUALIZE_DENSIFICATION 可视化加密效果
    
    figure;
    
    % 绘制原始中心线
    scatter3(original(:,1), original(:,2), original(:,3), 5,'filled');
    hold on
    % 绘制加密后的中心线
    scatter3(dense(:,1), dense(:,2), dense(:,3),10,'filled');
    axis equal;
    xlabel('X');
    ylabel('Y');
    zlabel('Z');
    title('中心线加密效果对比');
    
    hold off;
end