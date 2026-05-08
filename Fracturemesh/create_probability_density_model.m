function merged_model = create_probability_density_model(combined_meshes, results)
    % CREATE_PROBABILITY_DENSITY_MODEL - 合并5个分位数模型，用颜色编码概率密度
    % 输入:
    %   combined_meshes: 5个分位数的网格结构体cell数组
    %   results: MCMC反演结果
    % 输出:
    %   merged_model: 合并后的模型结构体
    
    fprintf('开始合并5个分位数模型...\n');
    
    % 分位数信息
    quantile_levels = results.quantile_levels;
    quantile_names = results.quantile_names;
    
    % 颜色定义：从蓝色(保守)到红色(乐观)
    colors = [...
        0.2 0.4 0.8;   % 35% - 深蓝（保守）
        0.0 0.6 0.0;   % 50% - 绿色（最可能）
        0.9 0.6 0.2;   % 65% - 橙色（较可能）
        0.9 0.4 0.2;   % 80% - 橙红（较乐观）
        0.8 0.2 0.2;   % 95% - 红色（乐观）
    ];
    
    % 初始化合并模型
    merged_V = [];
    merged_F = [];
    merged_colors = [];
    merged_quantiles = [];
    vertex_offset = 0;
    
    % 合并所有网格
    for q = 1:5
        fprintf('  处理 %s 分位数...\n', quantile_names{q});
        
        V = combined_meshes{q}.V;
        F = combined_meshes{q}.F;
        
        if isempty(V) || isempty(F)
            fprintf('  警告: 分位数 %d 的网格为空，跳过\n', q);
            continue;
        end
        
        % 调整面索引
        adjusted_F = F + vertex_offset;
        
        % 添加顶点
        merged_V = [merged_V; V];
        
        % 添加面
        merged_F = [merged_F; adjusted_F];
        
        % 为当前分位数的所有顶点分配颜色和分位数标签
        n_vertices = size(V, 1);
        vertex_colors = repmat(colors(q, :), n_vertices, 1);
        vertex_quantiles = repmat(q, n_vertices, 1);
        
        merged_colors = [merged_colors; vertex_colors];
        merged_quantiles = [merged_quantiles; vertex_quantiles];
        
        vertex_offset = vertex_offset + n_vertices;
        
        fprintf('    添加了 %d 个顶点，%d 个面\n', n_vertices, size(F, 1));
    end
    
    % 计算每个顶点的概率密度（基于分位数位置）
    % 距离50%分位数越近，概率密度越高
    fprintf('计算概率密度...\n');
    probabilities = zeros(size(merged_quantiles));
    for i = 1:length(merged_quantiles)
        q_idx = merged_quantiles(i);
        
        % 计算与50%分位数（索引3）的距离
        distance_to_median = abs(q_idx - 3);  % 3对应50%分位数
        
        % 距离越近，概率越高（使用高斯核）
        probability = exp(-distance_to_median^2 / (2 * 1.5^2));  % sigma=1.5
        
        % 归一化
        probabilities(i) = probability;
    end
    
    % 归一化到[0,1]范围
    if max(probabilities) > 0
        probabilities = probabilities / max(probabilities);
    end
    
    % 计算模型统计
    n_vertices_total = size(merged_V, 1);
    n_faces_total = size(merged_F, 1);
    
    % 计算每个分位数的顶点数量
    vertex_counts = zeros(5, 1);
    for q = 1:5
        vertex_counts(q) = sum(merged_quantiles == q);
    end
    
    fprintf('模型合并完成:\n');
    fprintf('  总顶点数: %d\n', n_vertices_total);
    fprintf('  总面数: %d\n', n_faces_total);
    for q = 1:5
        fprintf('  %s: %d 顶点 (%.1f%%)\n', quantile_names{q}, vertex_counts(q), ...
                vertex_counts(q)/n_vertices_total*100);
    end
    
    % 创建合并模型结构体
    merged_model = struct();
    merged_model.vertices = merged_V;
    merged_model.faces = merged_F;
    merged_model.vertex_colors = merged_colors;      % 基于分位数的颜色
    merged_model.vertex_quantiles = merged_quantiles; % 顶点所属分位数
    merged_model.probabilities = probabilities;       % 概率密度
    merged_model.quantile_levels = quantile_levels;
    merged_model.quantile_names = quantile_names;
    merged_model.base_colors = colors;
    merged_model.stats = struct(...
        'n_vertices', n_vertices_total, ...
        'n_faces', n_faces_total, ...
        'vertex_counts', vertex_counts, ...
        'vertex_distribution', vertex_counts/n_vertices_total);
    
    fprintf('概率密度模型创建完成\n');
end