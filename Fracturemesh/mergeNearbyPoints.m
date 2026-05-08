function [mergedA, nearbyB] = mergeNearbyPoints(A, B, distanceThreshold)
% MERGENEARBYPOINTS 将B数组中在A点附近一定距离内的点归入A数组
% 输入:
%   A - Mx3 double数组, 主点云坐标
%   B - Nx3 double数组, 待合并的点云坐标
%   distanceThreshold - 距离阈值, 范围内的B点将被合并到A
% 输出:
%   mergedA - 合并后的A数组 (包含原始A和附近的B点)
%   nearbyB - 被合并的B点索引

    % 参数检查
    if nargin < 3
        error('需要3个输入参数: A, B, distanceThreshold');
    end
    if size(A, 2) ~= 3 || size(B, 2) ~= 3
        error('A和B必须是Nx3的数组');
    end
    if ~isscalar(distanceThreshold) || distanceThreshold <= 0
        error('distanceThreshold必须是正标量');
    end

    % 使用KDTree快速搜索附近点
    kdtree = KDTreeSearcher(B);
    
    % 查找每个A点附近的B点
    [indices, distances] = rangesearch(kdtree, A, distanceThreshold);
    
    % 收集所有在范围内的B点索引
    nearbyBIndices = unique([indices{:}]);
    
    % 获取对应的B点坐标
    nearbyBPoints = B(nearbyBIndices, :);
    
    % 合并A点和附近的B点
    mergedA = [A; nearbyBPoints];
    
    % 输出被合并的B点信息
    nearbyB.indices = nearbyBIndices;
    nearbyB.points = nearbyBPoints;
    nearbyB.count = length(nearbyBIndices);
    
    fprintf('合并完成: 原始A点%d个, 合并B点%d个, 总计%d个点\n', ...
            size(A, 1), nearbyB.count, size(mergedA, 1));
end

% 如果没有KDTreeSearcher, 可以使用以下替代方案
% function [mergedA, nearbyB] = mergeNearbyPointsBasic(A, B, distanceThreshold)
% % 基础版本: 使用循环计算距离
% % 参数检查同上...
% 
%     nearbyBIndices = [];
%     squaredThreshold = distanceThreshold ^ 2;
%     
%     % 对每个B点检查是否在任何一个A点的范围内
%     for i = 1:size(B, 1)
%         bPoint = B(i, :);
%         distancesSquared = sum((A - bPoint).^2, 2);
%         if any(distancesSquared <= squaredThreshold)
%             nearbyBIndices = [nearbyBIndices; i];
%         end
%     end
%     
%     % 获取对应的B点坐标
%     nearbyBPoints = B(nearbyBIndices, :);
%     
%     % 合并A点和附近的B点
%     mergedA = [A; nearbyBPoints];
%     
%     % 输出被合并的B点信息
%     nearbyB.indices = nearbyBIndices;
%     nearbyB.points = nearbyBPoints;
%     nearbyB.count = length(nearbyBIndices);
%     
%     fprintf('合并完成: 原始A点%d个, 合并B点%d个, 总计%d个点\n', ...
%             size(A, 1), nearbyB.count, size(mergedA, 1));
% end