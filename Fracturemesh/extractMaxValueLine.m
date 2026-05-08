function [fractureProperties, Fractioninformations] = extractMaxValueLine(points, values, esplain, minpt,Nearpoints)
    % 生成裂隙等边三角网格
    % 输入: points - 裂隙点云坐标(N×3), values - 点的赋值(N×1)
    %DBSCAN裂隙分组
    labels = dbscan(points, esplain, minpt);
    % 获取聚类数量（排除噪声点，标签为-1）
    clusterIds = unique(labels);
    clusterIds = clusterIds(clusterIds ~= -1);
    numClusters = length(clusterIds);

figure;
colors = lines(max(labels)+1);
for i = 1:max(labels)+1
    if i == 1
        idx = labels == -1; % 噪声点
        color = [0.5 0.5 0.5]; % 灰色
    else
        idx = labels == (i-1);
        color = colors(i-1,:);
    end
    scatter3(points(idx,1), points(idx,2), points(idx,3), 5, color, 'filled');
    hold on;
end
fontName = 'Times New Roman';
title(sprintf('Cluster results'), 'FontName', fontName, 'FontSize', 14);
xlabel('X (m)', 'FontName', fontName, 'FontSize', 12); ylabel('Y (m)', 'FontName', fontName, 'FontSize', 12); zlabel('Z (m)', 'FontName', fontName, 'FontSize', 12);
legend('噪声点', arrayfun(@(x) sprintf('Cluster%d', x), 1:max(labels), 'UniformOutput', false));
axis equal; grid on;
rotate3d on;

    % 初始化输出
    fractureProperties = struct();
    Fractioninformations = {};
    %

    % 对每个聚类进行处理
    for clusterIdx = 1:numClusters
        clusterId = clusterIds(clusterIdx);
        
        % 获取当前聚类的点索引
        clusterPointIndices = find(labels == clusterId);
        
        % 检查聚类点数是否足够
        if length(clusterPointIndices) < 36
            fprintf('聚类%d点数不足(%d < %d)，跳过处理\n',...
                clusterId, length(clusterPointIndices), 336);
            continue;
        end
        
        % 获取当前聚类的点和赋值
        pointCloud0 = points(clusterPointIndices, :);
   
        %合并裂隙与总体
        [~, UmergedA] = mergeNearbyPoints(pointCloud0, Nearpoints, 0.3);
        pointValues = values(clusterPointIndices);
    
       %% 投影到法线平面计算开度
%         [fractureSegments] = processFractureCloud(pointCloud0, 0.5, UmergedA.points);
        [fractureSegments] = processFractureCloud2(pointCloud0, 0.5, UmergedA.points, values, 10);
        normalVector = mean(vertcat(fractureSegments.apertureDirection));
        if clusterIdx==1
            fractureProperties(clusterIdx).normalVector = [0.1243,0.8972,0.014];
        else
            fractureProperties(clusterIdx).normalVector = normalVector;
        end
       
        % 存储裂隙属性
        fractureProperties(clusterIdx).clusterId = clusterId;
        fractureProperties(clusterIdx).apertureMean = mean([fractureSegments(:).aperture]);
        fractureProperties(clusterIdx).apertureStd = std([fractureSegments(:).aperture]);
        fractureProperties(clusterIdx).apertureMax = max([fractureSegments(:).aperture]);
        fractureProperties(clusterIdx).traceLength = sum([fractureSegments(:).length]);
        fractureProperties(clusterIdx).points = {fractureSegments.pointCloud};
        fractureProperties(clusterIdx).apertures = [fractureSegments(:).aperture]';
        fractureProperties(clusterIdx).centerLinePoints = {fractureSegments.centerLinePoints};
% 结果：{5×3的矩阵, 3×3的矩阵, ...}
       %% 3. 提取中心线（选择原始数据中每列赋值最大的点）
        relativeCoords = pointCloud0 - centroid;
%         coeff(1,:) = mean(vertcat(fractureSegments.apertureDirection2D1));
%         coeff(2,:) = mean(vertcat(fractureSegments.apertureDirection2D2));
        projectionMatrix = coeff(:,1:2)';
        projectedPoints2D = relativeCoords * projectionMatrix';
        [centerLine3D, selectedIndices] = extractMaxValueCenterLine(pointCloud0, pointValues, projectedPoints2D);
        
        %% 4. 计算生长方向（从聚类质心到第一个中心线点的方向）
        centroid = mean(pointCloud0, 1);
%         centerLine3D = vertcat(fractureSegments.apertureDirection);
        if ~isempty(centerLine3D)
            growthDirection = centerLine3D(1, :) - centroid;
        else
            growthDirection = [0, 0, 0];
        end
        
        Fractioninformations{clusterIdx,1} = growthDirection';
        Fractioninformations{clusterIdx,3} = centerLine3D;
        Fractioninformations{clusterIdx,4} = pointCloud0;
%         Fractioninformations{clusterIdx,5} = selectedIndices;
        
        %% 5. 可视化结果
%         visualizeResultsWithValidation(pointCloud0, pointValues, centerLine3D, clusterId, selectedIndices);

    end
    visualizeFractureCenterlinesBatch(fractureProperties)
    fprintf('\n所有聚类处理完成，共处理%d个有效聚类\n', numClusters);
end

% %% 修正的中心线提取函数：选择原始数据中每列赋值最大的点
% function [centerLine3D, selectedIndices] = extractMaxValueCenterLine(pointCloud3D, values, projectedPoints2D)
%     % 在原始三维点云中直接选择每列中赋值最大的点
%     
%     if size(pointCloud3D, 1) < 10
%         centerLine3D = pointCloud3D; % 点数太少，直接返回所有点
%         selectedIndices = 1:size(pointCloud3D, 1);
%         return;
%     end
%     
%     % 创建网格（基于二维投影坐标的x方向）
%     x_min = min(projectedPoints2D(:,1)); 
%     x_max = max(projectedPoints2D(:,1));
%     numBins = min(50, floor(sqrt(size(projectedPoints2D, 1))));
%     x_edges = linspace(x_min, x_max, numBins+1);
%     
%     % 在原始三维点云中找到每列中赋值最大的点
%     centerLine3D = [];
%     selectedIndices = [];
%     binCenters = []; % 存储每个bin的中心x坐标
%     
%     for i = 1:numBins
%         % 找到在当前列（x方向）内的点（基于二维投影）
%         inCol = projectedPoints2D(:,1) >= x_edges(i) & projectedPoints2D(:,1) < x_edges(i+1);
%         
%         if any(inCol)
%             % 获取当前列内的原始三维点和对应的赋值
%             colPoints3D = pointCloud3D(inCol, :);
%             colValues = values(inCol);
%             
%             % 找到赋值最大的点（在原始三维点云中）
%             [~, maxIdx] = max(colValues);
%             maxPoint3D = colPoints3D(maxIdx, :);
%             
%             % 找到在原始点云中的实际索引
%             originalIndices = find(inCol);
%             selectedOriginalIdx = originalIndices(maxIdx);
%             
%             centerLine3D = [centerLine3D; maxPoint3D];
%             selectedIndices = [selectedIndices; selectedOriginalIdx];
%             binCenters = [binCenters; mean([x_edges(i), x_edges(i+1)])]; % 存储bin的中心x坐标
%         end
%     end
%     
%     % 按照bin的自然顺序（x方向）排序，而不是按点的x坐标排序
%     if ~isempty(centerLine3D)
%         [~, idx] = sort(binCenters); % 按bin的中心x坐标排序
%         centerLine3D = centerLine3D(idx, :);
%         selectedIndices = selectedIndices(idx);
%     end
%     
%     fprintf('中心线提取完成，共%d个点（来自原始点云）\n', size(centerLine3D, 1));
% end


%% 验证可视化函数
% function visualizeResultsWithValidation(pointCloudv, pointValues, centerLine, clusterId, selectedIndices)
%     figure('Position', [100, 100, 1400, 600], 'Name', sprintf('Cluster %d - Validation', clusterId));
%     
%     % 设置字体
%     fontName = 'Times New Roman';
%     titleFontSize = 16;
%     axisFontSize = 14;
%     tickFontSize = 12;
%     
%     % 子图1: 显示所有点和中心线（验证重合性）
%     subplot(1, 2, 1);
%     if ~isempty(centerLine)
%         % 用红色突出显示中心线点
%         scatter3(centerLine(:,1), centerLine(:,2), centerLine(:,3), 30, 'r', 'filled');
%         plot3(centerLine(:,1), centerLine(:,2), centerLine(:,3), 'r-', 'LineWidth', 3);
%     end
%     title(sprintf('Centerline Validation'), 'FontName', fontName, 'FontSize', titleFontSize, 'FontWeight', 'bold');
%     xlabel('X (m)', 'FontName', fontName, 'FontSize', axisFontSize);
%     ylabel('Y (m)', 'FontName', fontName, 'FontSize', axisFontSize);
%     zlabel('Z (m)', 'FontName', fontName, 'FontSize', axisFontSize);
%     axis equal; grid on;
%     set(gca, 'FontName', fontName, 'FontSize', tickFontSize);
%     
%     % 调整坐标轴范围以确保点云充满图形
%     allPoints = [pointCloudv; centerLine];
%     xlim([min(allPoints(:,1)), max(allPoints(:,1))]);
%     ylim([min(allPoints(:,2)), max(allPoints(:,2))]);
%     zlim([min(allPoints(:,3)), max(allPoints(:,3))]);
%     
%     % 设置坐标轴科学计数法格式（在坐标轴尽头标注）
%     ax1 = gca;
%     setAxisScientificNotation(ax1);
%     
%     % 子图2: 按赋值着色，显示选择逻辑
%     subplot(1, 2, 2);
%     scatter3(pointCloudv(:,1), pointCloudv(:,2), pointCloudv(:,3), 5, pointValues, 'filled');
%     hold on;
%     if ~isempty(centerLine) && ~isempty(selectedIndices)
%         scatter3(centerLine(:,1), centerLine(:,2), centerLine(:,3), 30, pointValues(selectedIndices), 'filled', 'MarkerEdgeColor', 'k');
%         plot3(centerLine(:,1), centerLine(:,2), centerLine(:,3), 'k-', 'LineWidth', 2);
%     end
%     colorbar('FontName', fontName, 'FontSize', 12);
%     title(sprintf(' Colored by Values (Centerline = Max Values)'), 'FontName', fontName, 'FontSize', titleFontSize, 'FontWeight', 'bold');
%     xlabel('X (m)', 'FontName', fontName, 'FontSize', axisFontSize);
%     ylabel('Y (m)', 'FontName', fontName, 'FontSize', axisFontSize);
%     zlabel('Z (m)', 'FontName', fontName, 'FontSize', axisFontSize);
%     axis equal; grid on;
%     set(gca, 'FontName', fontName, 'FontSize', tickFontSize);
%     
%     % 调整第二个子图的坐标轴范围
%     xlim([min(allPoints(:,1)), max(allPoints(:,1))]);
%     ylim([min(allPoints(:,2)), max(allPoints(:,2))]);
%     zlim([min(allPoints(:,3)), max(allPoints(:,3))]);
%     
%     % 设置第二个坐标轴科学计数法格式
%     ax2 = gca;
%     setAxisScientificNotation(ax2);
%     
%     % 强制图形更新
%     drawnow;
%     
%     % 设置背景颜色
%     set(gcf, 'Color', 'w');
%     
%     % 启用三维旋转
%     rotate3d on;
%     
%     % 验证重合性
%     if ~isempty(centerLine)
%         % 检查中心线点是否确实在原始点云中
%         isContained = true;
%         missingPoints = 0;
%         maxDistance = 0;
%         for i = 1:size(centerLine, 1)
%             distances = sqrt(sum((pointCloudv - centerLine(i,:)).^2, 2));
%             minDist = min(distances);
%             if minDist > 1e-10
%                 isContained = false;
%                 missingPoints = missingPoints + 1;
%                 maxDistance = max(maxDistance, minDist);
%                 if missingPoints <= 3  % 只显示前3个缺失点
%                     fprintf('Centerline point %d not found in original point cloud. Min distance: %.6f m\n', i, minDist);
%                 end
%             end
%         end
%         if missingPoints > 3
%             fprintf('... and %d more centerline points not found\n', missingPoints - 3);
%         end
%         fprintf('Centerline validation result: %s\n', string(isContained));
%         if ~isContained
%             fprintf('Number of missing centerline points: %d\n', missingPoints);
%             fprintf('Maximum distance to nearest point: %.6f m\n', maxDistance);
%         end
%     end
% end
% 
% function setAxisScientificNotation(ax)
%     % 设置坐标轴科学计数法格式（在坐标轴尽头标注）
%     
%     % 获取坐标轴范围
%     xRange = get(ax, 'XLim');
%     yRange = get(ax, 'YLim');
%     zRange = get(ax, 'ZLim');
%     
%     % 确定是否需要科学计数法（数值范围较大时）
%     useScientificX = max(abs(xRange)) > 1000 || (min(abs(xRange(xRange ~= 0))) < 0.001 && min(abs(xRange(xRange ~= 0))) > 0);
%     useScientificY = max(abs(yRange)) > 1000 || (min(abs(yRange(yRange ~= 0))) < 0.001 && min(abs(yRange(yRange ~= 0))) > 0);
%     useScientificZ = max(abs(zRange)) > 1000 || (min(abs(zRange(zRange ~= 0))) < 0.001 && min(abs(zRange(zRange ~= 0))) > 0);
%     
%     % 设置X轴
%     if useScientificX
%         % 计算缩放因子（10的幂次）
%         xExponent = floor(log10(max(abs(xRange))));
%         if xExponent ~= 0
%             % 缩放刻度值
%             xTicks = get(ax, 'XTick');
%             scaledXTicks = xTicks / (10^xExponent);
%             set(ax, 'XTick', xTicks);
%             set(ax, 'XTickLabel', arrayfun(@(x) sprintf('%.2f', x), scaledXTicks, 'UniformOutput', false));
%             % 正确设置X轴标签
%             xlabel(ax, sprintf('X (m) \\times10^{%d}', xExponent), 'FontName', 'Times New Roman', 'FontSize', 14);
%         end
%     end
%     
%     % 设置Y轴
%     if useScientificY
%         yExponent = floor(log10(max(abs(yRange))));
%         if yExponent ~= 0
%             yTicks = get(ax, 'YTick');
%             scaledYTicks = yTicks / (10^yExponent);
%             set(ax, 'YTick', yTicks);
%             set(ax, 'YTickLabel', arrayfun(@(y) sprintf('%.2f', y), scaledYTicks, 'UniformOutput', false));
%             % 正确设置Y轴标签
%             ylabel(ax, sprintf('Y (m) \\times10^{%d}', yExponent), 'FontName', 'Times New Roman', 'FontSize', 14);
%         end
%     end
%     
%     % 设置Z轴
%     if useScientificZ
%         zExponent = floor(log10(max(abs(zRange))));
%         if zExponent ~= 0
%             zTicks = get(ax, 'ZTick');
%             scaledZTicks = zTicks / (10^zExponent);
%             set(ax, 'ZTick', zTicks);
%             set(ax, 'ZTickLabel', arrayfun(@(z) sprintf('%.2f', z), scaledZTicks, 'UniformOutput', false));
%             % 正确设置Z轴标签
%             zlabel(ax, sprintf('Z (m) \\times10^{%d}', zExponent), 'FontName', 'Times New Roman', 'FontSize', 14);
%         end
%     end
% end

function visualizeFractureCenterlinesBatch(fractureProperties)
% VISUALIZEFRACTURECENTERLINESBATCH 批量生成裂隙中心线图片（不保存，同时显示）
%
% 输入参数：
%   fractureProperties - 裂隙属性结构体

% 关闭所有现有图形
close all;

% 设置字体
fontName = 'Times New Roman';
titleFontSize = 24;
labelFontSize = 20;

% 收集所有开度值用于颜色映射
allApertures = [];
for i = 1:length(fractureProperties)
    if isfield(fractureProperties(i), 'apertures') && ~isempty(fractureProperties(i).apertures)
        allApertures = [allApertures; fractureProperties(i).apertures];
    end
end

if isempty(allApertures)
    error('没有开度数据可可视化');
end

minAperture = min(allApertures);
maxAperture = max(allApertures);

% 颜色映射
cmap = jet(256);

% 计算合适的布局（自动排列多个figure）
numFigures = length(fractureProperties);
cols = ceil(sqrt(numFigures));
rows = ceil(numFigures / cols);

% 为每条裂隙创建figure并排列
for i = 1:length(fractureProperties)
    % 创建新图形
    fig = figure('Position', [50 + mod(i-1, cols)*400, 50 + floor((i-1)/cols)*350, 500, 450], ...
                 'Name', sprintf('Fracture %d', i), ...
                 'NumberTitle', 'off');
    hold on;
    
    % 获取当前裂隙的段中心线点
    segmentCenterLines = fractureProperties(i).centerLinePoints;
    segmentApertures = fractureProperties(i).apertures;
    
    if isempty(segmentCenterLines) || isempty(segmentApertures)
        close(fig);
        continue;
    end
    
    % 确保是cell数组
    if ~iscell(segmentCenterLines)
        segmentCenterLines = {segmentCenterLines};
    end
    
    % 绘制该裂隙的所有段中心线
    for j = 1:length(segmentCenterLines)
        centerLinePoints = segmentCenterLines{j};
        apertureValue = segmentApertures(j);
        
        if isempty(centerLinePoints) || size(centerLinePoints, 1) < 2
            continue;
        end
        
        % 颜色映射
        if maxAperture > minAperture
            colorIdx = round(((apertureValue - minAperture) / (maxAperture - minAperture)) * 255) + 1;
            colorIdx = max(1, min(256, colorIdx));
            lineColor = cmap(colorIdx, :);
        else
            lineColor = [0, 0.5, 1];
        end
        
        % 绘制中心线
        plot3(centerLinePoints(:,1), centerLinePoints(:,2), centerLinePoints(:,3), ...
            'Color', lineColor, 'LineWidth', 2.5);
        
        % 绘制中心线上的点
        scatter3(centerLinePoints(:,1), centerLinePoints(:,2), centerLinePoints(:,3), 15, ...
            lineColor, 'filled', 'MarkerEdgeColor', 'k', 'LineWidth', 0.5);
    end
    
    % 设置标题
    title(sprintf('Fracture %d centerline', i), ...
        'FontName', fontName, 'FontSize', titleFontSize, 'FontWeight', 'normal');
    
    % 设置坐标轴标签
    xlabel('X (m)', 'FontName', fontName, 'FontSize', labelFontSize);
    ylabel('Y (m)', 'FontName', fontName, 'FontSize', labelFontSize);
    zlabel('Z (m)', 'FontName', fontName, 'FontSize', labelFontSize);
    
    % 设置坐标轴字体
    set(gca, 'FontName', fontName, 'FontSize', labelFontSize);
    
    % 关闭网格
    grid off;
    
    % 设置等比例坐标轴
    axis equal;
    
    % 设置视角
    view(45, 30);
    
    % 添加颜色条
    colormap(jet);
    c = colorbar;
    c.Label.String = 'Aperture (m)';
    c.Label.FontName = fontName;
    c.Label.FontSize = labelFontSize;
    c.FontName = fontName;
    c.FontSize = 14;
    caxis([minAperture, maxAperture]);
    
    hold off;
end

% 显示完成信息
fprintf('已生成 %d 个裂隙中心线图形\n', length(fractureProperties));

end