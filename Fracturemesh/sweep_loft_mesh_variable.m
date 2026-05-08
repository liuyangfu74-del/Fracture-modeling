% function [V, F, upper_surface, lower_surface] = sweep_loft_mesh_variable(centerLine, seg_idx, start_width, seg_depth, n_in, densityTarget)
% % SWEEP_LOFT_MESH_VARIABLE 沿中心线扫掠生成连续裂隙曲面，支持可变截面宽度
% 
%     n_in = n_in(:)' / norm(n_in);
%     N = size(centerLine, 1);
%     
%     % 确保 seg_idx 是列向量
%     seg_idx = seg_idx(:);
%     
%     % 获取唯一分段编号（按出现顺序）
%     [unique_segs, ~, ic] = unique(seg_idx, 'stable');
%     num_segs = length(unique_segs);
%     
%     % 创建宽度渐变函数（线性衰减）
%     seg_widths = zeros(num_segs, 1);
%     for s = 1:num_segs
%         if num_segs == 1
%             seg_widths(s) = start_width(min(s, end));  % 安全索引
%         else
%             % 使用start_width的第s个元素
%             seg_widths(s) = start_width(min(s, length(start_width))) * (1 - (s-1)/(num_segs-1));
%         end
%     end
%     
%     % 预分配存储
%     rects = cell(N, 1);
%     
%     % 1) 在中心线每个点生成截面矩形（宽度渐变）
%     for i = 1:N
%         % 切向向量
%         if i == 1
%             tangent = centerLine(2, :) - centerLine(1, :);
%         elseif i == N
%             tangent = centerLine(N, :) - centerLine(N-1, :);
%         else
%             tangent = centerLine(i+1, :) - centerLine(i-1, :);
%         end
%         tangent = tangent / norm(tangent);
%         
%         % 宽度方向
%         w = cross(n_in, tangent);
%         if norm(w) < 1e-8
%             w = [1, 0, 0]; % fallback
%         end
%         w = w / norm(w);
%         
%         % 当前点所属分段（使用映射关系）
%         seg_index = ic(i);  % 这是1到num_segs之间的整数
%         hw = seg_widths(seg_index);  % 使用渐变宽度
%         
%         % 获取对应的深度（确保索引不越界）
%         if seg_index <= length(seg_depth)
%             d = seg_depth(seg_index);
%         else
%             d = seg_depth(end); % 使用最后一个深度值
%         end
%         
%         % 截面矩形四角
%         p = centerLine(i, :);
%         TL = p + hw * w; 
%         TR = p - hw * w; 
%         BL = TL + d * n_in; 
%         BR = TR + d * n_in; 
%         rects{i} = [TL; TR; BR; BL];
%     end
%     
%     % 2) 生成网格
%     V = []; F = []; vCount = 0;
%     
%     for i = 2:N
%         if isempty(rects{i-1}) || isempty(rects{i})
%             continue;
%         end
%         
%         R1 = rects{i-1};
%         R2 = rects{i};
%         
%         % === 修改1：只保留上下两个面 ===
%         quads = {
% %             [R1(1,:); R1(2,:); R2(2,:); R2(1,:)] % top
% %             [R1(4,:); R1(3,:); R2(3,:); R2(4,:)] % bottom
%             [R1(1,:); R2(1,:); R2(4,:); R1(4,:)] % left
%             [R1(2,:); R1(3,:); R2(3,:); R2(2,:)] % right
% %             [R1(1,:); R1(4,:); R1(3,:); R1(2,:)] % near cap
% %             [R2(1,:); R2(2,:); R2(3,:); R2(4,:)] % far cap
%         };
%         
%         for q = 1:numel(quads)
%             Q = quads{q};
%             % 面面积
%             A = 0.5 * norm(cross(Q(2,:) - Q(1,:), Q(3,:) - Q(1,:))) + ...
%                 0.5 * norm(cross(Q(4,:) - Q(1,:), Q(3,:) - Q(1,:)));
%             % 目标细分数
%             nPts = max(2, round(sqrt(A * densityTarget)));
%             [Vnew, Fnew] = subdivide_quad(Q, nPts);
%             F = [F; Fnew + vCount];
%             V = [V; Vnew];
%             vCount = size(V, 1);
%         end
%     end
%     
%     % === 修改2-5：生成上下表面数据 ===
%     upper_surface = [];
%     lower_surface = [];
%     
%     % 提取所有上表面点（TL点）
%     for i = 1:N
%         if ~isempty(rects{i})
%             upper_surface = [upper_surface; rects{i}(1,:)];  % TL点
%         end
%     end
%     
%     % 提取所有下表面点（BL点）
%     for i = 1:N
%         if ~isempty(rects{i})
%             lower_surface = [lower_surface; rects{i}(4,:)];  % BL点
%         end
%     end
%     
%     fprintf('网格生成完成: 顶点数=%d, 面数=%d\n', size(V,1), size(F,1));
% end
% %% 辅助函数: 四边形均匀细分（移到文件顶部）
% function [V, F] = subdivide_quad(Q, n)
% % Q: 4×3 四边形点 (顺序)
% % n: 每边细分数
%     V = [];
%     for i = 0:n
%         for j = 0:n
%             s = i/n; t = j/n;
%             P = (1-s)*(1-t)*Q(1,:) + s*(1-t)*Q(2,:) + s*t*Q(3,:) + (1-s)*t*Q(4,:);
%             V = [V; P];
%         end
%     end
%     F = [];
%     for i = 1:n
%         for j = 1:n
%             idx1 = (i-1)*(n+1)+j;
%             idx2 = idx1+1;
%             idx3 = idx1+(n+1);
%             idx4 = idx3+1;
%             F = [F; idx1 idx2 idx4; idx1 idx4 idx3];
%         end
%     end
% end
function [V, F, upper_surface, lower_surface] = sweep_loft_mesh_variable(centerLine, seg_idx, start_width, seg_depth, n_in, densityTarget)
% SWEEP_LOFT_MESH_VARIABLE 沿中心线扫掠生成连续裂隙曲面，支持可变截面宽度
% 修改：实现沿深度方向的宽度衰减

    n_in = n_in(:)' / norm(n_in);
    N = size(centerLine, 1);
    
    % 确保 seg_idx 是列向量
    seg_idx = seg_idx(:);
    
    % 获取唯一分段编号（按出现顺序）
    [unique_segs, ~, ic] = unique(seg_idx, 'stable');
    num_segs = length(unique_segs);
    
    % 计算每个分段对应的初始宽度（不进行衰减，直接使用输入值）
    seg_widths = zeros(num_segs, 1);
    for s = 1:num_segs
        % 直接使用start_width的对应元素，不进行沿中心线的衰减
        seg_widths(s) = start_width(min(s, length(start_width)));
    end
    
    % 预存储：每个中心点对应多个深度步长的截面
    % rects{i}{j} 表示第i个中心点、第j个深度步长的截面矩形
    rects = cell(N, 1);
    
    % 定义深度方向的最小步长（控制网格密度）
    min_step_size = 0.05;  % 可以根据需要调整
    
    % 1) 在中心线每个点生成沿深度方向衰减的截面矩形
    for i = 1:N
        % 切向向量
        if i == 1
            tangent = centerLine(2, :) - centerLine(1, :);
        elseif i == N
            tangent = centerLine(N, :) - centerLine(N-1, :);
        else
            tangent = centerLine(i+1, :) - centerLine(i-1, :);
        end
        tangent = tangent / norm(tangent);
        
        % 宽度方向
        w = cross(n_in, tangent);
        if norm(w) < 1e-8
            w = [1, 0, 0]; % fallback
        end
        w = w / norm(w);
        
        % 当前点所属分段
        seg_index = ic(i);
        
        % 获取该分段的初始宽度和总深度
        W0 = seg_widths(seg_index);
        total_depth = seg_depth(min(seg_index, length(seg_depth)));
        
        % 计算沿深度方向的分段数
        % 根据初始宽度和总深度确定合适的步数，使得宽度衰减平滑
        if W0 > 0
            % 步数 = 总深度 / 最小步长，向上取整
            m = max(2, ceil(total_depth / min_step_size));
        else
            m = 1;  % 宽度为0时只生成一个截面
        end
        
        % 每个深度步长的实际长度
        step_depth = total_depth / m;
        
        % 生成该中心点沿深度方向的多个截面
        depth_rects = cell(m, 1);
        
        for j = 0:m-1
            % 计算当前步长的衰减后宽度（线性衰减到0）
            % j=0时宽度为W0，j=m-1时宽度趋近于0
            if m > 1
                W_ij = W0 * (1 - j/(m-1));
            else
                W_ij = W0;
            end
            
            % 计算当前步长的位置偏移（沿深度方向）
            depth_offset = j * step_depth * n_in;
            
            % 当前步长的中心点位置
            p_current = centerLine(i, :) + depth_offset;
            
            % 截面矩形四角
            half_width = W_ij / 2;
            TL = p_current + half_width * w;      % Top-Left (上表面点)
            TR = p_current - half_width * w;      % Top-Right
            BL = TL + step_depth * n_in;           % Bottom-Left (下表面点，指向下一个步长)
            BR = TR + step_depth * n_in;           % Bottom-Right
            
            % 存储当前步长的矩形
            depth_rects{j+1} = [TL; TR; BR; BL];
        end
        
        rects{i} = depth_rects;
    end
    
    % 2) 生成网格
    V = []; F = []; vCount = 0;
    
    % 收集所有上下表面点
    upper_points = [];
    lower_points = [];
    
    for i = 1:N
        depth_rects_i = rects{i};
        m_i = length(depth_rects_i);
        
        for j = 1:m_i
            R = depth_rects_i{j};
            
            % 收集上下表面点
            upper_points = [upper_points; R(1,:)];  % TL点
            lower_points = [lower_points; R(4,:)];  % BL点
        end
    end
    
    % 去重（可选）
    upper_surface = unique(upper_points, 'rows', 'stable');
    lower_surface = unique(lower_points, 'rows', 'stable');
    
    % 生成相邻截面间的面片
    for i = 1:N-1  % 遍历相邻中心点
        depth_rects_i = rects{i};
        depth_rects_ip1 = rects{i+1};
        
        m_i = length(depth_rects_i);
        m_ip1 = length(depth_rects_ip1);
        
        % 取两个中心点中较小的深度步数，保证连接
        m_min = min(m_i, m_ip1);
        
        for j = 1:m_min
            R1 = depth_rects_i{j};
            R2 = depth_rects_ip1{j};
            
            % 构建左右两个面（与文档一致）
            quads = {
                [R1(1,:); R2(1,:); R2(4,:); R1(4,:)] % left plane: TL_i, TL_i+1, BL_i+1, BL_i
                [R1(2,:); R1(3,:); R2(3,:); R2(2,:)] % right plane: TR_i, BR_i, BR_i+1, TR_i+1
            };
            
            for q = 1:numel(quads)
                Q = quads{q};
                % 面面积
                A = 0.5 * norm(cross(Q(2,:) - Q(1,:), Q(3,:) - Q(1,:))) + ...
                    0.5 * norm(cross(Q(4,:) - Q(1,:), Q(3,:) - Q(1,:)));
                
                % 目标细分数
                nPts = max(2, round(sqrt(A * densityTarget)));
                [Vnew, Fnew] = subdivide_quad(Q, nPts);
                F = [F; Fnew + vCount];
                V = [V; Vnew];
                vCount = size(V, 1);
            end
        end
    end
    
    fprintf('网格生成完成: 顶点数=%d, 面数=%d\n', size(V,1), size(F,1));
end

%% 辅助函数: 四边形均匀细分
function [V, F] = subdivide_quad(Q, n)
% Q: 4×3 四边形点 (顺序: TL, TR, BR, BL)
% n: 每边细分数
    V = [];
    for i = 0:n
        for j = 0:n
            s = i/n; t = j/n;
            P = (1-s)*(1-t)*Q(1,:) + s*(1-t)*Q(2,:) + s*t*Q(3,:) + (1-s)*t*Q(4,:);
            V = [V; P];
        end
    end
    F = [];
    for i = 1:n
        for j = 1:n
            idx1 = (i-1)*(n+1)+j;
            idx2 = idx1+1;
            idx3 = idx1+(n+1);
            idx4 = idx3+1;
            F = [F; idx1 idx2 idx4; idx1 idx4 idx3];
        end
    end
end