% function [fractureSegments] = processFractureCloud2(fractureCloud, stepSize, UmergedA,values)
% % PROCESSFRACTURECLOUD 处理岩石裂隙点云数据，分行计算开度并提取中心线
% %
% % 输入参数：
% %   fractureCloud - 裂隙点云数据，N×3矩阵 [x, y, z]
% %   stepSize - 沿延伸方向的分段步长
% %   UmergedA - PCA降采样后的点云（用于确定整体方向）
% %   direction - 裂隙延伸方向向量 [dx, dy, dz]（可选）
% %   values - 每个点的赋值，N×1矩阵（用于中心线提取）
% %
% % 输出参数：
% %   fractureSegments - 结构体数组，包含每个分段的信息
% 
% 
% % 使用PCA确定主要延伸方向
% [coeff, ~, ~] = pca(UmergedA);
% direction = coeff(:,1)'; % 第一主成分方向为延伸方向
% 
% % 构建整体局部坐标系
% xAxis = direction(:) / norm(direction); % 延伸方向
% 
% % 对UmergedA进行PCA，确定整体坐标系的y轴和z轴
% [coeff_all, ~, ~] = pca(UmergedA);
% yAxis = coeff_all(:,2); % 第二主成分方向（横向）
% zAxis = coeff_all(:,3); % 第三主成分方向（法向）
% 
% % 构建变换矩阵：从世界坐标系到整体局部坐标系
% transformMatrix = [xAxis, yAxis, zAxis]';
% center = mean(fractureCloud, 1);
% centeredPoints = fractureCloud - center;
% 
% % 转换到整体局部坐标系
% localCoords = centeredPoints * transformMatrix';
% 
% % 沿着延伸方向（x轴）进行分段
% xCoords = localCoords(:,1);
% minX = min(xCoords);
% maxX = max(xCoords);
% totalLength = maxX - minX;
% 
% % 确定分段数量
% numSegments = ceil(totalLength / stepSize);
% fprintf('裂隙总长度: %.3f m, 分段数量: %d\n', totalLength, numSegments);
% 
% % 初始化分段结构体 - 精简输出字段
% fractureSegments = struct(...
%     'startPos', {}, ...
%     'endPos', {}, ...
%     'length', {}, ...
%     'aperture', {}, ...              % 最终开度（立方根均值）
%     'apertureDirection', {}, ...      % 开度方向（法向量）
%     'centerLinePoints', {}, ...       % 中心线点（每行一个）
%     'centerLineValues', {}, ...       % 中心线点对应的values
%     'pointCloud', {}, ...             % 分段点云（可选，如需节省空间可删除）
%     'centerPoint', {}, ...            % 分段中心点
%     'numPoints', {} ...               % 点数
% );
% 
% % 创建分段
% for i = 1:numSegments
%     % 计算当前分段的x坐标范围
%     segStart = minX + (i-1) * stepSize;
%     segEnd = min(segStart + stepSize, maxX);
%     
%     % 找出在当前分段内的点
%     inSegment = (xCoords >= segStart) & (xCoords <= segEnd);
%     segmentIndices = find(inSegment);
%     
%     if isempty(segmentIndices)
%         continue; % 跳过空分段
%     end
%     
%     % 提取当前分段的点云和对应的values
%     segmentPoints = fractureCloud(segmentIndices, :);
%     segmentValues = values(segmentIndices);
%     
%     % 对当前分段进行PCA，建立分段局部坐标系
%     [coeff_segment, ~, latent_segment] = pca(segmentPoints);
%     
%     % 确定延伸方向（与整体延伸方向最接近的主成分）
%     dotProducts = abs(coeff_segment' * xAxis);
%     [~, extendIdx] = max(dotProducts);
%     
%     % 确定横向方向和开度方向
%     otherIndices = setdiff(1:3, extendIdx);
%     
%     % 从剩余两个主成分中，横向方向取方差较大的，开度方向取方差较小的
%     [~, sortIdx] = sort(latent_segment(otherIndices), 'descend');
%     lateralIdx = otherIndices(sortIdx(1));      % 横向方向（方差较大）
%     apertureIdx = otherIndices(sortIdx(2));     % 开度方向（方差较小）
%     
%     % 获取三个方向的单位向量
%     xAxis_seg = coeff_segment(:, extendIdx);     % 分段延伸方向
%     yAxis_seg = coeff_segment(:, lateralIdx);    % 分段横向方向
%     zAxis_seg = coeff_segment(:, apertureIdx);   % 分段开度方向（法向）
%     
%     % 确保坐标系是右手系
%     if dot(cross(xAxis_seg, yAxis_seg), zAxis_seg) < 0
%         zAxis_seg = -zAxis_seg;
%     end
%     
%     % 构建分段局部坐标系的变换矩阵
%     transformMatrix_seg = [xAxis_seg, yAxis_seg, zAxis_seg]';
%     center_seg = mean(segmentPoints, 1);
%     
%     % 将当前分段的点转换到分段局部坐标系
%     segmentLocalCoords = (segmentPoints - center_seg) * transformMatrix_seg';
%     
%     % 获取横向坐标和开度坐标
%     y_coords = segmentLocalCoords(:,2);  % 横向坐标
%     z_coords = segmentLocalCoords(:,3);  % 开度坐标
%     
%     % 沿横向方向分行
%     y_min = min(y_coords);
%     y_max = max(y_coords);
%     
%     % 根据点数和横向宽度确定行数
%     idealNumRows = floor(sqrt(length(segmentIndices)));
%     maxRows = floor((y_max - y_min) / 0.01); % 最小行宽0.01m
%     numRows = min(idealNumRows, maxRows);
%     numRows = max(numRows, 1); % 至少1行
%     
%     if numRows > 1
%         y_edges = linspace(y_min, y_max, numRows+1);
%     else
%         y_edges = [y_min, y_max];
%     end
%     
%     % 初始化该分段的开度数组和中心线
%     apertureProfile = [];
%     centerLinePoints = [];
%     centerLineValues = [];
%     
%     % 对每一行进行处理
%     for j = 1:numRows
%         % 找出在当前行内的点
%         if j < numRows
%             inRow = (y_coords >= y_edges(j)) & (y_coords < y_edges(j+1));
%         else
%             inRow = (y_coords >= y_edges(j)) & (y_coords <= y_edges(j+1));
%         end
%         
%         rowIndices = find(inRow);
%         
%         if length(rowIndices) >= 3  % 至少3个点才计算
%             % 获取该行的z坐标
%             row_z = z_coords(inRow);
%             
%             % 计算该行的开度（z方向的范围）
%             rowAperture = range(row_z);
%             
%             % 获取该行对应的原始三维点和values
%             rowPoints3D = segmentPoints(inRow, :);
%             rowValues = segmentValues(inRow);
%             
%             % 找到该行中values最大的点
%             [maxValue, maxIdx] = max(rowValues);
%             maxPoint = rowPoints3D(maxIdx, :);
%             
%             % 存储结果
%             apertureProfile = [apertureProfile; rowAperture];
%             centerLinePoints = [centerLinePoints; maxPoint];
%             centerLineValues = [centerLineValues; maxValue];
%         end
%     end
%     
%     % 计算该分段的最终开度和中心线
%     if ~isempty(apertureProfile)
%         % 1. 最终开度 = 所有行开度的立方根均值
%         finalAperture = mean(apertureProfile .^ (1/3)) .^ 3;
%         
%         % 2. 开度方向 = 该段的法向量 (zAxis_seg)
%         apertureDirection = zAxis_seg';
%         
%         % 3. 中心线点（按横向排序，但这里不需要保留顺序细节）
%         % 可以保留所有中心线点，或者取均值/中位数？根据您后续需求
%         % 这里保留所有中心线点，供extractMaxValueLine使用
%     else
%         % 如果没有有效的行，使用简化方法
%         finalAperture = range(z_coords);
%         apertureDirection = zAxis_seg';
%         
%         % 取该段中values最大的点作为中心线
%         [~, maxIdx] = max(segmentValues);
%         centerLinePoints = segmentPoints(maxIdx, :);
%         centerLineValues = segmentValues(maxIdx);
%     end
%     
%     % 计算分段长度
%     segmentLength = segEnd - segStart;
%     
%     % 计算分段中心点
%     centerPoint = mean(segmentPoints, 1);
%     
%     % 存储精简后的分段信息
%     fractureSegments(i).startPos = segStart;
%     fractureSegments(i).endPos = segEnd;
%     fractureSegments(i).length = segmentLength;
%     fractureSegments(i).aperture = finalAperture;
%     fractureSegments(i).apertureDirection = apertureDirection;
%     fractureSegments(i).centerLinePoints = centerLinePoints;
%     fractureSegments(i).centerLineValues = centerLineValues;
%     fractureSegments(i).pointCloud = segmentPoints;      % 如需节省空间可删除此行
%     fractureSegments(i).centerPoint = centerPoint;
%     fractureSegments(i).numPoints = size(segmentPoints, 1);
%     
%     % 显示进度
%     if mod(i, 10) == 0 || i == numSegments
%         fprintf('分段 %d/%d 处理完成, 有效行数: %d, 开度: %.4f m\n', ...
%             i, numSegments, length(apertureProfile), finalAperture);
%     end
% end
% 
% % 移除空的分段
% fractureSegments = fractureSegments(~cellfun(@isempty, {fractureSegments.startPos}));
% 
% % 显示整体处理结果
% fprintf('\n======= 处理完成 =======\n');
% fprintf('有效分段数: %d\n', length(fractureSegments));
% 
% if ~isempty(fractureSegments)
%     allApertures = [fractureSegments.aperture];
%     fprintf('开度均值: %.4f m\n', mean(allApertures));
%     fprintf('开度标准差: %.4f m\n', std(allApertures));
%     fprintf('开度最大值: %.4f m\n', max(allApertures));
%     fprintf('开度最小值: %.4f m\n', min(allApertures));
% end
% 
% fprintf('总迹长: %.3f m\n', totalLength);
% 
% end
function [fractureSegments] = processFractureCloud2(fractureCloud, stepSize, UmergedA, values, extractInterval)
% PROCESSFRACTURECLOUD 处理岩石裂隙点云数据，分行计算开度并提取中心线
%
% 输入参数：
%   fractureCloud - 裂隙点云数据，N×3矩阵 [x, y, z]
%   stepSize - 沿延伸方向的分段步长
%   UmergedA - PCA降采样后的点云（用于确定整体方向）
%   values - 每个点的赋值，N×1矩阵（用于中心线提取）
%   extractInterval - 隔行提取间隔（可选，默认=2，表示每2列取1列）
%
% 输出参数：
%   fractureSegments - 结构体数组，包含每个分段的信息

% 设置默认隔行间隔
if nargin < 5
    extractInterval = 2; % 默认每2列取1列
end

% 使用PCA确定主要延伸方向
[coeff, ~, ~] = pca(UmergedA);
direction = coeff(:,1)'; % 第一主成分方向为延伸方向

% 构建整体局部坐标系
xAxis = direction(:) / norm(direction); % 延伸方向

% 对UmergedA进行PCA，确定整体坐标系的y轴和z轴
[coeff_all, ~, ~] = pca(UmergedA);
yAxis = coeff_all(:,2); % 第二主成分方向（横向）
zAxis = coeff_all(:,3); % 第三主成分方向（法向）

% 构建变换矩阵：从世界坐标系到整体局部坐标系
transformMatrix = [xAxis, yAxis, zAxis]';
center = mean(fractureCloud, 1);
centeredPoints = fractureCloud - center;

% 转换到整体局部坐标系
localCoords = centeredPoints * transformMatrix';

% 沿着延伸方向（x轴）进行分段
xCoords = localCoords(:,1);
minX = min(xCoords);
maxX = max(xCoords);
totalLength = maxX - minX;

% 确定分段数量
numSegments = ceil(totalLength / stepSize);
fprintf('裂隙总长度: %.3f m, 分段数量: %d\n', totalLength, numSegments);

% 初始化分段结构体
fractureSegments = struct(...
    'startPos', {}, ...
    'endPos', {}, ...
    'length', {}, ...
    'aperture', {}, ...              % 最终开度（立方根均值）
    'apertureDirection', {}, ...      % 开度方向（法向量）
    'centerLinePoints', {}, ...       % 中心线点（每列一个）
    'centerLineValues', {}, ...       % 中心线点对应的values
    'pointCloud', {}, ...             % 分段点云
    'centerPoint', {}, ...            % 分段中心点
    'numPoints', {} ...               % 点数
);

% 创建分段
for i = 1:numSegments
    % 计算当前分段的x坐标范围
    segStart = minX + (i-1) * stepSize;
    segEnd = min(segStart + stepSize, maxX);
    
    % 找出在当前分段内的点
    inSegment = (xCoords >= segStart) & (xCoords <= segEnd);
    segmentIndices = find(inSegment);
    
    if isempty(segmentIndices)
        continue; % 跳过空分段
    end
    
    % 提取当前分段的点云和对应的values
    segmentPoints = fractureCloud(segmentIndices, :);
    segmentValues = values(segmentIndices);
    
    % 对当前分段进行PCA，建立分段局部坐标系
    [coeff_segment, ~, latent_segment] = pca(segmentPoints);
    
    % 确定延伸方向（与整体延伸方向最接近的主成分）
    dotProducts = abs(coeff_segment' * xAxis);
    [~, extendIdx] = max(dotProducts);
    
    % 确定横向方向和开度方向
    otherIndices = setdiff(1:3, extendIdx);
    
    % 从剩余两个主成分中，横向方向取方差较大的，开度方向取方差较小的
    [~, sortIdx] = sort(latent_segment(otherIndices), 'descend');
    lateralIdx = otherIndices(sortIdx(1));      % 横向方向（方差较大）
    apertureIdx = otherIndices(sortIdx(2));     % 开度方向（方差较小）
    
    % 获取三个方向的单位向量
    xAxis_seg = coeff_segment(:, extendIdx);     % 分段延伸方向
    yAxis_seg = coeff_segment(:, lateralIdx);    % 分段横向方向
    zAxis_seg = coeff_segment(:, apertureIdx);   % 分段开度方向（法向）
    
    % 确保坐标系是右手系
    if dot(cross(xAxis_seg, yAxis_seg), zAxis_seg) < 0
        zAxis_seg = -zAxis_seg;
    end
    
    % 构建分段局部坐标系的变换矩阵
    transformMatrix_seg = [xAxis_seg, yAxis_seg, zAxis_seg]';
    center_seg = mean(segmentPoints, 1);
    
    % 将当前分段的点转换到分段局部坐标系
    segmentLocalCoords = (segmentPoints - center_seg) * transformMatrix_seg';
    
    % 获取各方向坐标
    x_coords = segmentLocalCoords(:,1);  % 延伸方向坐标
    y_coords = segmentLocalCoords(:,2);  % 横向坐标
    z_coords = segmentLocalCoords(:,3);  % 开度坐标
    
    % ========== 1. 沿横向分行计算开度 ==========
    y_min = min(y_coords);
    y_max = max(y_coords);
    
    % 根据点数和横向宽度确定行数
    idealNumRows = floor(sqrt(length(segmentIndices)));
    maxRows = floor((y_max - y_min) / 0.01); % 最小行宽0.01m
    numRows = min(idealNumRows, maxRows);
    numRows = max(numRows, 1); % 至少1行
    
    if numRows > 1
        y_edges = linspace(y_min, y_max, numRows+1);
    else
        y_edges = [y_min, y_max];
    end
    
    % 初始化开度数组
    apertureProfile = [];
    
    % 对每一行进行处理计算开度
    for j = 1:numRows
        % 找出在当前行内的点
        if j < numRows
            inRow = (y_coords >= y_edges(j)) & (y_coords < y_edges(j+1));
        else
            inRow = (y_coords >= y_edges(j)) & (y_coords <= y_edges(j+1));
        end
        
        if sum(inRow) >= 3  % 至少3个点才计算
            % 获取该行的z坐标
            row_z = z_coords(inRow);
            
            % 计算该行的开度（z方向的范围）
            rowAperture = range(row_z);
            
            % 存储结果
            apertureProfile = [apertureProfile; rowAperture];
        end
    end
    
    % ========== 2. 沿延伸方向分列提取中心线 ==========
    x_min = min(x_coords);
    x_max = max(x_coords);
    
    % 确定列数（沿延伸方向）
    numCols = min(50, floor(sqrt(length(segmentIndices))));
    numCols = max(numCols, 1); % 至少1列
    
    centerLinePoints = [];
    centerLineValues = [];
    
    if numCols > 1
        x_edges = linspace(x_min, x_max, numCols+1);
        
        for j = 1:numCols
            % 隔行提取：只处理指定间隔的列
            if mod(j, extractInterval) == 0 || j == 1 || j == numCols
                % 找出在当前列内的点
                inCol = (x_coords >= x_edges(j)) & (x_coords < x_edges(j+1));
                
                if any(inCol)
                    % 获取该列的原始三维点和values
                    colPoints3D = segmentPoints(inCol, :);
                    colValues = segmentValues(inCol);
                    
                    % 找到该列中values最大的点
                    [maxValue, maxIdx] = max(colValues);
                    maxPoint = colPoints3D(maxIdx, :);
                    
                    centerLinePoints = [centerLinePoints; maxPoint];
                    centerLineValues = [centerLineValues; maxValue];
                end
            end
        end
    else
        % 列数太少，取整个段中values最大的点
        [maxValue, maxIdx] = max(segmentValues);
        centerLinePoints = segmentPoints(maxIdx, :);
        centerLineValues = maxValue;
    end
    
    % 计算该分段的最终开度
    if ~isempty(apertureProfile)
        % 最终开度 = 所有行开度的立方根均值
        finalAperture = mean(apertureProfile .^ (1/3)) .^ 3;
    else
        % 如果没有有效的行，使用简化方法
        finalAperture = range(z_coords);
    end
    
    % 开度方向 = 该段的法向量
    apertureDirection = zAxis_seg';
    
    % 计算分段长度
    segmentLength = segEnd - segStart;
    
    % 计算分段中心点
    centerPoint = mean(segmentPoints, 1);
    
    % 存储精简后的分段信息
    fractureSegments(i).startPos = segStart;
    fractureSegments(i).endPos = segEnd;
    fractureSegments(i).length = segmentLength;
    fractureSegments(i).aperture = finalAperture;
    fractureSegments(i).apertureDirection = apertureDirection;
    fractureSegments(i).centerLinePoints = centerLinePoints;
    fractureSegments(i).centerLineValues = centerLineValues;
    fractureSegments(i).pointCloud = segmentPoints;
    fractureSegments(i).centerPoint = centerPoint;
    fractureSegments(i).numPoints = size(segmentPoints, 1);
    
    % 显示进度
    if mod(i, 10) == 0 || i == numSegments
        fprintf('分段 %d/%d 处理完成, 开度: %.4f m, 中心线点数: %d\n', ...
            i, numSegments, finalAperture, size(centerLinePoints, 1));
    end
end

% 移除空的分段
fractureSegments = fractureSegments(~cellfun(@isempty, {fractureSegments.startPos}));

% 显示整体处理结果
fprintf('\n======= 处理完成 =======\n');
fprintf('有效分段数: %d\n', length(fractureSegments));

if ~isempty(fractureSegments)
    allApertures = [fractureSegments.aperture];
    fprintf('开度均值: %.4f m\n', mean(allApertures));
    fprintf('开度标准差: %.4f m\n', std(allApertures));
    fprintf('开度最大值: %.4f m\n', max(allApertures));
    fprintf('开度最小值: %.4f m\n', min(allApertures));
end

fprintf('总迹长: %.3f m\n', totalLength);

end