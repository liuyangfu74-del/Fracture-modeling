function [fractureProperties, Fractioninformations] = extractMaxValueLine2(points, value, ~, ~,Nearpoints)
    % 生成裂隙等边三角网格
    % 输入: points - 裂隙点云坐标(N×3), values - 点的赋值(N×1)
    %DBSCAN裂隙分组
%     labels = dbscan(points, esplain, minpt);
     labels = ones(length(points),1);
    % 获取聚类数量（排除噪声点，标签为-1）
    clusterIds = unique(labels);
    clusterIds = clusterIds(clusterIds ~= -1);
    numClusters = length(clusterIds);
    values = (value - min(value)) / (max(value) - min(value));
% figure;
% colors = lines(max(labels)+1);
% for i = 1:max(labels)+1
%     if i == 1
%         idx = labels == -1; % 噪声点
%         color = [0.5 0.5 0.5]; % 灰色
%     else
%         idx = labels == (i-1);
%         color = colors(i-1,:);
%     end
%     scatter3(points(idx,1), points(idx,2), points(idx,3), 5, color, 'filled');
%     hold on;
% end
% fontName = 'Times New Roman';
% title(sprintf('Cluster results'), 'FontName', fontName, 'FontSize', 14);
% xlabel('X (m)', 'FontName', fontName, 'FontSize', 12); ylabel('Y (m)', 'FontName', fontName, 'FontSize', 12); zlabel('Z (m)', 'FontName', fontName, 'FontSize', 12);
% legend('噪声点', arrayfun(@(x) sprintf('Cluster%d', x), 1:max(labels), 'UniformOutput', false));
% axis equal; grid on;
% rotate3d on;

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
        [coeff,~,~] = pca(UmergedA.points);
        pointValues = values(clusterPointIndices);
    
       %% 投影到法线平面计算开度
        [fractureSegments] = processFractureCloud(pointCloud0, 0.5, UmergedA.points);
        
        normalVector = mean(vertcat(fractureSegments.apertureDirection));
%         if clusterIdx==1
%             fractureProperties(clusterIdx).normalVector = [0.1243,0.8972,0.014];
%         else
            fractureProperties(clusterIdx).normalVector = normalVector;
%         end
       
        % 存储裂隙属性
        fractureProperties(clusterIdx).clusterId = clusterId;
        fractureProperties(clusterIdx).apertureMean = mean([fractureSegments(:).aperture]);
        fractureProperties(clusterIdx).apertureStd = std([fractureSegments(:).aperture]);
        fractureProperties(clusterIdx).apertureMax = max([fractureSegments(:).aperture]);
        fractureProperties(clusterIdx).traceLength = sum([fractureSegments(:).length]);
        fractureProperties(clusterIdx).maxValueMean = mean(pointValues);
        fractureProperties(clusterIdx).maxValueStd = std(pointValues);
        fractureProperties(clusterIdx).points = {fractureSegments.pointCloud};
        fractureProperties(clusterIdx).apertures = [fractureSegments(:).aperture]';
        fractureProperties(clusterIdx).allpoints = vertcat(fractureSegments.pointCloud);

       %% 3. 提取中心线（选择原始数据中每列赋值最大的点）
        centroid = mean(pointCloud0, 1);
        relativeCoords = pointCloud0 - centroid;
        projectionMatrix = coeff(:,1:2)';
        projectedPoints2D = relativeCoords * projectionMatrix';
        [centerLine3D, selectedIndices] = extractMaxValueCenterLine(pointCloud0, pointValues, projectedPoints2D);
        
        %% 4. 计算生长方向（从聚类质心到第一个中心线点的方向）
        if ~isempty(centerLine3D)
            growthDirection = centerLine3D(1, :) - centroid;
        else
            growthDirection = [0, 0, 0];
        end
        
        Fractioninformations{clusterIdx,1} = growthDirection';
        Fractioninformations{clusterIdx,3} = centerLine3D;
        Fractioninformations{clusterIdx,4} = pointCloud0;
        Fractioninformations{clusterIdx,5} = selectedIndices;
        
        %% 5. 可视化结果
%         visualizeResultsWithValidation(pointCloud0, pointValues, centerLine3D, clusterId, selectedIndices);
%         l = [0.2,0.70,0.1];
%         visualizeNormalAngles(l, fractureSegments)
    end
    fprintf('\n所有聚类处理完成，共处理%d个有效聚类\n', numClusters);
end

%% 修正的中心线提取函数：选择原始数据中每列赋值最大的点
function [centerLine3D, selectedIndices] = extractMaxValueCenterLine(pointCloud3D, values, projectedPoints2D)
    % 在原始三维点云中直接选择每列中赋值最大的点
    
    if size(pointCloud3D, 1) < 10
        centerLine3D = pointCloud3D; % 点数太少，直接返回所有点
        selectedIndices = 1:size(pointCloud3D, 1);
        return;
    end
    
    % 创建网格（基于二维投影坐标的x方向）
    x_min = min(projectedPoints2D(:,1)); 
    x_max = max(projectedPoints2D(:,1));
%     numBins = min(50, floor(sqrt(size(projectedPoints2D, 1))));
    numBins = floor((x_max-x_min)/0.1);
    x_edges = linspace(x_min, x_max, numBins+1);
    
    % 在原始三维点云中找到每列中赋值最大的点
    centerLine3D = [];
    selectedIndices = [];
    binCenters = []; % 存储每个bin的中心x坐标
    
    for i = 1:numBins
        % 找到在当前列（x方向）内的点（基于二维投影）
        inCol = projectedPoints2D(:,1) >= x_edges(i) & projectedPoints2D(:,1) < x_edges(i+1);
        
        if any(inCol)
            % 获取当前列内的原始三维点和对应的赋值
            colPoints3D = pointCloud3D(inCol, :);
            colValues = values(inCol);
            
            % 找到赋值最大的点（在原始三维点云中）
            [~, maxIdx] = max(colValues);
            maxPoint3D = colPoints3D(maxIdx, :);
            
            % 找到在原始点云中的实际索引
            originalIndices = find(inCol);
            selectedOriginalIdx = originalIndices(maxIdx);
            
            centerLine3D = [centerLine3D; maxPoint3D];
            selectedIndices = [selectedIndices; selectedOriginalIdx];
            binCenters = [binCenters; mean([x_edges(i), x_edges(i+1)])]; % 存储bin的中心x坐标
        end
    end
    
    % 按照bin的自然顺序（x方向）排序，而不是按点的x坐标排序
    if ~isempty(centerLine3D)
        [~, idx] = sort(binCenters); % 按bin的中心x坐标排序
        centerLine3D = centerLine3D(idx, :);
        selectedIndices = selectedIndices(idx);
    end
    
    fprintf('中心线提取完成，共%d个点（来自原始点云）\n', size(centerLine3D, 1));
end

%% 验证可视化函数
function visualizeResultsWithValidation(pointCloudv, pointValues, centerLine, ~, selectedIndices)
    figure('Position', [100, 100, 1400, 600]);
    a = [-0.9,0,0];
    % 设置字体
    fontName = 'Times New Roman';
    titleFontSize = 16;
    axisFontSize = 14;
    tickFontSize = 12;
    
%     % 子图1: 显示所有点和中心线（验证重合性）
%     subplot(1, 2, 1);
    if ~isempty(centerLine)
        % 用红色突出显示中心线点
        scatter3(centerLine(:,1), centerLine(:,2), centerLine(:,3), 30,  'filled');
        plot3(centerLine(:,1), centerLine(:,2), centerLine(:,3), 'r-', 'LineWidth', 3);
    end
%     title(sprintf('Centerline Validation'), 'FontName', fontName, 'FontSize', titleFontSize, 'FontWeight', 'bold');
    xlabel('X (m)', 'FontName', fontName, 'FontSize', axisFontSize);
    ylabel('Y (m)', 'FontName', fontName, 'FontSize', axisFontSize);
    zlabel('Z (m)', 'FontName', fontName, 'FontSize', axisFontSize);
    axis equal; grid on;
    set(gca, 'FontName', fontName, 'FontSize', tickFontSize);
    
    % 调整坐标轴范围以确保点云充满图形
    allPoints = [pointCloudv; centerLine];
%     xlim([min(allPoints(:,1)), max(allPoints(:,1))]);
%     ylim([min(allPoints(:,2)), max(allPoints(:,2))]);
%     zlim([min(allPoints(:,3)), max(allPoints(:,3))]);
%     
%     % 设置坐标轴科学计数法格式（在坐标轴尽头标注）
%     ax1 = gca;
%     setAxisScientificNotation(ax1);
    grid off;
    axis off;
    view(a)
    figure('Position', [100, 100, 1400, 600]);
    scatter3(pointCloudv(:,1), pointCloudv(:,2), pointCloudv(:,3), 5, pointValues, 'filled');
    hold on;
    if ~isempty(centerLine) && ~isempty(selectedIndices)
        scatter3(centerLine(:,1), centerLine(:,2), centerLine(:,3), 30, pointValues(selectedIndices), 'filled', 'MarkerEdgeColor', 'k');
        plot3(centerLine(:,1), centerLine(:,2), centerLine(:,3), 'k-', 'LineWidth', 2);
    end
    colorbar('FontName', fontName, 'FontSize', 24);
%     title(sprintf(' Colored by Values (Centerline = Max Values)'), 'FontName', fontName, 'FontSize', titleFontSize, 'FontWeight', 'bold');
    xlabel('X (m)', 'FontName', fontName, 'FontSize', axisFontSize);
    ylabel('Y (m)', 'FontName', fontName, 'FontSize', axisFontSize);
    zlabel('Z (m)', 'FontName', fontName, 'FontSize', axisFontSize);
    axis equal; grid on;
    set(gca, 'FontName', fontName, 'FontSize', tickFontSize);
    grid off;
    axis off;
    % 调整第二个子图的坐标轴范围
    xlim([min(allPoints(:,1)), max(allPoints(:,1))]);
    ylim([min(allPoints(:,2)), max(allPoints(:,2))]);
    zlim([min(allPoints(:,3)), max(allPoints(:,3))]);
    
%     % 设置第二个坐标轴科学计数法格式
%     ax2 = gca;
%     setAxisScientificNotation(ax2);
    
%     % 强制图形更新
%     drawnow;
    
%     % 设置背景颜色
%     set(gcf, 'Color', 'w');
    
%     % 启用三维旋转
%     rotate3d on;
    view(a)
    % 验证重合性
    if ~isempty(centerLine)
        % 检查中心线点是否确实在原始点云中
        isContained = true;
        missingPoints = 0;
        maxDistance = 0;
        for i = 1:size(centerLine, 1)
            distances = sqrt(sum((pointCloudv - centerLine(i,:)).^2, 2));
            minDist = min(distances);
            if minDist > 1e-10
                isContained = false;
                missingPoints = missingPoints + 1;
                maxDistance = max(maxDistance, minDist);
                if missingPoints <= 3  % 只显示前3个缺失点
                    fprintf('Centerline point %d not found in original point cloud. Min distance: %.6f m\n', i, minDist);
                end
            end
        end
        if missingPoints > 3
            fprintf('... and %d more centerline points not found\n', missingPoints - 3);
        end
        fprintf('Centerline validation result: %s\n', string(isContained));
        if ~isContained
            fprintf('Number of missing centerline points: %d\n', missingPoints);
            fprintf('Maximum distance to nearest point: %.6f m\n', maxDistance);
        end
    end
end

function setAxisScientificNotation(ax)
    % 设置坐标轴科学计数法格式（在坐标轴尽头标注）
    
    % 获取坐标轴范围
    xRange = get(ax, 'XLim');
    yRange = get(ax, 'YLim');
    zRange = get(ax, 'ZLim');
    
    % 确定是否需要科学计数法（数值范围较大时）
    useScientificX = max(abs(xRange)) > 1000 || (min(abs(xRange(xRange ~= 0))) < 0.001 && min(abs(xRange(xRange ~= 0))) > 0);
    useScientificY = max(abs(yRange)) > 1000 || (min(abs(yRange(yRange ~= 0))) < 0.001 && min(abs(yRange(yRange ~= 0))) > 0);
    useScientificZ = max(abs(zRange)) > 1000 || (min(abs(zRange(zRange ~= 0))) < 0.001 && min(abs(zRange(zRange ~= 0))) > 0);
    
    % 设置X轴
    if useScientificX
        % 计算缩放因子（10的幂次）
        xExponent = floor(log10(max(abs(xRange))));
        if xExponent ~= 0
            % 缩放刻度值
            xTicks = get(ax, 'XTick');
            scaledXTicks = xTicks / (10^xExponent);
            set(ax, 'XTick', xTicks);
            set(ax, 'XTickLabel', arrayfun(@(x) sprintf('%.2f', x), scaledXTicks, 'UniformOutput', false));
            % 正确设置X轴标签
            xlabel(ax, sprintf('X (m) \\times10^{%d}', xExponent), 'FontName', 'Times New Roman', 'FontSize', 14);
        end
    end
    
    % 设置Y轴
    if useScientificY
        yExponent = floor(log10(max(abs(yRange))));
        if yExponent ~= 0
            yTicks = get(ax, 'YTick');
            scaledYTicks = yTicks / (10^yExponent);
            set(ax, 'YTick', yTicks);
            set(ax, 'YTickLabel', arrayfun(@(y) sprintf('%.2f', y), scaledYTicks, 'UniformOutput', false));
            % 正确设置Y轴标签
            ylabel(ax, sprintf('Y (m) \\times10^{%d}', yExponent), 'FontName', 'Times New Roman', 'FontSize', 14);
        end
    end
    
    % 设置Z轴
    if useScientificZ
        zExponent = floor(log10(max(abs(zRange))));
        if zExponent ~= 0
            zTicks = get(ax, 'ZTick');
            scaledZTicks = zTicks / (10^zExponent);
            set(ax, 'ZTick', zTicks);
            set(ax, 'ZTickLabel', arrayfun(@(z) sprintf('%.2f', z), scaledZTicks, 'UniformOutput', false));
            % 正确设置Z轴标签
            zlabel(ax, sprintf('Z (m) \\times10^{%d}', zExponent), 'FontName', 'Times New Roman', 'FontSize', 14);
        end
    end
end


function visualizeNormalAngles(l, fractureSegments)
    
    % 设置字体
    fontName = 'Times New Roman';
    titleFontSize = 24;
    labelFontSize = 22;
    legendFontSize = 20;
    tickFontSize = 20;
    textFontSize = 18;
    
    % 确保l是单位向量
    l = l / norm(l);
    
    % ==================== 提取分段法向量 ====================
    n_segments = length(fractureSegments);
    segment_normals = zeros(n_segments, 3);
    segment_centers = zeros(n_segments, 3);
    segment_apertures = zeros(n_segments, 1);
    
    for i = 1:n_segments
        if isfield(fractureSegments(i), 'apertureDirection') && ...
           ~isempty(fractureSegments(i).apertureDirection)
            segment_normals(i, :) = fractureSegments(i).apertureDirection;
            segment_normals(i, :) = segment_normals(i, :) / norm(segment_normals(i, :));
        end
        
        if isfield(fractureSegments(i), 'centerPoint')
            segment_centers(i, :) = fractureSegments(i).centerPoint;
        end
        
        if isfield(fractureSegments(i), 'aperture')
            segment_apertures(i) = fractureSegments(i).aperture * 1000; % 转换为mm
        end
    end
    
    % 计算与参考法向量l的角度差
    angles = acosd(abs(segment_normals * l')); % 取绝对值处理方向 ambiguity
    angles = min(angles, 180 - angles); % 确保角度在0-90度范围内
    
    % 计算均值向量
    mean_normal = mean(segment_normals, 1);
    mean_normal = mean_normal / norm(mean_normal);
    mean_angle = acosd(abs(mean_normal * l'));
    mean_angle = min(mean_angle, 180 - mean_angle);
    
    % ==================== 图1：3D可视化 ====================
    figure('Position', [50, 50, 1400, 600], 'Color', 'white');

    % 绘制裂隙点云（半透明灰色）
    all_points = vertcat(fractureSegments.pointCloud);
    scatter3(all_points(:,1), all_points(:,2), all_points(:,3), 5, ...
        [0.7, 0.7, 0.7], 'filled', 'MarkerFaceAlpha', 0.3);
    hold on;
    
    % 绘制参考法向量l（红色粗线）
    scale = mean(range(all_points)) * 0.3;
    quiver3(mean(all_points(:,1)), mean(all_points(:,2)), mean(all_points(:,3)), ...
        l(1)*scale, l(2)*scale, l(3)*scale, ...
        'r', 'LineWidth', 4, 'MaxHeadSize', 0.8, 'DisplayName', 'Reference l');
    
    % 绘制均值向量（蓝色粗线）
    quiver3(mean(all_points(:,1)), mean(all_points(:,2)), mean(all_points(:,3)), ...
        mean_normal(1)*scale, mean_normal(2)*scale, mean_normal(3)*scale, ...
        'b', 'LineWidth', 4, 'MaxHeadSize', 0.8, 'DisplayName', 'Mean normal');
    
    % 绘制每个分段的法向量，颜色表示角度差
    % 创建颜色映射
    cmap = jet(256);
    
    for i = 1:n_segments
        if norm(segment_normals(i, :)) > 0
            % 根据角度差确定颜色索引（确保在1-256范围内）
            color_idx = max(1, min(256, round(angles(i)/90 * 255) + 1));
            color = cmap(color_idx, :);
            
            % 绘制从分段中心出发的法向量
            quiver3(segment_centers(i,1), segment_centers(i,2), segment_centers(i,3), ...
                segment_normals(i,1)*scale*0.5, segment_normals(i,2)*scale*0.5, ...
                segment_normals(i,3)*scale*0.5, ...
                'Color', color, 'LineWidth', 2, 'MaxHeadSize', 0.5);
        end
    end
    
    % 设置坐标轴
    set(gca, 'FontName', fontName, 'FontSize', tickFontSize, 'LineWidth', 1.5);
    title('Calculation results of direction', ...
        'FontName', fontName, 'FontSize', titleFontSize, 'FontWeight', 'normal');
    
    legend('Location', 'best', 'FontName', fontName, 'FontSize', legendFontSize);
    grid off;
    axis equal;
    view(45, 30);
    
    % 添加颜色条
    colorbarHandle = colorbar;
    set(colorbarHandle, 'FontName', fontName, 'FontSize', tickFontSize);
    ylabel(colorbarHandle, 'Angle to l (°)', 'FontName', fontName, 'FontSize', labelFontSize-2);
    caxis([0, 90]);
    colormap(gca, jet);
    
    grid off;
    axis equal;
    axis off;
    
    % ==================== 图2：角度差曲线 ====================
    figure('Position', [100, 100, 1200, 700], 'Color', 'white');
    
    % 分段序号
    segment_idx = 1:n_segments;
    
    % 绘制角度差曲线（黑色）
    plot(segment_idx, angles, 'k-', 'LineWidth', 3, 'DisplayName', 'Segment angles');
    hold on;
    
    % 绘制y=0参考线（大红色）
    plot([0, n_segments+1], [0, 0], 'r-', 'LineWidth', 4, 'DisplayName', 'y = 0 (perfect alignment)');
    
    % 绘制均值角度线
    plot([0, n_segments+1], [mean_angle, mean_angle], 'b--', 'LineWidth', 3, ...
        'DisplayName', sprintf('Mean angle = %.2f°', mean_angle));
    
    % 填充均值上下区域（表示波动）
    fill([segment_idx, fliplr(segment_idx)], ...
         [angles', fliplr(ones(1, n_segments)*mean_angle)], ...
         'b', 'FaceAlpha', 0.1, 'EdgeColor', 'none');
    
    % 标记最大偏差
    [max_angle, max_idx] = max(angles);
    plot(max_idx, max_angle, 'ro', 'MarkerSize', 12, 'LineWidth', 2);
    text(max_idx+0.5, max_angle, sprintf('Max: %.1f°', max_angle), ...
        'FontName', fontName, 'FontSize', textFontSize, 'Color', 'r');
    
    % 标记最小偏差
    [min_angle, min_idx] = min(angles);
    plot(min_idx, min_angle, 'go', 'MarkerSize', 12, 'LineWidth', 2);
    text(min_idx+0.5, min_angle, sprintf('Min: %.1f°', min_angle), ...
        'FontName', fontName, 'FontSize', textFontSize, 'Color', 'g');
    
    % 设置坐标轴
    set(gca, 'FontName', fontName, 'FontSize', tickFontSize, 'LineWidth', 1.5);
    xlabel('Segment index (along outcrop structural plane)', 'FontName', fontName, 'FontSize', labelFontSize);
    ylabel('Angle to structural plane direction(°)', 'FontName', fontName, 'FontSize', labelFontSize);
    title('Normal angle variation', ...
        'FontName', fontName, 'FontSize', titleFontSize, 'FontWeight', 'normal');
    
    % 设置x轴范围
    xlim([0, n_segments+1]);

    legend('Location', 'best', 'FontName', fontName, 'FontSize', legendFontSize);
    grid off
    
end