% function [V,F] = sweep_loft_mesh(centerLine, seg_idx, seg_halfwidth, seg_depth, n_in, densityTarget)
% % 生成高密度内部裂隙网格，点密度 ~ densityTarget 点/m?
% %
% % 输入:
% %   centerLine   : N×3 裂隙中心线
% %   seg_idx      : N×1 分段ID
% %   seg_halfwidth: M×1 每段半宽
% %   seg_depth    : M×1 每段深度
% %   n_in         : 1×3 岩体内部方向 (单位向量)
% %   densityTarget: 每平方米目标点数 (如 200)
% %
% % 输出:
% %   V : 顶点坐标
% %   F : 三角面索引
% 
% V = [];
% F = [];
% vCount = 0;
% M = max(seg_idx);
% n_in = n_in(:)'/norm(n_in);
% 
% for m = 1:M
%     pts = centerLine(seg_idx==m,:);
%     if size(pts,1)<2, continue; end
%     u = (pts(end,:) - pts(1,:)); u = u/norm(u);
%     w = cross(n_in, u); w = w/norm(w);
%     hw = seg_halfwidth(m);
%     d  = seg_depth(m);
% 
%     % 截面矩形的四点
%     p0 = pts(1,:); p1 = pts(end,:);
%     TL = p0 + hw*w; TR = p0 - hw*w;
%     BL = TL + d*n_in; BR = TR + d*n_in;
%     TL2= p1 + hw*w; TR2= p1 - hw*w;
%     BL2= TL2 + d*n_in; BR2 = TR2 + d*n_in;
% 
%     % 每个面四边形 → 三角网格，按面积细分
%     quads = {[TL, TR, TR2, TL2];  % top
%              [BL, BL2, BR2, BR];  % bottom
%              [TL, TL2, BL2, BL];  % left
%              [TR, BR, BR2, TR2];  % right
%              [TL, BL, BR, TR];    % near
%              [TL2, TR2, BR2, BL2]}; % far
% 
%     for q = 1:numel(quads)
%         Q = reshape(quads{q},3,4)'; % 4×3
%         % 计算面面积
%         A = 0.5*norm(cross(Q(2,:)-Q(1,:), Q(3,:)-Q(1,:))) + ...
%             0.5*norm(cross(Q(4,:)-Q(1,:), Q(3,:)-Q(1,:)));
%         % 目标点数
%         nPts = max(2, round(sqrt(A * densityTarget)));
%         % 网格化该面
%         [Vnew,Fnew] = subdivide_quad(Q,nPts);
%         F = [F; Fnew+vCount];
%         V = [V; Vnew];
%         vCount = size(V,1);
%     end
% end
% end
% 
% %% 子函数: 把四边形均匀细分成小三角
% function [V,F] = subdivide_quad(Q,n)
% % Q: 4×3 四边形点 (顺时针/逆时针)
% % n: 细分数
% V = [];
% for i = 0:n
%     for j = 0:n
%         s = i/n; t = j/n;
%         % 双线性插值
%         P = (1-s)*(1-t)*Q(1,:) + s*(1-t)*Q(2,:) + s*t*Q(3,:) + (1-s)*t*Q(4,:);
%         V = [V; P];
%     end
% end
% % 构造网格索引
% F = [];
% for i=1:n
%     for j=1:n
%         idx1 = (i-1)*(n+1)+j;
%         idx2 = idx1+1;
%         idx3 = idx1+(n+1);
%         idx4 = idx3+1;
%         F = [F; idx1 idx2 idx4; idx1 idx4 idx3];
%     end
% end
% end
function [V,F] = sweep_loft_mesh(centerLine, seg_idx, seg_halfwidth, seg_depth, n_in, densityTarget)
% SWEEP_FRACTURE_SURFACE 沿中心线扫掠生成连续裂隙曲面
%
% 输入:
%   centerLine   : N×3 中心线点
%   seg_idx      : N×1 分段编号
%   seg_halfwidth: M×1 每段半宽
%   seg_depth    : M×1 每段深度
%   n_in         : 1×3 向量，岩体内部方向 (单位化)
%   densityTarget: 目标点密度 (点/m?)
%
% 输出:
%   V : 顶点坐标 (Nv×3)
%   F : 三角面索引 (Nf×3)

n_in = n_in(:)'/norm(n_in);
N = size(centerLine,1);

% 预分配存储
rects = cell(N,1);

% 1) 在中心线每个点生成截面矩形
for i = 1:N-1
    % 切向向量
    if i==1
        tangent = centerLine(2,:) - centerLine(1,:);
    elseif i==N
        tangent = centerLine(N,:) - centerLine(N-1,:);
    else
        tangent = centerLine(i+1,:) - centerLine(i-1,:);
    end
    tangent = tangent / norm(tangent);

    % 宽度方向
    w = cross(n_in, tangent);
    if norm(w) < 1e-8
        w = [1,0,0]; % fallback
    end
    w = w / norm(w);

    % 当前点所属分段
    seg = seg_idx(i);
    hw = seg_halfwidth(seg);
    d  = seg_depth(seg);

    % 截面矩形四角
    p = centerLine(i,:);
    TL = p + hw*w; 
    TR = p - hw*w; 
    BL = TL + d*n_in; 
    BR = TR + d*n_in; 
    rects{i} = [TL; TR; BR; BL]; % 顺时针四角
end

% 2) 相邻截面拼接成四边形 → 再细分成三角网格
V = []; F = []; vCount = 0;

for i = 2:N-1
    R1 = rects{i-1};
    R2 = rects{i};

    % 六个面：上/下/左/右/前/后
    quads = {
        [R1(1,:);R1(2,:);R2(2,:);R2(1,:)] % top
        [R1(4,:);R1(3,:);R2(3,:);R2(4,:)] % bottom
        [R1(1,:);R2(1,:);R2(4,:);R1(4,:)] % left
        [R1(2,:);R1(3,:);R2(3,:);R2(2,:)] % right
        [R1(1,:);R1(4,:);R1(3,:);R1(2,:)] % near cap
        [R2(1,:);R2(2,:);R2(3,:);R2(4,:)] % far cap
    };

    for q = 1:numel(quads)
        Q = quads{q};
        % 面面积
        A = 0.5*norm(cross(Q(2,:)-Q(1,:), Q(3,:)-Q(1,:))) + ...
            0.5*norm(cross(Q(4,:)-Q(1,:), Q(3,:)-Q(1,:)));
        % 目标细分数
        nPts = max(2, round(sqrt(A * densityTarget)));
        [Vnew,Fnew] = subdivide_quad(Q,nPts);
        F = [F; Fnew+vCount];
        V = [V; Vnew];
        vCount = size(V,1);
    end
end

end

%% 辅助函数: 四边形均匀细分
function [V,F] = subdivide_quad(Q,n)
% Q: 4×3 四边形点 (顺序)
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
for i=1:n
    for j=1:n
        idx1 = (i-1)*(n+1)+j;
        idx2 = idx1+1;
        idx3 = idx1+(n+1);
        idx4 = idx3+1;
        F = [F; idx1 idx2 idx4; idx1 idx4 idx3];
    end
end
end
