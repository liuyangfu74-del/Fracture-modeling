function [ClusterPointfracture] = ExtractionfractureinformationTD(numNeighbors, Piontfissure, Pointfracturesuround,cn)
    % 输入:
    %   numNeighbors - 邻近点数量
    %   Piontfissure - 需要计算法向量的点 (N×3)
    %   Pointfracturesuround - 用于搜索邻近点的点云 (M×3)

    points = Piontfissure; % 需要计算法向量的点
    
    % 使用k-d树进行快速邻近点搜索（基于Pointfracturesuround构建）
    kdtree = KDTreeSearcher(Pointfracturesuround);
    
    % 初始化法向量存储
    mainDir0 = zeros(size(points, 1), 3);
    ClusterPointfracture = {};
    
    % 循环处理每个需要计算法向量的点
    for i = 1:size(points, 1)
        currentPoint = points(i, :);
        
        % 找到该点在Pointfracturesuround中的邻近点
        [neighborIdx, ~] = knnsearch(kdtree, currentPoint, 'K', numNeighbors);
        
        % 获取邻近点的坐标
        neighborPoints = Pointfracturesuround(neighborIdx, :);
        
        % 对邻近点进行PCA分析
        [coeff, ~, ~] = pca(neighborPoints);
        
        % 提取主方向向量（主成分对应的方向）
        mainDir1 = coeff(:, 3);  % 第一个主成分表示裂隙的主方向
        mainDir2 = coeff(:, 1);
        mainDir = cross(mainDir1, mainDir2);
        % 确保法向量方向一致（统一指向z轴正方向）
        if mainDir(3) < 0
            mainDir = -mainDir;
        end
        
        mainDir0(i, 1:3) = mainDir;
        
    end
    fprintf('法向量计算完成，共计算 %d 个点的法向量\n', size(points, 1));
    
    gm = fitgmdist(mainDir0(:,1:3),cn);  % 将数据聚类为3个簇

    % 获取聚类结果
    cluster_idx = cluster(gm, mainDir0(:,1:3));  % 获取每个数据点所属的簇索引

    figure;
    for i = 1:max(cluster_idx)
        pf = find(cluster_idx==i);
        ClusterPointfracture{i,1} = Piontfissure(pf,:);
        scatter3(Piontfissure(pf,1), Piontfissure(pf,2), Piontfissure(pf,3), 10,  'filled');
        hold on 
    end
    axis equal
end
