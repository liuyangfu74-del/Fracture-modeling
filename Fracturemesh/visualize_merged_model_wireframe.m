% function visualize_merged_model_wireframe(merged_model, results)
%     % VISUALIZE_MERGED_MODEL_WIREFRAME - 用线框模式显示不同置信区间的模型
%     
%     fprintf('用线框模式显示不同置信区间的3D模型...\n');
%     
%     % 字体设置
%     font_name = 'Times New Roman';
%     title_fontsize = 28;
%     label_fontsize = 26;
%     tick_fontsize = 24;
%     
%     % 提取数据
%     V = merged_model.vertices;
%     F = merged_model.faces;
%     
%     % 从results中获取分位数信息
%     if nargin < 2 || isempty(results)
%         % 如果results不存在，使用merged_model中的信息或默认值
%         if isfield(merged_model, 'quantile_names')
%             quantile_names = merged_model.quantile_names;
%         else
%             quantile_names = {'保守估计', '最可能估计', '较可能估计', '较乐观估计', '乐观估计'};
%         end
%         
%         if isfield(merged_model, 'quantile_levels')
%             quantile_levels = merged_model.quantile_levels;
%         else
%             quantile_levels = [0.35, 0.50, 0.65, 0.80, 0.95];
%         end
%     else
%         % 从results中获取分位数信息
%         quantile_names = results.quantile_names;
%         quantile_levels = results.quantile_levels;
%     end
%     
%     % 定义从蓝色到红色的5种颜色
%     % 顺序: 保守(35%) -> 最可能(50%) -> 较可能(65%) -> 较乐观(80%) -> 乐观(95%)
%     confidence_colors = [
%         0.0, 0.0, 1.0;   % 蓝色 - 保守估计(35%)
%         0.0, 0.8, 0.0;   % 绿色 - 最可能估计(50%)
%         1.0, 1.0, 0.0;   % 黄色 - 较可能估计(65%)
%         1.0, 0.6, 0.0;   % 橙色 - 较乐观估计(80%)
%         1.0, 0.0, 0.0;   % 红色 - 乐观估计(95%)
%     ];
%     
%     % 定义透明度梯度（从低到高透明度）
%     edge_alpha = [0.2, 0.3, 0.4, 0.5, 0.6];  % 保守的透明度低，乐观的透明度高
%     
%     % 定义线宽梯度
%     line_widths = [1.5, 1.8, 2.1, 2.4, 2.7];  % 保守的线细，乐观的线粗
%     
%     % 将分位数转换为百分比字符串
%     quantile_levels_str = cell(1, 5);
%     for q = 1:5
%         quantile_levels_str{q} = sprintf('%d%%', round(quantile_levels(q)*100));
%     end
%     
%     % === 图1: 彩色置信区间线框图 ===
%     figure('Position', [100, 100, 1400, 900], ...
%            'Name', 'Confidence Interval Wireframe Visualization', ...
%            'Color', 'white');
%     
%     % 按置信区间分组绘制
%     hold on;
%     
%     for q = 1:5
%         % 为该置信区间选择颜色、透明度和线宽
%         color = confidence_colors(q, :);
%         alpha_val = edge_alpha(q);
%         line_width = line_widths(q);
%         
%         % 绘制该置信区间的线框
%         patch('Vertices', V, 'Faces', F, ...
%               'FaceColor', 'none', ...               % 不填充面
%               'EdgeColor', color, ...                % 边颜色
%               'EdgeAlpha', alpha_val, ...            % 边透明度
%               'LineWidth', line_width, ...           % 线宽
%               'DisplayName', sprintf('%s (%s)', ...
%                      quantile_names{q}, quantile_levels_str{q}));
%     end
%     
%     axis equal;
%     grid on;
%     view(45, 30);
%     
%     % 设置轴范围
%     xlims = [min(V(:,1)), max(V(:,1))];
%     ylims = [min(V(:,2)), max(V(:,2))];
%     zlims = [min(V(:,3)), max(V(:,3))];
%     
%     padding = max([range(xlims), range(ylims), range(zlims)]) * 0.1;
%     if padding == 0, padding = 0.5; end
%     
%     xlim([xlims(1)-padding, xlims(2)+padding]);
%     ylim([ylims(1)-padding, ylims(2)+padding]);
%     zlim([zlims(1)-padding, zlims(2)+padding]);
%     
%     set(gca, 'FontName', font_name, 'FontSize', tick_fontsize, 'LineWidth', 1.5);
%     xlabel('X (m)', 'FontName', font_name, 'FontSize', label_fontsize);
%     ylabel('Y (m)', 'FontName', font_name, 'FontSize', label_fontsize);
%     zlabel('Z (m)', 'FontName', font_name, 'FontSize', label_fontsize);
%     
%     title('Confidence Interval Wireframe Visualization', ...
%           'FontName', font_name, 'FontSize', title_fontsize, 'FontWeight', 'bold');
%     
%     % 创建自定义图例
%     legend_str = {};
%     for q = 1:5
%         legend_str{q} = sprintf('%s (%s)', quantile_names{q}, quantile_levels_str{q});
%     end
%     legend(legend_str, 'Location', 'best', 'FontName', font_name, 'FontSize', tick_fontsize-2);
%     
%     % === 图2: 单独显示每个置信区间的子图 ===
%     figure('Position', [100, 100, 1800, 900], ...
%            'Name', 'Individual Confidence Interval Wireframes', ...
%            'Color', 'white');
%     
%     for q = 1:5
%         subplot(2, 3, q);
%         hold on;
%         
%         color = confidence_colors(q, :);
%         alpha_val = 0.7;  % 单独显示时用较高透明度
%         line_width = 2.5;
%         
%         % 绘制该置信区间的线框
%         patch('Vertices', V, 'Faces', F, ...
%               'FaceColor', 'none', ...      % 不填充面
%               'EdgeColor', color, ...       % 边颜色
%               'EdgeAlpha', alpha_val, ...   % 边透明度
%               'LineWidth', line_width);     % 线宽
%         
%         axis equal;
%         grid on;
%         view(45, 30);
%         
%         % 设置轴范围
%         xlim([xlims(1)-padding, xlims(2)+padding]);
%         ylim([ylims(1)-padding, ylims(2)+padding]);
%         zlim([zlims(1)-padding, zlims(2)+padding]);
%         
%         set(gca, 'FontName', font_name, 'FontSize', tick_fontsize-4, 'LineWidth', 1.2);
%         xlabel('X (m)', 'FontSize', label_fontsize-4);
%         ylabel('Y (m)', 'FontSize', label_fontsize-4);
%         zlabel('Z (m)', 'FontSize', label_fontsize-4);
%         
%         title_str = sprintf('%s\n(%s Confidence)', ...
%                            quantile_names{q}, quantile_levels_str{q});
%         title(title_str, 'FontName', font_name, 'FontSize', title_fontsize-4, ...
%               'FontWeight', 'bold', 'Color', color);
%     end
%     
%     % 第6个子图：颜色图例和说明
%     subplot(2, 3, 6);
%     axis off;
%     
%     % 创建颜色图例显示
%     hold on;
%     
%     legend_y = 0.9;
%     text_y_step = 0.12;
%     
%     for q = 1:5
%         color = confidence_colors(q, :);
%         
%         % 绘制颜色方块
%         rectangle('Position', [0.1, legend_y-0.08, 0.15, 0.06], ...
%                   'FaceColor', color, 'EdgeColor', 'k', 'LineWidth', 1);
%         
%         % 添加文字说明
%         text_str = sprintf('%s (%s)', quantile_names{q}, quantile_levels_str{q});
%         text(0.3, legend_y, text_str, 'FontName', font_name, 'FontSize', tick_fontsize-2, ...
%              'Color', color, 'FontWeight', 'bold');
%         
%         legend_y = legend_y - text_y_step;
%     end
%     
%     % 添加总体说明
%     text(0.1, 0.25, 'Color Progression:', 'FontName', font_name, 'FontSize', tick_fontsize, ...
%          'FontWeight', 'bold');
%     text(0.1, 0.18, 'Conservative → Optimistic', 'FontName', font_name, 'FontSize', tick_fontsize-2);
%     text(0.1, 0.12, 'Blue → Green → Yellow → Orange → Red', 'FontName', font_name, 'FontSize', tick_fontsize-2);
%     
%     title('Color Legend', 'FontName', font_name, 'FontSize', title_fontsize-4);
%     
%     sgtitle('Individual Confidence Interval Wireframes', 'FontName', font_name, ...
%             'FontSize', title_fontsize+2, 'FontWeight', 'bold');
%     
%     % === 图3: 置信区间渐变效果图 ===
%     figure('Position', [100, 100, 1400, 900], ...
%            'Name', 'Confidence Interval Gradient', ...
%            'Color', 'white');
%     
%     % 创建渐变色显示
%     hold on;
%     
%     % 从内到外（保守到乐观）绘制渐变效果
%     for q = [1, 3, 5]  % 只绘制保守、中间、乐观三个
%         color = confidence_colors(q, :);
%         alpha_val = 0.3 + (q-1)*0.15;
%         line_width = 1.2 + (q-1)*0.4;
%         
%         patch('Vertices', V, 'Faces', F, ...
%               'FaceColor', 'none', ...
%               'EdgeColor', color, ...
%               'EdgeAlpha', alpha_val, ...
%               'LineWidth', line_width, ...
%               'DisplayName', sprintf('%s (%s)', quantile_names{q}, quantile_levels_str{q}));
%     end
%     
%     axis equal;
%     grid on;
%     view(45, 30);
%     
%     xlim([xlims(1)-padding, xlims(2)+padding]);
%     ylim([ylims(1)-padding, ylims(2)+padding]);
%     zlim([zlims(1)-padding, zlims(2)+padding]);
%     
%     set(gca, 'FontName', font_name, 'FontSize', tick_fontsize, 'LineWidth', 1.5);
%     xlabel('X (m)', 'FontName', font_name, 'FontSize', label_fontsize);
%     ylabel('Y (m)', 'FontName', font_name, 'FontSize', label_fontsize);
%     zlabel('Z (m)', 'FontName', font_name, 'FontSize', label_fontsize);
%     
%     title('Confidence Interval Gradient (Blue → Yellow → Red)', ...
%           'FontName', font_name, 'FontSize', title_fontsize, 'FontWeight', 'bold');
%     
%     legend('show', 'Location', 'best', 'FontName', font_name, 'FontSize', tick_fontsize-2);
%     
%     % 添加说明文字
%     text(0.02, 0.02, 0.02, ...
%          sprintf('Conservative (%s): Thin Blue Lines\nMost Likely (%s): Medium Green Lines\nOptimistic (%s): Thick Red Lines', ...
%                  quantile_levels_str{1}, quantile_levels_str{3}, quantile_levels_str{5}), ...
%          'Units', 'normalized', 'FontName', font_name, 'FontSize', tick_fontsize-4, ...
%          'BackgroundColor', 'white', 'EdgeColor', 'black', 'Margin', 5);
%     
%     fprintf('置信区间线框图已生成:\n');
%     fprintf('  图1: 5个置信区间叠加显示\n');
%     fprintf('  图2: 单独显示的6个子图\n');
%     fprintf('  图3: 渐变效果显示\n');
%     fprintf('颜色对应:\n');
%     fprintf('  蓝色: %s (%s)\n', quantile_names{1}, quantile_levels_str{1});
%     fprintf('  绿色: %s (%s)\n', quantile_names{2}, quantile_levels_str{2});
%     fprintf('  黄色: %s (%s)\n', quantile_names{3}, quantile_levels_str{3});
%     fprintf('  橙色: %s (%s)\n', quantile_names{4}, quantile_levels_str{4});
%     fprintf('  红色: %s (%s)\n', quantile_names{5}, quantile_levels_str{5});
% end
function visualize_merged_model_by_quantile_separate(merged_model, results)
    % VISUALIZE_MERGED_MODEL_BY_QUANTILE_SEPARATE - 显示5个独立的分位数模型
    
    fprintf('显示5个独立的分位数3D模型...\n');
    
    % 字体设置
    font_name = 'Times New Roman';
    title_fontsize = 28;
    label_fontsize = 26;
    tick_fontsize = 24;
    
    % 定义从蓝色到红色的5种颜色
    confidence_colors = [
        0.0, 0.0, 1.0;   % 蓝色 - 保守估计(35%)
        0.0, 0.8, 0.0;   % 绿色 - 最可能估计(50%)
        1.0, 1.0, 0.0;   % 黄色 - 较可能估计(65%)
        1.0, 0.6, 0.0;   % 橙色 - 较乐观估计(80%)
        1.0, 0.0, 0.0;   % 红色 - 乐观估计(95%)
    ];
    
    % 从results中获取分位数信息
    if nargin < 2 || isempty(results)
        quantile_names = {'保守估计', '最可能估计', '较可能估计', '较乐观估计', '乐观估计'};
        quantile_levels = [0.35, 0.50, 0.65, 0.80, 0.95];
    else
        quantile_names = results.quantile_names;
        quantile_levels = results.quantile_levels;
    end
    
    % 将分位数转换为百分比字符串
    quantile_levels_str = cell(1, 5);
    for q = 1:5
        quantile_levels_str{q} = sprintf('%d%%', round(quantile_levels(q)*100));
    end
    
    % === 第一步：检查merged_model的结构 ===
    fprintf('\n检查merged_model结构...\n');
    
    % 检查merged_model是否包含5个子模型
    if isfield(merged_model, 'models_by_quantile')
        fprintf('找到分位数模型: merged_model.models_by_quantile\n');
        models = merged_model.models_by_quantile;
    elseif isfield(merged_model, 'quantile_models')
        fprintf('找到分位数模型: merged_model.quantile_models\n');
        models = merged_model.quantile_models;
    else
        fprintf('警告: merged_model不包含分位数子模型结构\n');
        fprintf('尝试从顶点颜色分离...\n');
        
        % 从vertex_colors中分离不同分位数的模型
        models = separate_models_by_color(merged_model, confidence_colors);
    end
    
    % 检查每个模型是否有数据
    for q = 1:5
        if isempty(models{q}.vertices) || isempty(models{q}.faces)
            fprintf('模型 %d (%s): 无数据\n', q, quantile_names{q});
        else
            fprintf('模型 %d (%s): %d 顶点, %d 面\n', ...
                q, quantile_names{q}, ...
                size(models{q}.vertices, 1), ...
                size(models{q}.faces, 1));
        end
    end
    
    % === 图1: 5个独立模型（网格显示） ===
    figure('Position', [50, 50, 1800, 1000], ...
           'Name', '5 Independent Fracture Models by Quantile', ...
           'Color', 'white');
    
    for q = 1:5
        subplot(2, 3, q);
        hold on;
        
        model = models{q};
        
        if ~isempty(model.vertices) && ~isempty(model.faces)
            % 绘制该分位数的线框模型
            patch('Vertices', model.vertices, 'Faces', model.faces, ...
                  'FaceColor', 'none', ...      % 不填充面
                  'EdgeColor', confidence_colors(q, :), ...  % 边颜色
                  'EdgeAlpha', 0.8, ...         % 边透明度
                  'LineWidth', 2.0);            % 线宽
            
            % 计算轴限制
            xlims = [min(model.vertices(:,1)), max(model.vertices(:,1))];
            ylims = [min(model.vertices(:,2)), max(model.vertices(:,2))];
            zlims = [min(model.vertices(:,3)), max(model.vertices(:,3))];
            
            % 添加填充
            padding = max([range(xlims), range(ylims), range(zlims)]) * 0.1;
            if padding == 0, padding = 0.5; end
            
            xlim([xlims(1)-padding, xlims(2)+padding]);
            ylim([ylims(1)-padding, ylims(2)+padding]);
            zlim([zlims(1)-padding, zlims(2)+padding]);
        else
            % 显示"无数据"
            text(0.5, 0.5, 'No Data', 'HorizontalAlignment', 'center', ...
                 'FontSize', 24, 'Color', 'red');
            xlim([0, 1]);
            ylim([0, 1]);
        end
        
        axis equal;
        grid on;
        view(45, 30);
        
        set(gca, 'FontName', font_name, 'FontSize', tick_fontsize-4, 'LineWidth', 1.2);
        xlabel('X (m)', 'FontSize', label_fontsize-4);
        ylabel('Y (m)', 'FontSize', label_fontsize-4);
        zlabel('Z (m)', 'FontSize', label_fontsize-4);
        
        title_str = sprintf('%s\n(%s Confidence)', ...
                           quantile_names{q}, quantile_levels_str{q});
        title(title_str, 'FontName', font_name, 'FontSize', title_fontsize-4, ...
              'FontWeight', 'bold', 'Color', confidence_colors(q, :));
    end
    
    % 第6个子图：图例和统计
    subplot(2, 3, 6);
    axis off;
    
    % 创建颜色图例
    hold on;
    
    legend_y = 0.9;
    text_y_step = 0.12;
    
    total_stats = struct('total_vertices', 0, 'total_faces', 0);
    
    for q = 1:5
        color = confidence_colors(q, :);
        model = models{q};
        
        % 绘制颜色方块
        rectangle('Position', [0.1, legend_y-0.08, 0.15, 0.06], ...
                  'FaceColor', color, 'EdgeColor', 'k', 'LineWidth', 1);
        
        % 统计信息
        n_vertices = size(model.vertices, 1);
        n_faces = size(model.faces, 1);
        
        total_stats.total_vertices = total_stats.total_vertices + n_vertices;
        total_stats.total_faces = total_stats.total_faces + n_faces;
        
        % 添加文字说明
        if n_vertices > 0
            text_str = sprintf('%s (%s): %d vertices, %d faces', ...
                              quantile_names{q}, quantile_levels_str{q}, n_vertices, n_faces);
        else
            text_str = sprintf('%s (%s): No data', ...
                              quantile_names{q}, quantile_levels_str{q});
        end
        
        text(0.3, legend_y, text_str, 'FontName', font_name, 'FontSize', tick_fontsize-4, ...
             'Color', color, 'FontWeight', 'bold');
        
        legend_y = legend_y - text_y_step;
    end
    
    % 添加总体统计
    text(0.1, 0.25, 'TOTAL STATISTICS:', 'FontName', font_name, 'FontSize', tick_fontsize-2, ...
         'FontWeight', 'bold');
    text(0.1, 0.18, sprintf('Total Vertices: %d', total_stats.total_vertices), ...
         'FontName', font_name, 'FontSize', tick_fontsize-4);
    text(0.1, 0.12, sprintf('Total Faces: %d', total_stats.total_faces), ...
         'FontName', font_name, 'FontSize', tick_fontsize-4);
    
    title('Model Statistics', 'FontName', font_name, 'FontSize', title_fontsize-4);
    
    sgtitle('Independent Fracture Models by Confidence Level', 'FontName', font_name, ...
            'FontSize', title_fontsize+2, 'FontWeight', 'bold');
    
    % === 图2: 透明度叠加显示 ===
    figure('Position', [100, 100, 1400, 900], ...
           'Name', 'Transparency Overlay of All Models', ...
           'Color', 'white');
    
    hold on;
    
    % 按从乐观到保守的顺序绘制（后面的覆盖前面的）
    draw_order = [5, 4, 3, 2, 1];
    
    for order_idx = 1:length(draw_order)
        q = draw_order(order_idx);
        model = models{q};
        
        if ~isempty(model.vertices) && ~isempty(model.faces)
            % 设置透明度：保守的透明度高，乐观的透明度低
            alpha_val = 0.3 + (q-1)*0.15;
            
            patch('Vertices', model.vertices, 'Faces', model.faces, ...
                  'FaceColor', confidence_colors(q, :), ...  % 面颜色
                  'EdgeColor', 'none', ...                   % 无边
                  'FaceAlpha', alpha_val, ...                % 面透明度
                  'FaceLighting', 'gouraud', ...
                  'DisplayName', sprintf('%s (%s)', quantile_names{q}, quantile_levels_str{q}));
        end
    end
    
    axis equal;
    grid on;
    view(45, 30);
    
    % 计算所有模型的总体轴限制
    all_vertices = [];
    for q = 1:5
        if ~isempty(models{q}.vertices)
            all_vertices = [all_vertices; models{q}.vertices];
        end
    end
    
    if ~isempty(all_vertices)
        xlims = [min(all_vertices(:,1)), max(all_vertices(:,1))];
        ylims = [min(all_vertices(:,2)), max(all_vertices(:,2))];
        zlims = [min(all_vertices(:,3)), max(all_vertices(:,3))];
        
        padding = max([range(xlims), range(ylims), range(zlims)]) * 0.1;
        if padding == 0, padding = 0.5; end
        
        xlim([xlims(1)-padding, xlims(2)+padding]);
        ylim([ylims(1)-padding, ylims(2)+padding]);
        zlim([zlims(1)-padding, zlims(2)+padding]);
    end
    
    set(gca, 'FontName', font_name, 'FontSize', tick_fontsize, 'LineWidth', 1.5);
    xlabel('X (m)', 'FontName', font_name, 'FontSize', label_fontsize);
    ylabel('Y (m)', 'FontName', font_name, 'FontSize', label_fontsize);
    zlabel('Z (m)', 'FontName', font_name, 'FontSize', label_fontsize);
    
    title('Transparency Overlay (Conservative → Transparent, Optimistic → Opaque)', ...
          'FontName', font_name, 'FontSize', title_fontsize, 'FontWeight', 'bold');
    
    legend('show', 'Location', 'best', 'FontName', font_name, 'FontSize', tick_fontsize-2);
    
    % 添加光照
    camlight('headlight');
    lighting gouraud;
    
    fprintf('\n可视化完成:\n');
    fprintf('  图1: 5个独立模型网格显示\n');
    fprintf('  图2: 透明度叠加显示\n');
    fprintf('颜色对应:\n');
    for q = 1:5
        fprintf('  %s (%s): RGB(%.1f,%.1f,%.1f)\n', ...
                quantile_names{q}, quantile_levels_str{q}, ...
                confidence_colors(q, 1), confidence_colors(q, 2), confidence_colors(q, 3));
    end
end

function models = separate_models_by_color(merged_model, target_colors)
    % 根据顶点颜色分离不同分位数的模型
    
    V = merged_model.vertices;
    F = merged_model.faces;
    vertex_colors = merged_model.vertex_colors;
    
    models = cell(5, 1);
    
    for q = 1:5
        models{q} = struct('vertices', [], 'faces', []);
        
        % 找到颜色接近目标颜色的顶点
        color_target = target_colors(q, :);
        color_threshold = 0.2;  % 颜色匹配阈值
        
        % 计算颜色差异
        color_diff = sqrt(sum((vertex_colors - color_target).^2, 2));
        vertex_mask = color_diff < color_threshold;
        
        if any(vertex_mask)
            % 获取顶点索引
            vertex_indices = find(vertex_mask);
            
            % 找出包含这些顶点的面
            face_mask = all(ismember(F, vertex_indices), 2);
            
            if any(face_mask)
                % 提取这些面和对应的顶点
                faces_in_group = F(face_mask, :);
                
                % 找到这些面使用的所有唯一顶点
                unique_vertices = unique(faces_in_group(:));
                
                % 创建新的顶点列表
                new_vertices = V(unique_vertices, :);
                
                % 重新映射面索引
                [~, loc] = ismember(faces_in_group(:), unique_vertices);
                new_faces = reshape(loc, size(faces_in_group));
                
                models{q}.vertices = new_vertices;
                models{q}.faces = new_faces;
            end
        end
    end
    
    return;
end