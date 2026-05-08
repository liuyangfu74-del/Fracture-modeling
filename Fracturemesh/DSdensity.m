function [datadensity,Growinglength] = DSdensity(downsampledPtCloud)
    pointCounts = zeros(size(downsampledPtCloud.Location, 1), 1);
     for i = 1:size(downsampledPtCloud.Location, 1)
%         if any(negcurvature == i)
%             continue
%         else
        %% 获取当前点的坐标
        currentPoint = downsampledPtCloud.Location(i,:);
    
        roi = [currentPoint(1,1) - 1/2,currentPoint(1,1) + 1/2....
              currentPoint(1,2) - 1/2, currentPoint(1,2) + 1/2....
              currentPoint(1,3) - 1/2, currentPoint(1,3) + 1/2];
    
        % 获取当前体素网格内的点云数据
        indices = findPointsInROI(downsampledPtCloud, roi);
        pointCounts(i,1) = length(indices(:,1));
     end
     datadensity=ceil(median(pointCounts(ceil(length(pointCounts)/2),:)));
     Growinglength=datadensity^0.5/1000;
end