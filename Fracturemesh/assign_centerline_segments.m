function seg_idx = assign_centerline_segments(centerLine, segCells)
% 给定裂隙中心线和分段点云，判断中心线点属于哪个分段
%
% 输入:
%   centerLine : Nx3 矩阵，裂隙中心线点坐标
%   segCells   : 1xM cell，每个 cell 是该分段的点云 (Ki×3)
%
% 输出:
%   seg_idx : Nx1 向量，每个中心点对应的分段 ID (1..M)

N = size(centerLine,1);
M = numel(segCells);
seg_idx = zeros(N,1);

% 为了效率，可以先把每段点云构建 KD-tree 或直接算最小距离
for i = 1:N
    p = centerLine(i,:);
    minDist = inf;
    minSeg = 1;
    for j = 1:M
        pts = segCells{j};
        d = sqrt(sum((pts - p).^2,2));
        [dmin,~] = min(d);
        if dmin < minDist
            minDist = dmin;
            minSeg = j;
        end
    end
    seg_idx(i) = minSeg;
end

end
