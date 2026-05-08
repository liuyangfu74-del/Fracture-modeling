function [V, F, selSign] = generate_fracture_mesh_advanced(linePts, A, B, gridSize, pcacoondates)
% GENERATE_FRACTURE_MESH_ADVANCED  鲁棒实现（修复 dot 大小不匹配）
% 输入:
%   linePts - Nx3 裂隙点云（至少 2 行）
%   A, B    - 长度 3 的向量（行或列均可）
%   gridSize- 网格间距（正标量）
% 输出:
%   V       - Mx3 网格顶点
%   F       - Kx3 三角面片索引
%   selSign - 选择方向: +1 表示使用 A 在平面上的"垂直分量"，-1 表示使用 -A

% -------- 参数检查与预处理 --------
if nargin < 4, error('需要 4 个输入：linePts,A,B,gridSize'); end
if size(linePts,2) ~= 3, error('linePts 必须为 Nx3'); end
if ~isscalar(gridSize) || gridSize <= 0, error('gridSize 必须为正标量'); end

% 保证列向量
A = double(A(:));
B = double(B(:));
tol = 1e-10;

% -------- 估算裂隙中心线与方向（若多点使用 PCA）--------
% if size(linePts,1) >= 3
%     meanP = mean(linePts,1);
%     C = bsxfun(@minus, linePts, meanP);
%     [~,~,Vv] = svd(C, 'econ');
%     v_line = Vv(:,1);         % 主方向（列向量）
%     t = (linePts - meanP) * v_line;
%     p1 = meanP(:) + v_line * min(t);
%     p2 = meanP(:) + v_line * max(t);
% else
    p1 = linePts(1,:)';
    p2 = linePts(end,:)';
%     v_line = (p2 - p1);
% end

% L = norm(v_line);
% if L < tol, error('裂隙长度为零或非常小'); end
% v_line = v_line / L;
center = (p1 + p2) / 2;
[coeff,~,~,~] = pca(pcacoondates);
v_line = coeff(:, 1);  % 第三主成分作为法线方向

% -------- 构造平面法向量（由 v_line 与 A 张成）--------
% 先保证 A 不是零向量
if norm(A) < tol
    error('输入向量 A 近似零向量，无法确定平面');
end
n_plane = cross(v_line, A);
if norm(n_plane) < tol
    % 退化：A 与 v_line 共线，选临时向量构造平面
    tmp = [1;0;0];
    if abs(dot(tmp, v_line)) > 0.9, tmp = [0;1;0]; end
    n_plane = cross(v_line, tmp);
end
n_plane = n_plane / norm(n_plane);

% -------- 计算 A 在平面上的分量，并取垂直于裂隙线的分量 --------
A_plane = A - ( (A' * n_plane) * n_plane );       % 投影到平面
if norm(A_plane) < tol
    % A 投影几乎为零 -> 用平面内与裂隙垂直的标准向量
    A_plane_perp = cross(n_plane, v_line);
else
    % 去掉沿裂隙的分量，得到平面内且与裂隙垂直的分量
    A_plane_perp = A_plane - ( (v_line' * A_plane) * v_line );
end
if norm(A_plane_perp) < tol
    % 最后兜底：用 cross(n_plane,v_line)
    A_plane_perp = cross(n_plane, v_line);
end
A_plane_perp = A_plane_perp / norm(A_plane_perp);  % 单位向量
% 两个候选方向为 ±A_plane_perp

% -------- B 投影到平面并单位化 --------
B_proj = B - ( (B' * n_plane) * n_plane );
if norm(B_proj) < tol
    % B 与平面几乎垂直，退化处理：用裂隙方向作为替代投影
    B_proj = v_line;
end
B_proj = B_proj / norm(B_proj);

% -------- 计算夹角（使用内积计算并数值截断）--------
s1 = (B_proj' *  A_plane_perp);   % 与 +A_plane_perp 的 cosθ
s2 = (B_proj' * -A_plane_perp);   % 与 -A_plane_perp 的 cosθ
% 数值稳定：截断到 [-1,1]
s1 = max(-1, min(1, s1));
s2 = max(-1, min(1, s2));
ang1 = acosd(s1);
ang2 = acosd(s2);

% -------- 选择夹角较大的方向（按你要求：取较大者）--------
if ang1 >= ang2
    selSign = +1;
    longDir =  A_plane_perp;
else
    selSign = -1;
    longDir = -A_plane_perp;
end

% -------- 生成特殊三角网格（带起伏）--------
% 第一层：原始裂隙线上的点
currentLayer = linePts;
V = currentLayer;
F = [];

% 计算平均线段长度
if size(currentLayer, 1) > 1
    avgDist = mean(sqrt(sum(diff(currentLayer).^2, 2)));
    triangleHeight = avgDist * sqrt(3) / 2; % 等边三角形高度
else
    triangleHeight = gridSize * sqrt(3) / 2;
end

% 逐层生成网格
layer = 1;
while size(currentLayer, 1) > 1
    % 计算下一层点
    nextLayer = zeros(size(currentLayer, 1)-1, 3);
    
    for i = 1:size(currentLayer, 1)-1
        % 计算中点
        p1 = currentLayer(i, :);
        p2 = currentLayer(i+1, :);
        midPoint = (p1 + p2) / 2;
        
        % 计算上一层两个点在平面法线方向上的平均高度
        if layer == 1
            % 第一层：使用参考平面
            vec1 = p1' - center;
            height1 = dot(vec1, n_plane);
            vec2 = p2' - center;
            height2 = dot(vec2, n_plane);
            avgHeight = (height1 + height2) / 2;
        else
            % 后续层：使用上一层相邻三个点的平均高度
            prevLayerIdx = size(V, 1) - size(currentLayer, 1) - (size(currentLayer, 1)-1) + 1;
            if i == 1
                % 第一个点：使用前两个点
                p_prev1 = V(prevLayerIdx, :);
                p_prev2 = V(prevLayerIdx + 1, :);
                vec1 = p_prev1' - center;
                vec2 = p_prev2' - center;
                avgHeight = (dot(vec1, n_plane) + dot(vec2, n_plane)) / 2;
            elseif i == size(currentLayer, 1)-1
                % 最后一个点：使用后两个点
                p_prev1 = V(prevLayerIdx + i - 2, :);
                p_prev2 = V(prevLayerIdx + i - 1, :);
                vec1 = p_prev1' - center;
                vec2 = p_prev2' - center;
                avgHeight = (dot(vec1, n_plane) + dot(vec2, n_plane)) / 2;
            else
                % 中间点：使用三个相邻点
                p_prev1 = V(prevLayerIdx + i - 2, :);
                p_prev2 = V(prevLayerIdx + i - 1, :);
                p_prev3 = V(prevLayerIdx + i, :);
                vec1 = p_prev1' - center;
                vec2 = p_prev2' - center;
                vec3 = p_prev3' - center;
                avgHeight = (dot(vec1, n_plane) + dot(vec2, n_plane) + dot(vec3, n_plane)) / 3;
            end
        end
        
        % 沿法线方向移动，但保持起伏度
        basePoint = midPoint + triangleHeight * longDir' * selSign;
        
        % 调整高度到平均起伏度
        vec_base = basePoint' - center;
        currentHeight = dot(vec_base, n_plane);
        heightAdjustment = avgHeight - currentHeight;
        
        % 应用高度调整
        nextLayer(i, :) = basePoint + heightAdjustment * n_plane';
    end
    
    % 添加新顶点
    startIdx = size(V, 1) + 1;
    V = [V; nextLayer];
    
    % 添加三角形面
    for i = 1:size(currentLayer, 1)-1
        % 基础三角形（连接当前层和下一层）
        if layer == 1
            F = [F; size(V, 1)-size(nextLayer, 1)-size(currentLayer, 1)+i, ...
                    size(V, 1)-size(nextLayer, 1)-size(currentLayer, 1)+i+1, ...
                    startIdx+i-1];
        else
            F = [F; size(V, 1)-size(nextLayer, 1)-size(currentLayer, 1)+i, ...
                    size(V, 1)-size(nextLayer, 1)-size(currentLayer, 1)+i+1, ...
                    startIdx+i-1];
        end
        
        % 连接上一层的三角形（如果不是第一层）
        if layer > 1
            prevStartIdx = size(V, 1) - size(nextLayer, 1) - size(currentLayer, 1) + 1;
            if i > 1
                F = [F; startIdx+i-2, startIdx+i-1, prevStartIdx+i-1];
            end
        end
    end
    
    % 准备下一轮迭代
    currentLayer = nextLayer;
    layer = layer + 1;
    
    % 逐渐减小三角形高度，使网格更加平滑
    triangleHeight = triangleHeight * 0.9;
end

end

