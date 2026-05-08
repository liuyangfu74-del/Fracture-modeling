%% =============== 主程序示例 ===============
clear; clc; close all;
tic
%% 阶段1: MCMC贝叶斯反演训练
fprintf('=== 阶段1: MCMC贝叶斯反演训练 ===\n');

% 定义数据文件路径
data_file = 'F:\ph.D\PCD\Rockpointcloudmodel\Inside\2..mat';

% 调用封装函数进行反演
[results, params_mean, post_samples] = bayesian_mcmc_inversion(...
    data_file, ...
    'n_chains', 4, ...
    'n_iter', 30000, ...
    'n_burn', 70, ...
    'n_thin', 1, ...
    'train_ratio', 0.8, ...
    'scale_factor', 10, ...  % mm转cm
    'use_parallel', true, ...
    'verbose', true);

% 保存训练结果
save('trained_model.mat', 'results', 'params_mean', 'post_samples', '-v7.3');
fprintf('训练完成！模型已保存\n');

%% 阶段2: 点云裂隙特征提取
%裂隙点云
load('F:\ph.D\PCD\Rockpointcloudmodel\Inside\2..mat')
PCdata01 = pcread('F:\ph.D\PCD\Rockpointcloudmodel\Inside\butu\3.ply');
ptCloud1 = PCdata01;

[datadensity,Growinglength] = DSdensity(PCdata01);

%% 计算每一个点处附近的密度
[density_map,~] = PCdensity_test(ptCloud1,datadensity);
density_map = (density_map - min(density_map)) / (max(density_map) - min(density_map));
figure('Position', [100, 100, 800, 800])

% 主图 - 上方
subplot(4, 4, [1:3, 5:7, 9:11]);
scatter3(ptCloud1.Location(:,1), ptCloud1.Location(:,2), ptCloud1.Location(:,3), 10, density_map, 'filled');
axis equal
axis off
colormap(jet);

% 颜色条
cb = colorbar;
cb.Position = [0.8 0.6 0.02 0.3];
set(cb, 'FontSize', 12, 'FontName', 'Times New Roman');
stats_data = density_map;
median_val = median(stats_data);
mean_val = mean(stats_data);

% 直方图 - 下方
subplot(4, 4, 13:16);
histogram(density_map, 30, 'FaceColor', [0.2 0.6 0.8], 'EdgeColor', 'none');
hold on;
% 添加统计线
xline(median_val, '--r', 'LineWidth', 2, 'Label', sprintf('Median: %.2f', median_val));
xline(mean_val, '--g', 'LineWidth', 2, 'Label', sprintf('Mean: %.2f', mean_val));

xlabel('Anisotropic Value');
ylabel('Frequency');
grid on;
set(gca, 'FontSize', 11, 'FontName', 'Times New Roman');
legend('Distribution', 'Median', 'Mean', 'Location', 'northeast');

% 提取裂隙线
Fpointcloud = [ptCloud1.Location];
[FractureProperties,Fractioninformations] = extractMaxValueLine2(Fpointcloud, density_map, 0.2, 50, PCdata01.Location);
PClusters = 1;

%% 阶段3: 使用7组不同参数预测迹长并生成裂隙面
fprintf('\n=== 阶段3: 迹长预测与裂隙面生成 (7个置信区间) ===\n');

% 获取7组不同的预测函数
predict_funcs = results.predict_funcs_by_quantile;  % 现在有7个不同的预测函数

% 存储7个置信区间的模型
all_3d_models_by_confidence = cell(7, 1);
all_predictions_by_confidence = cell(7, 1);

confidence_names = {
    '95%置信下限',
    '保守估计35%', 
    '最可能估计50%',
    '较可能估计65%',
    '较乐观估计80%',
    '95%置信上限',
    '概率最大点'
};

for conf_idx = 4:4  % 为每个置信区间循环
    fprintf('\n生成 %s (%d/7) 置信区间模型...\n', confidence_names{conf_idx}, conf_idx);
    
    % 获取当前置信区间的预测函数
    current_predict_func = predict_funcs{conf_idx};
    
    all_fracture_surfaces = cell(size(PClusters, 1), 1);
    all_predictions = cell(size(PClusters, 1), 1);
    
    for cluster_id = 1:size(PClusters, 1)
        fprintf('  处理聚类 %d/%d...\n', cluster_id, size(PClusters, 1));
        
        fracture_ids = PClusters(cluster_id, PClusters(cluster_id, :) ~= 0);
        
        if isempty(fracture_ids)
            continue;
        end
        
        cluster_surfaces = cell(length(fracture_ids), 1);
        cluster_predictions = struct();
        cluster_predictions.fracture_ids = fracture_ids;
        
        for idx = 1:length(fracture_ids)
            f_id = fracture_ids(idx);
            
            % 获取裂隙开度
            apertures = FractureProperties(f_id).apertures;  % 单位：mm
            apertures_scaled = apertures * results.scale_factor;  % 转换为训练时的单位
            
            % 使用当前置信区间的预测函数预测迹长
            L_predicted = current_predict_func(apertures_scaled);
            
            % 获取扫掠建模所需参数
            centerline = Fractioninformations{f_id, 3};
            normal_vector = FractureProperties(f_id).normalVector;
            
            % 中心线分段
            seg_idx = assign_centerline_segments(centerline, FractureProperties(f_id).points);
            if idx==1
                % 设置扫掠参数
                seg_depth = 0.65*L_predicted;
            else
                seg_depth = L_predicted;
            end
            
            % 调用修改后的扫掠建模函数
            try
                [V, F, upper_surface, lower_surface] = sweep_loft_mesh_variable(...
                    centerline, seg_idx, apertures, seg_depth, normal_vector, 20);
                
                % 存储模型
                model = struct();
                model.vertices = V;
                model.faces = F;
                model.upper_surface = upper_surface;
                model.lower_surface = lower_surface;
                model.centerline = centerline;
                model.apertures = apertures;
                model.predicted_length = L_predicted;
                model.confidence_idx = conf_idx;
                model.confidence_name = confidence_names{conf_idx};
                model.seg_depth = seg_depth;
                model.normal_vector = normal_vector;
                
                cluster_surfaces{idx} = model;
                
            catch ME
                fprintf('  裂隙 %d 建模失败: %s\n', f_id, ME.message);
                cluster_surfaces{idx} = [];
            end
        end
        
        all_fracture_surfaces{cluster_id} = cluster_surfaces;
        all_predictions{cluster_id} = cluster_predictions;
    end
    
    % 存储当前置信区间的所有模型
    all_3d_models_by_confidence{conf_idx} = all_fracture_surfaces;
    all_predictions_by_confidence{conf_idx} = all_predictions;
end

%% 阶段4: 结果保存与可视化
fprintf('\n=== 阶段4: 结果保存与可视化 ===\n');

% 保存所有置信区间的预测结果
save('fracture_predictions_7_confidence.mat', 'all_predictions_by_confidence', 'all_3d_models_by_confidence', 'results', '-v7.3');

% 为每个置信区间合并网格
combined_meshes = cell(7, 1);
for conf_idx = 4:4
    [combined_V, combined_F] = combine_all_meshes(all_3d_models_by_confidence{conf_idx});
    combined_meshes{conf_idx} = struct('V', combined_V, 'F', combined_F, ...
                                       'confidence_idx', conf_idx, ...
                                       'confidence_name', confidence_names{conf_idx});
    
    % 保存每个置信区间的三维模型
    save(sprintf('fracture_3d_model_confidence_%d.mat', conf_idx), ...
         'combined_V', 'combined_F', '-v7.3');
end

visualize_sweep_loft(centerline, V, F, upper_surface, lower_surface);
toc
