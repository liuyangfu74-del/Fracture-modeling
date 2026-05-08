function [results, params_mean, post_samples] = bayesian_mcmc_inversion(data_file, varargin)
% BAYESIAN_MCMC_INVERSION 贝叶斯MCMC反演函数
%
% 输入:
%   data_file: 数据文件路径，包含h_surface和L_surface变量
%   可选参数 (Name-Value pairs):
%     'n_chains': MCMC链数，默认4
%     'n_iter': 每链迭代次数，默认30000
%     'n_burn': 烧入期长度，默认70
%     'n_thin': 稀释间隔，默认1
%     'train_ratio': 训练集比例，默认0.8
%     'scale_factor': 开度缩放因子，默认10（mm转cm）
%     'use_parallel': 是否使用并行，默认true
%     'verbose': 显示详细信息，默认true
%
% 输出:
%   results: 包含所有结果的完整结构体
%   params_mean: 后验均值参数结构体
%   post_samples: 后验样本结构体

%% 参数解析
p = inputParser;
addRequired(p, 'data_file', @ischar);
addParameter(p, 'n_chains', 4, @(x) isscalar(x) && x > 0);
addParameter(p, 'n_iter', 30000, @(x) isscalar(x) && x > 0);
addParameter(p, 'n_burn', 10, @(x) isscalar(x) && x >= 0);
addParameter(p, 'n_thin', 1, @(x) isscalar(x) && x > 0);
addParameter(p, 'train_ratio', 0.8, @(x) isscalar(x) && x > 0 && x < 1);
addParameter(p, 'scale_factor', 10, @(x) isscalar(x) && x > 0);
addParameter(p, 'use_parallel', true, @islogical);
addParameter(p, 'verbose', true, @islogical);
parse(p, data_file, varargin{:});

% 提取参数
n_chains = p.Results.n_chains;
n_iter = p.Results.n_iter;
n_burn = p.Results.n_burn;
n_thin = p.Results.n_thin;
train_ratio = p.Results.train_ratio;
scale_factor = p.Results.scale_factor;
use_parallel = p.Results.use_parallel;
verbose = p.Results.verbose;

%% 1. 数据加载与预处理
if verbose
    fprintf('=== 贝叶斯MCMC反演 ===\n');
    fprintf('加载数据: %s\n', data_file);
end

% 加载数据
if ~exist(data_file, 'file')
    error('数据文件不存在: %s', data_file);
end

data = load(data_file);

% 检查数据变量
if ~isfield(data, 'h_surface') || ~isfield(data, 'L_surface')
    error('数据文件必须包含h_surface和L_surface变量');
end

% 提取并预处理数据
h_surface = data.h_surface(:);
L_surface = data.L_surface(:);

% 单位转换（mm → cm）
h_surface = h_surface .* scale_factor;

% 检查数据长度
if length(h_surface) ~= length(L_surface)
    warning('开度(%d)和迹长(%d)数据长度不一致，进行匹配处理', ...
            length(h_surface), length(L_surface));
    min_len = min(length(h_surface), length(L_surface));
    h_surface = h_surface(1:min_len);
    L_surface = L_surface(1:min_len);
end

h_observed = h_surface;
L_true = L_surface;
n_fractures = length(h_observed);

if verbose
    fprintf('数据加载成功: %d 个裂隙\n', n_fractures);
    fprintf('开度范围: %.4f - %.4f mm\n', min(h_observed)/scale_factor, max(h_observed)/scale_factor);
    fprintf('迹长范围: %.4f - %.4f m\n', min(L_true), max(L_true));
end

%% 2. 数据分割
indices = randperm(n_fractures);
n_train = round(train_ratio * n_fractures);
train_idx = indices(1:n_train);
val_idx = indices(n_train+1:end);

h_train = h_observed(train_idx);
L_train = L_true(train_idx);
h_val = h_observed(val_idx);
L_val = L_true(val_idx);

if verbose
    fprintf('数据分割: 训练集 %d, 验证集 %d\n', length(h_train), length(h_val));
end

%% 3. 模型定义
forward_model = @(params, L) ...
    max(1e-10, params.eta * params.alpha_I * (L .^ params.beta_I) + ...
    (1-params.eta) * params.alpha_II * (L .^ params.beta_II));

log_likelihood = @(params) ...
    -0.5 * length(h_train) * log(2*pi*params.sigma^2) ...
    - 0.5 * sum((log(h_train) - log(forward_model(params, L_train))).^2) / params.sigma^2;
% 半正态分布的概率密度函数
halfnormpdf = @(x, scale) sqrt(2/(pi*scale^2)) * exp(-x.^2/(2*scale^2)) .* (x >= 0);
log_prior = @(params) ...
    log(betapdf(params.eta, 1, 1)) + ...
    log(lognpdf(params.alpha_I, log(0.02), 0.3)) + ...
    log(lognpdf(params.alpha_II, log(0.02), 0.3)) + ...
    log(normpdf(params.beta_I, 0.7, 0.1)) + ...
    log(normpdf(params.beta_II, 0.5, 0.1)) + ...
    log(halfnormpdf(params.sigma, 0.5));  

log_posterior = @(params) log_likelihood(params) + log_prior(params);

%% 4. MCMC采样
if verbose
    fprintf('\n开始 %d 链 MCMC 采样...\n', n_chains);
end

% 初始化参数
initial_params = cell(n_chains, 1);
for chain = 1:n_chains
    switch chain
        case 1  % I型主导
            initial_params{chain} = struct(...
                'eta', 0.9, ...
                'alpha_I', median(h_train)/median(L_train)^0.7, ...
                'beta_I', 0.7, ...
                'alpha_II', median(h_train)/median(L_train)^0.5, ...
                'beta_II', 0.5, ...
                'sigma', 0.1);
        case 2  % 混合型
            initial_params{chain} = struct(...
                'eta', 0.6, ...
                'alpha_I', median(h_train)/median(L_train)^0.7 * 0.8, ...
                'beta_I', 0.6, ...
                'alpha_II', median(h_train)/median(L_train)^0.5 * 1.2, ...
                'beta_II', 0.45, ...
                'sigma', 0.15);
        case 3  % II型主导
            initial_params{chain} = struct(...
                'eta', 0.3, ...
                'alpha_I', median(h_train)/median(L_train)^0.7 * 0.6, ...
                'beta_I', 0.5, ...
                'alpha_II', median(h_train)/median(L_train)^0.5 * 1.5, ...
                'beta_II', 0.55, ...
                'sigma', 0.2);
        case 4  % 随机探索
            initial_params{chain} = struct(...
                'eta', 0.5 + 0.4*randn, ...
                'alpha_I', median(h_train)/median(L_train)^0.7 * (0.8 + 0.4*rand), ...
                'beta_I', 0.6 + 0.3*rand, ...
                'alpha_II', median(h_train)/median(L_train)^0.5 * (0.8 + 0.4*rand), ...
                'beta_II', 0.4 + 0.3*rand, ...
                'sigma', 0.1 + 0.1*rand);
    end
    
    % 边界约束
    initial_params{chain}.eta = max(0.1, min(0.99, initial_params{chain}.eta));
    initial_params{chain}.alpha_I = max(0.001, min(0.1, initial_params{chain}.alpha_I));
    initial_params{chain}.beta_I = max(0.5, min(1.0, initial_params{chain}.beta_I));
    initial_params{chain}.alpha_II = max(0.001, min(0.1, initial_params{chain}.alpha_II));
    initial_params{chain}.beta_II = max(0.3, min(0.7, initial_params{chain}.beta_II));
    initial_params{chain}.sigma = max(0.01, min(0.5, initial_params{chain}.sigma));
    
    if verbose
        fprintf('链%d初始: η=%.3f, β_I=%.3f, β_II=%.3f\n', ...
            chain, initial_params{chain}.eta, initial_params{chain}.beta_I, initial_params{chain}.beta_II);
    end
end

% 存储结果
all_chains_samples = cell(n_chains, 1);
all_chains_accept = zeros(n_chains, 1);
all_logpost = cell(n_chains, 1);

% 运行MCMC链
for chain = 1:n_chains
    if verbose
        fprintf('\n--- 运行链 %d/%d ---\n', chain, n_chains);
    end
    
    current_params = initial_params{chain};
    current_logpost = log_posterior(current_params);
    
    samples = zeros(n_iter, 6);
    logpost_trace = zeros(n_iter, 1);
    proposal_sd = [0.15, 0.03, 0.06, 0.03, 0.06, 0.09];
    accept_count = 0;
    
    for iter = 1:n_iter
        proposed_params = current_params;
        param_idx = randi(6);
        
        switch param_idx
            case 1  % η
                proposed_raw = current_params.eta + proposal_sd(1) * randn;
                proposed_params.eta = reflect_boundary(proposed_raw, 0.1, 0.99);
            case 2  % α_I
                proposed_raw = current_params.alpha_I * exp(proposal_sd(2) * randn);
                proposed_params.alpha_I = reflect_boundary(proposed_raw, 0.001, 0.1);
            case 3  % β_I
                proposed_raw = current_params.beta_I + proposal_sd(3) * randn;
                proposed_params.beta_I = reflect_boundary(proposed_raw, 0.5, 1.0);  
            case 4  % α_II
                proposed_raw = current_params.alpha_II * exp(proposal_sd(4) * randn);
                proposed_params.alpha_II = reflect_boundary(proposed_raw, 0.001, 0.1);
            case 5  % β_II
                proposed_raw = current_params.beta_II + proposal_sd(5) * randn;
                proposed_params.beta_II = reflect_boundary(proposed_raw, 0.3, 0.7);
            case 6  % σ
                proposed_raw = current_params.sigma * exp(proposal_sd(6) * randn);
                proposed_params.sigma = reflect_boundary(proposed_raw, 0.01, 0.5);
        end
        
        % Metropolis-Hastings
        try
            proposed_logpost = log_posterior(proposed_params);
            if isfinite(proposed_logpost)
                log_alpha = proposed_logpost - current_logpost;
                if log(rand) < log_alpha
                    current_params = proposed_params;
                    current_logpost = proposed_logpost;
                    accept_count = accept_count + 1;
                end
            end
        catch
            % 出错则拒绝
        end
        
        % 存储
        samples(iter, :) = [current_params.eta, current_params.alpha_I, ...
                           current_params.beta_I, current_params.alpha_II, ...
                           current_params.beta_II, current_params.sigma];
        logpost_trace(iter) = current_logpost;
        
        % 进度显示
        if verbose && mod(iter, 5000) == 0
            fprintf('  链%d: 迭代 %d/%d, η=%.3f, 接受率=%.3f\n', ...
                chain, iter, n_iter, current_params.eta, accept_count/iter);
        end
    end
    
    all_chains_samples{chain} = samples;
    all_chains_accept(chain) = accept_count / n_iter;
    all_logpost{chain} = logpost_trace;
    
    if verbose
        fprintf('链%d完成: 接受率=%.3f\n', chain, all_chains_accept(chain));
    end
end

%% 5. 后处理
if verbose
    fprintf('\n合并样本与计算后验统计...\n');
end

% 合并样本（后烧入）
all_samples = [];
for chain = 1:n_chains
    burned_samples = all_chains_samples{chain}(n_burn+1:n_thin:end, :);
    all_samples = [all_samples; burned_samples];
end

% 计算后验统计
param_names = {'eta', 'alpha_I', 'beta_I', 'alpha_II', 'beta_II', 'sigma'};
post_stats = struct();
post_samples = struct();

for i = 1:6
    samples = all_samples(:, i);
    post_samples.(param_names{i}) = samples;
    
    post_stats.([param_names{i} '_mean']) = mean(samples);
    post_stats.([param_names{i} '_median']) = median(samples);
    post_stats.([param_names{i} '_std']) = std(samples);
    post_stats.([param_names{i} '_ci95']) = prctile(samples, [2.5, 97.5]);
    post_stats.([param_names{i} '_ci90']) = prctile(samples, [5, 95]);
end

% 创建参数均值结构体
params_mean = struct(...
    'eta', post_stats.eta_mean, ...
    'alpha_I', post_stats.alpha_I_mean, ...
    'beta_I', post_stats.beta_I_mean, ...
    'alpha_II', post_stats.alpha_II_mean, ...
    'beta_II', post_stats.beta_II_mean, ...
    'sigma', post_stats.sigma_mean);

%% 6. 模型验证
if verbose
    fprintf('\n模型验证...\n');
end

% 训练集性能
h_pred_train = forward_model(params_mean, L_train);
train_residuals = h_pred_train - h_train;
R2_train = 1 - sum(train_residuals.^2) / sum((h_train - mean(h_train)).^2);

% 验证集性能
h_pred_val = forward_model(params_mean, L_val);
val_residuals = h_pred_val - h_val;
R2_val = 1 - sum(val_residuals.^2) / sum((h_val - mean(h_val)).^2);

% 迹长预测验证
if verbose
    fprintf('验证集迹长预测...\n');
end

n_val = length(h_val);
n_post_samples = min(200, length(post_samples.eta));

% 准备参数样本
params_cell = cell(n_post_samples, 1);
for s = 1:n_post_samples
    params_cell{s} = struct(...
        'eta', post_samples.eta(s), ...
        'alpha_I', post_samples.alpha_I(s), ...
        'beta_I', post_samples.beta_I(s), ...
        'alpha_II', post_samples.alpha_II(s), ...
        'beta_II', post_samples.beta_II(s));
end
params_samples = [params_cell{:}];

% 批量预测
if use_parallel && license('test', 'Distrib_Computing_Toolbox')
    try
        if isempty(gcp('nocreate'))
            parpool('local', min(4, feature('numcores')));
        end
        L_val_pred_samples = inverse_model_batch_parallel(h_val, params_samples, n_post_samples);
    catch
        L_val_pred_samples = inverse_model_batch_serial(h_val, params_samples, n_post_samples);
    end
else
    L_val_pred_samples = inverse_model_batch_serial(h_val, params_samples, n_post_samples);
end

% 计算预测统计
L_val_pred_median = median(L_val_pred_samples, 2);
L_val_pred_mean = mean(L_val_pred_samples, 2);
L_val_pred_std = std(L_val_pred_samples, 0, 2);
L_val_pred_ci90 = prctile(L_val_pred_samples, [5, 95], 2);
L_val_pred_ci95 = prctile(L_val_pred_samples, [2.5, 97.5], 2);

% 性能指标
val_errors = L_val_pred_median - L_val;
performance = struct();
performance.R2 = 1 - sum(val_errors.^2) / sum((L_val - mean(L_val)).^2);
performance.MAE = mean(abs(val_errors));
performance.RMSE = sqrt(mean(val_errors.^2));
performance.MAPE = mean(abs(val_errors ./ L_val)) * 100;
performance.ci90_coverage = mean(L_val >= L_val_pred_ci90(:,1) & L_val <= L_val_pred_ci90(:,2)) * 100;
performance.ci95_coverage = mean(L_val >= L_val_pred_ci95(:,1) & L_val <= L_val_pred_ci95(:,2)) * 100;

%% 7. 为点云裂隙预测准备函数
% 创建预测函数
predict_func = @(h_values) predict_trace_length_batch(h_values, params_mean, post_samples, n_post_samples);

%% 7.5 创建多分位数预测函数
% 定义需要的分位数
quantile_levels = [0.35, 0.50, 0.65, 0.80, 0.95];
quantile_names = {'保守估计', '最可能估计', '较可能估计', '较乐观估计', '乐观估计'};

% 创建多分位数预测函数
multi_quantile_func = @(h_values) predict_trace_length_multiple_quantiles(...
    h_values, params_mean, post_samples, n_post_samples, quantile_levels, quantile_names);

%% 7.6 为5个分位数生成代表性参数集
if verbose
    fprintf('\n生成5个分位数的代表性参数集...\n');
end

% 从后验样本中提取5组代表性参数（对应5个分位数）
n_total_samples = length(post_samples.eta);
quantile_positions = round(quantile_levels * n_total_samples);  % 使用之前定义的quantile_levels

representative_params_cell = cell(5, 1);      % 修改变量名
quantile_param_sets_cell = cell(5, 1);        % 修改变量名
predict_funcs_by_quantile = cell(5, 1);       % 修改变量名

for q = 1:5
    idx = quantile_positions(q);
    
    % 按分位数在参数样本中的位置提取参数
    representative_params_cell{q} = struct(...
        'eta', post_samples.eta(idx), ...
        'alpha_I', post_samples.alpha_I(idx), ...
        'beta_I', post_samples.beta_I(idx), ...
        'alpha_II', post_samples.alpha_II(idx), ...
        'beta_II', post_samples.beta_II(idx), ...
        'sigma', post_samples.sigma(idx));
    
    % 也存储一个简化的版本
    quantile_param_sets_cell{q} = struct(...
        'eta', post_samples.eta(idx), ...
        'alpha_I', post_samples.alpha_I(idx), ...
        'beta_I', post_samples.beta_I(idx), ...
        'alpha_II', post_samples.alpha_II(idx), ...
        'beta_II', post_samples.beta_II(idx));
    
    % 为每个分位数创建独立的预测函数
    params_q = quantile_param_sets_cell{q};
    predict_funcs_by_quantile{q} = @(h_values) predict_trace_length_for_single_params(...
        h_values, params_q);
end

if verbose
    fprintf('5组代表性参数生成完成\n');
    for q = 1:5
        params_q = quantile_param_sets_cell{q};
        fprintf('  分位数 %d (%.0f%%): η=%.3f, β_I=%.3f, β_II=%.3f\n', ...
            q, quantile_levels(q)*100, params_q.eta, params_q.beta_I, params_q.beta_II);
    end
end
%% 7.5 预测不确定性可视化
create_uncertainty_visualization(L_val, L_val_pred_median, L_val_pred_ci90, performance);

%% 7.6 为7个关键置信区间生成代表性参数集
if verbose
    fprintf('\n生成7个关键置信区间的代表性参数集...\n');
end

% 定义7个关键置信区间
confidence_levels = [0.025, 0.35, 0.50, 0.65, 0.80, 0.975, 0.50];  % 50%出现两次，一次为"最可能"，一次为"概率最大点"
confidence_names = {
    '95%置信下限',   % 0.025 (2.5%)
    '保守估计35%',   % 0.35
    '最可能估计50%',  % 0.50
    '较可能估计65%',  % 0.65
    '较乐观估计80%',  % 0.80
    '95%置信上限',   % 0.975 (97.5%)
    '概率最大点'      % 后验均值
};

% 获取样本总数
n_total_samples = length(post_samples.eta);

% 为前6个分位数计算位置
quantile_positions = zeros(6, 1);
for i = 1:6
    quantile_positions(i) = round(confidence_levels(i) * n_total_samples);
    quantile_positions(i) = max(1, min(n_total_samples, quantile_positions(i)));
end

% 存储7组参数
representative_params_cell = cell(7, 1);
quantile_param_sets_cell = cell(7, 1);
predict_funcs_by_quantile = cell(7, 1);

for q = 1:7
    if q <= 6
        % 前6个：从后验样本中提取对应分位数的参数
        idx = quantile_positions(q);
        
        representative_params_cell{q} = struct(...
            'eta', post_samples.eta(idx), ...
            'alpha_I', post_samples.alpha_I(idx), ...
            'beta_I', post_samples.beta_I(idx), ...
            'alpha_II', post_samples.alpha_II(idx), ...
            'beta_II', post_samples.beta_II(idx), ...
            'sigma', post_samples.sigma(idx));
        
        quantile_param_sets_cell{q} = struct(...
            'eta', post_samples.eta(idx), ...
            'alpha_I', post_samples.alpha_I(idx), ...
            'beta_I', post_samples.beta_I(idx), ...
            'alpha_II', post_samples.alpha_II(idx), ...
            'beta_II', post_samples.beta_II(idx));
        
    else
        % 第7个：概率最大点（后验均值）
        representative_params_cell{q} = struct(...
            'eta', post_stats.eta_mean, ...
            'alpha_I', post_stats.alpha_I_mean, ...
            'beta_I', post_stats.beta_I_mean, ...
            'alpha_II', post_stats.alpha_II_mean, ...
            'beta_II', post_stats.beta_II_mean, ...
            'sigma', post_stats.sigma_mean);
        
        quantile_param_sets_cell{q} = struct(...
            'eta', post_stats.eta_mean, ...
            'alpha_I', post_stats.alpha_I_mean, ...
            'beta_I', post_stats.beta_I_mean, ...
            'alpha_II', post_stats.alpha_II_mean, ...
            'beta_II', post_stats.beta_II_mean);
    end
    
    % 为每个置信区间创建独立的预测函数
    params_q = quantile_param_sets_cell{q};
    predict_funcs_by_quantile{q} = @(h_values) predict_trace_length_for_single_params(...
        h_values, params_q);
end

if verbose
    fprintf('7组代表性参数生成完成\n');
    for q = 1:7
        params_q = quantile_param_sets_cell{q};
        if q <= 6
            conf_percent = round(confidence_levels(q) * 100);
            fprintf('  置信区间 %d (%s): η=%.3f, β_I=%.3f, β_II=%.3f\n', ...
                q, confidence_names{q}, params_q.eta, params_q.beta_I, params_q.beta_II);
        else
            fprintf('  概率最大点: η=%.3f, β_I=%.3f, β_II=%.3f (后验均值)\n', ...
                params_q.eta, params_q.beta_I, params_q.beta_II);
        end
    end
end

%% 8. 打包结果
results = struct();
results.params_mean = params_mean;
results.post_samples = post_samples;
results.post_stats = post_stats;
results.performance = performance;
results.train_stats = struct('R2', R2_train);
results.val_stats = struct('R2', R2_val);
results.scale_factor = scale_factor;
results.data_info = struct(...
    'n_total', n_fractures, ...
    'n_train', length(h_train), ...
    'n_val', length(h_val), ...
    'h_range', [min(h_observed)/scale_factor, max(h_observed)/scale_factor], ...
    'L_range', [min(L_true), max(L_true)]);
results.mcmc_info = struct(...
    'n_chains', n_chains, ...
    'n_iter', n_iter, ...
    'n_burn', n_burn, ...
    'n_thin', n_thin, ...
    'accept_rates', all_chains_accept, ...
    'n_samples', size(all_samples, 1));
results.predict_func = predict_func;
results.multi_quantile_func = multi_quantile_func;  % 添加多分位数函数
results.forward_model = forward_model;
results.quantile_levels = quantile_levels;
results.quantile_names = quantile_names;

% === 新增：添加5组不同参数的预测函数 ===
results.predict_funcs_by_quantile = predict_funcs_by_quantile;  % 这行是关键的！
results.representative_params = representative_params_cell;     % 存储5组参数
results.quantile_param_sets = quantile_param_sets_cell;         % 简化版参数

% 存储验证集预测结果（用于参考）
results.validation_predictions = struct(...
    'h_val', h_val, ...
    'L_val', L_val, ...
    'L_pred_median', L_val_pred_median, ...
    'L_pred_mean', L_val_pred_mean, ...
    'L_pred_std', L_val_pred_std, ...
    'L_pred_ci90', L_val_pred_ci90, ...
    'L_pred_ci95', L_val_pred_ci95, ...
    'L_pred_samples', L_val_pred_samples);
end

%% 辅助函数
function L_pred_samples = inverse_model_batch_serial(h_vector, params_samples, n_samples)
    % 串行批量预测
    n_h = length(h_vector);
    L_pred_samples = zeros(n_h, n_samples);
    
    for s = 1:n_samples
        params = params_samples(s);
        for i = 1:n_h
            L_pred_samples(i, s) = inverse_model_robust(h_vector(i), params);
        end
    end
end

function L_pred_samples = inverse_model_batch_parallel(h_vector, params_samples, n_samples)
    % 并行批量预测
    n_h = length(h_vector);
    L_pred_samples = zeros(n_h, n_samples);
    
    parfor s = 1:n_samples
        params = params_samples(s);
        L_samples = zeros(n_h, 1);
        for i = 1:n_h
            L_samples(i) = inverse_model_robust(h_vector(i), params);
        end
        L_pred_samples(:, s) = L_samples;
    end
end

function [L_pred, L_ci90] = predict_trace_length_batch(h_values, params_mean, post_samples, n_samples)
    % 批量预测迹长及置信区间
    % 输入: h_values (开度值, mm)
    % 输出: 
    %   L_pred: 预测迹长均值/中位数 (m)
    %   L_ci90: 90%置信区间 [lower, upper]
    
    % 注意: 输入的开度需要乘以scale_factor（在函数内部处理）
    
    n_h = length(h_values);
    L_samples = zeros(n_h, n_samples);
    
    % 从后验采样参数
    sample_indices = randi(length(post_samples.eta), n_samples, 1);
    
    for s = 1:n_samples
        idx = sample_indices(s);
        params = struct(...
            'eta', post_samples.eta(idx), ...
            'alpha_I', post_samples.alpha_I(idx), ...
            'beta_I', post_samples.beta_I(idx), ...
            'alpha_II', post_samples.alpha_II(idx), ...
            'beta_II', post_samples.beta_II(idx));
        
        for i = 1:n_h
            % 注意: inverse_model_robust期望开度单位为训练时的单位（mm*scale_factor）
            L_samples(i, s) = inverse_model_robust(h_values(i), params);
        end
    end
    
    % 计算统计量
    L_pred = median(L_samples, 2);  % 使用中位数作为预测值
    L_ci90 = prctile(L_samples, [5, 95], 2);
end

function [L_pred, exit_flag] = inverse_model_robust(h, params, L_range)
    % 稳健的迹长反演函数
    if nargin < 3
        L_range = [0.1, 100];
    end
    
    % 混合断裂模型
    forward_func = @(L) params.eta * params.alpha_I * (L .^ params.beta_I) + ...
                       (1 - params.eta) * params.alpha_II * (L .^ params.beta_II);
    
    % 目标函数
    f = @(L) forward_func(L) - h;
    
    try
        options = optimset('Display', 'off', 'TolX', 1e-6);
        L_pred = fzero(f, L_range, options);
        exit_flag = 1;
    catch
        % 失败时使用解析近似
        if params.eta > 0.5
            L_pred = (h / params.alpha_I)^(1/params.beta_I);
        else
            L_pred = (h / params.alpha_II)^(1/params.beta_II);
        end
        L_pred = max(L_range(1), min(L_range(2), L_pred));
        exit_flag = 0;
    end
end

function value = reflect_boundary(value, lower, upper)
    % 反射边界函数：当值超出边界时进行反射
    while value < lower || value > upper
        if value < lower
            value = 2*lower - value;  % 从下边界反射
        elseif value > upper
            value = 2*upper - value;  % 从上边界反射
        end
    end
end

function L_quantiles = predict_trace_length_multiple_quantiles(...
    h_values, params_mean, post_samples, n_samples, quantile_levels, quantile_names)
% 预测多个分位数的迹长
% 简化的版本：只返回迹长矩阵，不返回复杂结构体

    n_h = length(h_values);
    n_quantiles = length(quantile_levels);
    
    % 采样迹长
    L_samples = zeros(n_h, n_samples);
    
    % 从后验采样参数
    sample_indices = randi(length(post_samples.eta), n_samples, 1);
    
    for s = 1:n_samples
        idx = sample_indices(s);
        params = struct(...
            'eta', post_samples.eta(idx), ...
            'alpha_I', post_samples.alpha_I(idx), ...
            'beta_I', post_samples.beta_I(idx), ...
            'alpha_II', post_samples.alpha_II(idx), ...
            'beta_II', post_samples.beta_II(idx));
        
        for i = 1:n_h
            L_samples(i, s) = inverse_model_robust(h_values(i), params);
        end
    end
    
    % 计算所有分位数
    L_quantiles = zeros(n_h, n_quantiles);
    for q = 1:n_quantiles
        L_quantiles(:, q) = prctile(L_samples, quantile_levels(q)*100, 2);
    end
end

function L_pred = predict_trace_length_for_single_params(h_values, params)
    % 使用单组参数预测迹长
    n_h = length(h_values);
    L_pred = zeros(n_h, 1);
    
    for i = 1:n_h
        L_pred(i) = inverse_model_robust(h_values(i), params);
    end
end

function create_uncertainty_visualization(L_true, L_pred, L_ci90, performance)
    % 预测不确定性可视化函数
    
    figure('Position', [100, 100, 1400, 900], 'Name', 'Prediction Uncertainty Visualization', 'Color', 'white');
    
    % 按预测值排序
    [L_pred_sorted, idx] = sort(L_pred);
    L_ci_sorted = L_ci90(idx, :);
    L_true_sorted = L_true(idx);
    
    n_samples = length(L_pred_sorted);
    
    % 置信区间填充
    fill_x = [1:n_samples, n_samples:-1:1];
    fill_y = [L_ci_sorted(:,1); flipud(L_ci_sorted(:,2))];
    
    fill_handle = fill(fill_x, fill_y, [0.8, 0.9, 1.0], ...
                      'EdgeColor', 'none', 'FaceAlpha', 0.5, 'DisplayName', '90% CI');
    hold on;
    
    % 预测中位数
    pred_handle = plot(1:n_samples, L_pred_sorted, 'b-', ...
                      'LineWidth', 3, 'DisplayName', 'Prediction Median');
    
    % 真实值
    true_handle = scatter(1:n_samples, L_true_sorted, 50, 'r', 'filled', ...
                         'MarkerFaceAlpha', 0.7, 'LineWidth', 1.5, 'DisplayName', 'True Values');
    
    xlabel('Sample Index (Sorted by Prediction)', 'FontSize', 32, 'FontName', 'Times New Roman');
    ylabel('Trace Length (m)', 'FontSize', 32, 'FontName', 'Times New Roman');
    title('Prediction Uncertainty Visualization', ...
          'FontSize', 36, 'FontName', 'Times New Roman', 'FontWeight', 'bold');
    
    legend([fill_handle, pred_handle, true_handle], 'Location', 'best', ...
           'FontSize', 28, 'FontName', 'Times New Roman');
    
    box on;
    set(gca, 'FontSize', 26, 'FontName', 'Times New Roman', 'LineWidth', 2);
    
    % 设置Y轴刻度标签
    y_ticks = get(gca, 'YTick');
    y_tick_labels = arrayfun(@(x) sprintf('%.1f', x), y_ticks, 'UniformOutput', false);
    set(gca, 'YTickLabel', y_tick_labels);
end