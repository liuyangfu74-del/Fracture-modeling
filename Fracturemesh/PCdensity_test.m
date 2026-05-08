function [pointCounts, centroid] = PCdensity_test(downsampledPtCloud,datadensity)
    pointCounts = zeros(size(downsampledPtCloud.Location, 1), 1);
    centroid = zeros(size(downsampledPtCloud.Location, 1),3);
    curvature = zeros(size(downsampledPtCloud.Location, 1),1);
%     negcurvature = zeros(1,1);
    % 遍历每个点
     for i = 1:size(downsampledPtCloud.Location, 1)
%         if any(negcurvature == i)
%             continue
%         else
        %% 获取当前点的坐标
        currentPoint = downsampledPtCloud.Location(i,:);
        searchrange = 0.2；
        roi = [currentPoint(1,1) - searchrange/2,currentPoint(1,1) + searchrange/2....
              currentPoint(1,2) - searchrange/2, currentPoint(1,2) + searchrange/2....
              currentPoint(1,3) - searchrange/2, currentPoint(1,3) + searchrange/2];
    
        % 获取当前体素网格内的点云数据
        indices = findPointsInROI(downsampledPtCloud, roi);
        if length(indices(:,1))<4
            pointCounts(i) = pointCounts(i);
            continue
        else
        indicesdensity = length(indices(:,1));
        end
       %% 1.PCA数值
        % 计算质心
        centroid(i,:) = mean(downsampledPtCloud.Location(indices(:,1),:), 1);

        % 计算主成分分析
        [~, ~, latent, ~, ~] = pca(downsampledPtCloud.Location(indices(:,1),:));
        % 曲率表征
        curvature(i,1) = min(latent)/sum(latent);

        % 计算从点P到参考点的向量v
        v = centroid(i,:) - currentPoint;

%         % 计算法向量和参考点方向的点积
%         dot_product = dot(normal, v);
% 
%         % 判断法向量方向
%         if dot_product > 0
%         % 如果点积为负，反转法向量
%         normal = -normal;
%         end

%        计算法向量与参考方向的点积
%         dot_products = dot(v, AverageDirection);
        % 如果点积为正，保留曲率为正，否则取负值
%     doubleArray = downsampledPtCloud.Location(indices(:,1),:);
%     centroid = mean(doubleArray, 1);
%     v = centroid - currentPoint;
%     figure
%     quiver3(v(:, 1),v(:, 2), v(:, 3), ...
%              currentPoint(1,1), currentPoint(1,2), currentPoint(1,3), 0.5, 'r', 'LineWidth', 2);
%     xlabel('X');
%     ylabel('Y');
%     zlabel('Z');
%     axis equal;
%     figure   
%     quiver3(AverageDirection(:, 1), AverageDirection(:, 2), AverageDirection(:, 3), ...
%              0, 0, 0, 0.5, 'r', 'LineWidth', 2);
%     xlabel('X');
%     ylabel('Y');
%     zlabel('Z');
%     axis equal;
%         if dot_products <= 0 
%          curvature(i) = -curvature(i);  % 负曲率
%            pointCounts(i,1) = 1*norm(centroid(i,:) - currentPoint)*datadensity*searchrange;
%            + curvature(i)*datadensity*searchrange/2
%            pointCounts(indices(:,1),1) = pointCounts(i,1);
%            negcurvature = [negcurvature;double(indices(:,1))];
%            continue
%         else % 正曲率
            if norm(centroid(i,:) - currentPoint)>0.08*searchrange && curvature(i)<0.015
                pointCounts(i) = curvature(i)*datadensity*searchrange;
            else
%            pointCounts(i) = pointCounts(i)+curvature(i)*datadensity*searchrange;
             pointCounts(i) = 4*curvature(i)*datadensity*searchrange + 1*norm(centroid(i,:) - currentPoint)*datadensity*searchrange;
           end
%         end
%         end
        %2.颜色判定
        
%         colors = downsampledPtCloud.Color;  % RGB颜色
% 
%         % 将RGB颜色转换为灰度值（加权平均法）
%         % 灰度值公式: Gray = 0.2989 * R + 0.5870 * G + 0.1140 * B
%         grayValues = 0.2989 * double(colors(:, 1)) + ...
%                      0.5870 * double(colors(:, 2)) + ...
%                      0.1140 * double(colors(:, 3));
% 
%         % 为颜色越深（灰度越低）赋予更大的值（反转灰度值）
%         maxValue = max(grayValues);  % 找到灰度值中的最大值
%         minValue = min(grayValues);  % 找到灰度值中的最小值
% 
%         % 将灰度值映射为赋值值，越深（灰度越低）值越大
%         assignedValues = maxValue - grayValues(i);
%         pointCounts(i) = pointCounts(i)+assignedValues*0.5;
        %3.
 
%          if length(indices(:,1))==1||isempty(indices)
%              pointCounts(i) = 1;
%              continue
%          else
%                % 计算当前点到所有其他点的距离
%                distances = sqrt(sum((downsampledPtCloud.Location(indices,:) - currentPoint).^2, 2));
%                % 统计在圆形范围内的点数
%                pointsInRange = sum(distances <= radius); % 不用减去自身点
%                pointCounts(i) = pointsInRange;
%          end
%     doubleArray = downsampledPtCloud.Location(indices(:,1),:);
%     centroid = mean(doubleArray, 1);
%     v = centroid - currentPoint;
%     figure
%     quiver3(centroid(:, 1),centroid(:, 2), centroid(:, 3), ...
%              currentPoint(1,1), currentPoint(1,2), currentPoint(1,3), 0.5, 'r', 'LineWidth', 2);
%     xlabel('X');
%     ylabel('Y');
%     zlabel('Z');
%     axis equal;
%     figure   
%     quiver3(mean(doubleArray(:, 1)), mean(doubleArray(:, 2)), mean(doubleArray(:, 3)), ...
%              normal(1), normal(2), normal(3), 0.5, 'r', 'LineWidth', 2);
%     xlabel('X');
%     ylabel('Y');
%     zlabel('Z');
%     axis equal;
%     figure
%     scatter3(doubleArray(:, 1), doubleArray(:, 2), doubleArray(:, 3), 'filled');
%     xlabel('X');
%     ylabel('Y');
%     zlabel('Z');
%     axis equal;
%     hold on;
%     scatter3(centroid(:, 1), centroid(:, 2), centroid(:, 3), 'r');
%     axis equal;
%     figure
%     quiver3(0,0,0, ...
%              v(1), v(2), v(3), 0.5, 'r', 'LineWidth', 2);
%     xlabel('X');
%     ylabel('Y');
%     zlabel('Z');
%     axis equal;
%     dot_product = dot(a, v)
%         end
     end
end