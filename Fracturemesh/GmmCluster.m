function [FClusters] = GmmCluster(FractureProperties)
for i = 1:length([FractureProperties(:).clusterId])
    for j = 1:length(FractureProperties(i).points)
        Segmentp = FractureProperties(i).points;
        if length(Segmentp{1,j})<100
            continue
        else
        [coeff_all, ~, ~]  = pca(Segmentp{1,j});
        Nom2(j,:) = coeff_all(:,1)';
        end
        clear Segmentp
    end
    FractureAttitudesu(i,:) = cross(mean(Nom2),FractureProperties(i).normalVector);
    clear Nom2
end
% cn = 3;
FractureAttitudes = unify_vector_direction(FractureAttitudesu, [0,0,1]);
gm = fitgmdist(FractureAttitudes(:,1:3),2,'Replicates', 10);  

% 获取聚类结果
cluster_idx = cluster(gm, FractureAttitudes(:,1:3));  % 获取每个数据点所属的簇索引
% cluster_idx = ones(length(FractureProperties(i).points), 1);
figure;
% 定义两种颜色（RGB格式）
colors = [0    0.4470 0.7410;  % 蓝色 - Group1
          0.8500 0.3250 0.0980; % 橙色 - Group2
          0.9290 0.6940 0.1250; % 黄色 - Group3（如有需要）
          0.4940 0.1840 0.5560; % 紫色
          0.4660 0.6740 0.1880; % 绿色
          0.3010 0.7450 0.9330; % 浅蓝
          0.6350 0.0780 0.1840];% 红色


for i = 1:max(cluster_idx)
    pf = find(cluster_idx == i);
    
    % 只为每个聚类组创建一次图例项
    if ~isempty(pf)
        % 创建虚拟散点图用于图例（只显示一次）
        h_scatter = scatter3(NaN, NaN, NaN, 50, colors(i,:), 'filled', ...
                            'DisplayName', sprintf('Group%d', i));
        hold on;
    end
    
    for j = 1:length(pf)
        % 绘制散点（不显示在图例中）
        scatter3(FractureProperties(pf(j)).allpoints(:,1), ...
                 FractureProperties(pf(j)).allpoints(:,2), ...
                 FractureProperties(pf(j)).allpoints(:,3), ...
                 10, colors(i,:), 'filled', 'HandleVisibility', 'off');
        
        FClusters(i,j) = pf(j);
        
        a = mean(FractureProperties(pf(j)).allpoints(:,1:3));
        % 箭头颜色为大红色，长度放大2倍（从1.5改为3.0）
        quiver3(a(1), a(2), a(3), ...
                FractureAttitudes(pf(j),1), FractureAttitudes(pf(j),2), FractureAttitudes(pf(j),3), ...
                3.0, 'LineWidth', 3, 'Color', 'r', 'MaxHeadSize', 1, 'HandleVisibility', 'off');
    end
end

axis equal;
xlabel('X (m)', 'FontSize', 10, 'FontName', 'Times New Roman');
ylabel('Y (m)', 'FontSize', 10, 'FontName', 'Times New Roman');
zlabel('Z (m)', 'FontSize', 10, 'FontName', 'Times New Roman');
title('Fracture Clustering Results', 'FontSize', 16, 'FontName', 'Times New Roman');

grid off;

% 可选：单独添加箭头图例（如果需要）
% 创建箭头图例项
% arrow_legend = quiver3(NaN, NaN, NaN, NaN, NaN, NaN, 3.0, 'LineWidth', 3, 'Color', 'r', 'MaxHeadSize', 1, 'DisplayName', '结构面倾向');
% legend([legend_handles, arrow_legend], 'Group1', 'Group2', '结构面倾向', 'Location', 'best');

end