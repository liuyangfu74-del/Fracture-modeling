function [fractureSegments] = processFractureCloud(fractureCloud, stepSize, UmergedA,direction)
% PROCESSFRACTURECLOUD 处理岩石裂隙点云数据，计算开度和迹长
%
% 输入参数：
%   fractureCloud - 裂隙点云数据，N×3矩阵 [x, y, z]
%   stepSize - 分段步长
%   direction - 裂隙延伸方向向量 [dx, dy, dz]，默认为主成分方向
%
% 输出参数：
%   fractureSegments - 结构体数组，包含每个分段的信息

% 参数检查
if nargin < 4
    % 使用PCA确定主要延伸方向
    [coeff, ~, latent] = pca(UmergedA);
    direction = coeff(:,1)'; % 第一主成分方向为延伸方向
    fprintf('Automatically determined extension direction: [%.3f, %.3f, %.3f]\n', direction);
    fprintf('Principal component variance: %.3f, %.3f, %.3f\n', latent);
end

if nargin < 2
    stepSize = 0.1; % 默认步长
end

% 构建局部坐标系
xAxis = direction(:) / norm(direction); % 延伸方向（第一主成分）

% 对每个分段单独进行PCA，确定该分段的开度方向
[coeff_all, ~, ~] = pca(UmergedA);
% 第二主成分方向（垂直于延伸方向的主要方向）
yAxis = coeff_all(:,2);
% 第三主成分方向（开度方向，垂直于延伸方向的最小方差方向）
zAxis = coeff_all(:,3);

% 构建变换矩阵：从世界坐标系到局部坐标系
transformMatrix = [xAxis, yAxis, zAxis]';
center = mean(fractureCloud, 1);
centeredPoints = fractureCloud - center;

% 转换到局部坐标系
localCoords = centeredPoints * transformMatrix';

% 沿着延伸方向（x轴）进行分段
xCoords = localCoords(:,1);
minX = min(xCoords);
maxX = max(xCoords);
totalLength = maxX - minX;

% 确定分段数量
numSegments = ceil(totalLength / stepSize);

% 初始化分段结构体
fractureSegments = struct(...
    'startPos', {}, ...
    'endPos', {}, ...
    'length', {}, ...
    'aperture', {}, ...
    'pointCloud', {}, ...
    'centerPoint', {}, ...
    'numPoints', {}, ...
    'localCoords', {} ...
);

% 创建分段
for i = 1:numSegments
    % 计算当前分段的x坐标范围
    segStart = minX + (i-1) * stepSize;
    segEnd = min(segStart + stepSize, maxX);
    
    % 找出在当前分段内的点
    inSegment = (xCoords >= segStart) & (xCoords <= segEnd);
    segmentIndices = find(inSegment);
    
    if ~isempty(segmentIndices) && length(segmentIndices) > 3
        % 提取当前分段的点云
        segmentPoints = fractureCloud(segmentIndices, :);
        
        % 对当前分段进行PCA，确定该分段的开度方向
        [coeff_segment, ~, latent_segment] = pca(segmentPoints);
        
        % 确定延伸方向（与整体延伸方向最接近的主成分）
        dotProducts = abs(coeff_segment' * xAxis);
        [~, extendIdx] = max(dotProducts);
        
        % 另外两个主成分中，方差较小的为开度方向
        otherIndices = setdiff(1:3, extendIdx);
        [~, apertureIdx] = min(latent_segment(otherIndices));
        apertureDirection = coeff_segment(:, otherIndices(apertureIdx));
        
        % 构建当前分段的局部坐标系
        xAxis_segment = coeff_segment(:, extendIdx);
        zAxis_segment = apertureDirection; % 开度方向
        yAxis_segment = cross(xAxis_segment, zAxis_segment);
        yAxis_segment = yAxis_segment / norm(yAxis_segment);
        
        % 转换到当前分段的局部坐标系
        transformMatrix_segment = [xAxis_segment, yAxis_segment, zAxis_segment]';
        center_segment = mean(segmentPoints, 1);
        segmentLocalCoords = (segmentPoints - center_segment) * transformMatrix_segment';
        
        % 计算开度：在开度方向（z轴）上的范围
        aperture = range(segmentLocalCoords(:,3));
        
        % 计算分段长度
        segmentLength = segEnd - segStart;
        
        % 计算中心点
        centerPoint = mean(segmentPoints, 1);
        
        % 存储分段信息
        fractureSegments(i).startPos = segStart;
        fractureSegments(i).endPos = segEnd;
        fractureSegments(i).length = segmentLength;
        fractureSegments(i).aperture = aperture;
        fractureSegments(i).pointCloud = segmentPoints;
        fractureSegments(i).centerPoint = centerPoint;
        fractureSegments(i).numPoints = size(segmentPoints, 1);
        fractureSegments(i).localCoords = segmentLocalCoords;
        fractureSegments(i).apertureDirection = zAxis_segment';
%         fractureSegments(i).apertureDirection2D1 = coeff_segment(:, 1)';
%         fractureSegments(i).apertureDirection2D2 = coeff_segment(:, 2)';
    elseif ~isempty(segmentIndices)
        % 点数太少的分段，使用简化方法
        segmentPoints = fractureCloud(segmentIndices, :);
        segmentLocalCoords = (segmentPoints - center) * transformMatrix';
        
        % 使用整体坐标系的z轴范围作为开度
        aperture = range(segmentLocalCoords(:,3));
        
        segmentLength = segEnd - segStart;
        centerPoint = mean(segmentPoints, 1);
        
        fractureSegments(i).startPos = segStart;
        fractureSegments(i).endPos = segEnd;
        fractureSegments(i).length = segmentLength;
        fractureSegments(i).aperture = aperture;
        fractureSegments(i).pointCloud = segmentPoints;
        fractureSegments(i).centerPoint = centerPoint;
        fractureSegments(i).numPoints = size(segmentPoints, 1);
        fractureSegments(i).localCoords = segmentLocalCoords;
        fractureSegments(i).apertureDirection = zAxis';
    end
end

% 移除空的分段
fractureSegments = fractureSegments([fractureSegments.numPoints] > 0);

% 显示处理结果
fprintf('Processing completed! Total segments: %d\n', length(fractureSegments));
fprintf('Total trace length: %.3f m\n', totalLength);
fprintf('Mean aperture: %.3f m\n', mean([fractureSegments.aperture]));
fprintf('Maximum aperture: %.3f m\n', max([fractureSegments.aperture]));
fprintf('Minimum aperture: %.3f m\n', min([fractureSegments.aperture]));

end

% function plotFractureResults(segments, originalCloud)
% % 可视化结果 - 英文版，新罗马字体
% figure('Position', [50, 50, 1600, 1000], 'Name', 'Fracture Aperture Analysis');
% 
% if isempty(segments)
%     return;
% end
% 
% % 设置新罗马字体
% fontName = 'Times New Roman';
% titleFontSize = 16;
% axisFontSize = 14;
% tickFontSize = 12;
% 
% % 选择中间的一个分段作为示例
% exampleIdx = ceil(length(segments) / 2);
% exampleSegment = segments(exampleIdx);
% 
% % 创建子图
% subplotHandles = gobjects(2, 3);
% 
% % 子图1：原始点云和分段示意图
% subplotHandles(1) = subplot(2, 3, 1);
% scatter3(originalCloud(:,1), originalCloud(:,2), originalCloud(:,3), 10, 'filled', 'MarkerFaceAlpha', 0.3);
% hold on;
% scatter3(exampleSegment.pointCloud(:,1), exampleSegment.pointCloud(:,2), ...
%          exampleSegment.pointCloud(:,3), 30, 'r', 'filled');
% title('Original Point Cloud and Example Segment', 'FontName', fontName, 'FontSize', titleFontSize, 'FontWeight', 'bold');
% xlabel('X (m)', 'FontName', fontName, 'FontSize', axisFontSize);
% ylabel('Y (m)', 'FontName', fontName, 'FontSize', axisFontSize);
% zlabel('Z (m)', 'FontName', fontName, 'FontSize', axisFontSize);
% grid on; axis equal;
% legend('All Points', 'Example Segment', 'Location', 'best', 'FontName', fontName, 'FontSize', tickFontSize);
% set(gca, 'FontName', fontName, 'FontSize', tickFontSize);
% 
% % 子图2：示例分段的局部坐标系视图
% subplotHandles(2) = subplot(2, 3, 2);
% scatter3(exampleSegment.localCoords(:,1), exampleSegment.localCoords(:,2), ...
%          exampleSegment.localCoords(:,3), 30, 'filled');
% hold on;
% % 绘制坐标系
% origin = mean(exampleSegment.localCoords, 1);
% quiver3(origin(1), origin(2), origin(3), 0.5, 0, 0, 'r', 'LineWidth', 2, 'MaxHeadSize', 0.5);
% quiver3(origin(1), origin(2), origin(3), 0, 0.5, 0, 'g', 'LineWidth', 2, 'MaxHeadSize', 0.5);
% quiver3(origin(1), origin(2), origin(3), 0, 0, 0.5, 'b', 'LineWidth', 2, 'MaxHeadSize', 0.5);
% title('Local Coordinate System of Example Segment', 'FontName', fontName, 'FontSize', titleFontSize, 'FontWeight', 'bold');
% xlabel('Extension Direction (X)', 'FontName', fontName, 'FontSize', axisFontSize);
% ylabel('Y Direction', 'FontName', fontName, 'FontSize', axisFontSize);
% zlabel('Aperture Direction (Z)', 'FontName', fontName, 'FontSize', axisFontSize);
% grid on; axis equal;
% legend('Point Cloud', 'X-axis (Extension)', 'Y-axis', 'Z-axis (Aperture)', 'Location', 'best', 'FontName', fontName, 'FontSize', tickFontSize);
% set(gca, 'FontName', fontName, 'FontSize', tickFontSize);
% 
% % 子图3：开度方向（Z轴）的分布
% subplotHandles(3) = subplot(2, 3, 3);
% zCoords = exampleSegment.localCoords(:,3);
% histogram(zCoords, 20, 'FaceColor', 'blue', 'EdgeColor', 'black');
% hold on;
% xline(min(zCoords), 'r--', 'LineWidth', 2);
% xline(max(zCoords), 'r--', 'LineWidth', 2);
% title('Aperture Distribution of Example Segment', 'FontName', fontName, 'FontSize', titleFontSize, 'FontWeight', 'bold');
% xlabel('Aperture Coordinate Value (m)', 'FontName', fontName, 'FontSize', axisFontSize);
% ylabel('Frequency', 'FontName', fontName, 'FontSize', axisFontSize);
% grid on;
% legend('Distribution', 'Min/Max Values', 'Location', 'best', 'FontName', fontName, 'FontSize', tickFontSize);
% set(gca, 'FontName', fontName, 'FontSize', tickFontSize);
% 
% % 子图4：所有分段开度沿迹长的分布
% subplotHandles(4) = subplot(2, 3, 4);
% centerX = arrayfun(@(s) (s.startPos + s.endPos)/2, segments);
% apertures = [segments.aperture];
% plot(centerX, apertures, 'bo-', 'LineWidth', 1.5, 'MarkerFaceColor', 'b', 'MarkerSize', 4);
% hold on;
% plot(centerX(exampleIdx), apertures(exampleIdx), 'ro', 'MarkerSize', 8, 'MarkerFaceColor', 'r');
% title('Aperture Distribution Along Trace Length', 'FontName', fontName, 'FontSize', titleFontSize, 'FontWeight', 'bold');
% xlabel('Position Along Trace Length (m)', 'FontName', fontName, 'FontSize', axisFontSize);
% ylabel('Aperture (m)', 'FontName', fontName, 'FontSize', axisFontSize);
% grid on;
% legend('Segment Aperture', 'Example Segment', 'Location', 'best', 'FontName', fontName, 'FontSize', tickFontSize);
% set(gca, 'FontName', fontName, 'FontSize', tickFontSize);
% 
% % 子图5：开度统计直方图
% subplotHandles(5) = subplot(2, 3, 5);
% histogram(apertures, 20, 'FaceColor', 'green', 'EdgeColor', 'black');
% hold on;
% xline(mean(apertures), 'r--', 'LineWidth', 2, 'DisplayName', sprintf('Mean: %.3f m', mean(apertures)));
% xline(median(apertures), 'b--', 'LineWidth', 2, 'DisplayName', sprintf('Median: %.3f m', median(apertures)));
% title('Statistical Distribution of Aperture', 'FontName', fontName, 'FontSize', titleFontSize, 'FontWeight', 'bold');
% xlabel('Aperture (m)', 'FontName', fontName, 'FontSize', axisFontSize);
% ylabel('Frequency', 'FontName', fontName, 'FontSize', axisFontSize);
% grid on;
% legend('show', 'FontName', fontName, 'FontSize', tickFontSize);
% set(gca, 'FontName', fontName, 'FontSize', tickFontSize);
% 
% % 子图6：分段信息汇总
% subplotHandles(6) = subplot(2, 3, 6);
% % 显示文本信息
% text(0.1, 0.8, sprintf('Example Segment %d:', exampleIdx), 'FontName', fontName, 'FontSize', axisFontSize, 'FontWeight', 'bold');
% text(0.1, 0.7, sprintf('  Aperture: %.3f m', exampleSegment.aperture), 'FontName', fontName, 'FontSize', tickFontSize);
% text(0.1, 0.6, sprintf('  Length: %.3f m', exampleSegment.length), 'FontName', fontName, 'FontSize', tickFontSize);
% text(0.1, 0.5, sprintf('  Points: %d', exampleSegment.numPoints), 'FontName', fontName, 'FontSize', tickFontSize);
% text(0.1, 0.4, 'Overall Statistics:', 'FontName', fontName, 'FontSize', axisFontSize, 'FontWeight', 'bold');
% text(0.1, 0.3, sprintf('  Mean Aperture: %.3f m', mean(apertures)), 'FontName', fontName, 'FontSize', tickFontSize);
% text(0.1, 0.2, sprintf('  Mean Length: %.3f m', mean([segments.length])), 'FontName', fontName, 'FontSize', tickFontSize);
% text(0.1, 0.1, sprintf('  Mean Points: %.1f', mean([segments.numPoints])), 'FontName', fontName, 'FontSize', tickFontSize);
% axis off;
% title('Segment Information Summary', 'FontName', fontName, 'FontSize', titleFontSize, 'FontWeight', 'bold');
% 
% % 设置背景颜色
% set(gcf, 'Color', 'w');
% 
% % 添加创建日期和时间
% annotation('textbox', [0.02, 0.02, 0.2, 0.03], 'String', sprintf('Created: %s', datestr(now)), ...
%     'FontName', fontName, 'FontSize', 10, 'EdgeColor', 'none', 'Color', [0.5, 0.5, 0.5]);
% 
% % 调整子图间距，确保标题可见
% set(gcf, 'Units', 'normalized');
% for i = 1:6
%     if isgraphics(subplotHandles(i))
%         pos = get(subplotHandles(i), 'Position');
%         % 稍微调整位置，确保标题完全可见
%         set(subplotHandles(i), 'Position', [pos(1), pos(2)-0.01, pos(3), pos(4)*0.98]);
%     end
% end
% 
% end