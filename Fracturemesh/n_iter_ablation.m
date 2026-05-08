%% =============== n_iter 参数消融实验 ===============
clear; clc; close all;

%% =============== 1. 数据加载与预处理 ===============
fprintf('=== 1. 裂隙数据加载与预处理 ===\n');

% 加载实际数据
load('C:\Users\Administrator\Desktop\2..mat');
h_surface = h_surface.*10;
% 检查数据变量名并提取
if exist('h_surface', 'var') && exist('L_surface', 'var')
    h_observed = h_surface(:)*1;  % 确保是列向量
    L_true = L_surface(:);      % 确保是列向量
    
    % 检查数据长度一致
    if length(h_observed) ~= length(L_true)
        fprintf('警告：开度数据(%d个)和迹长数据(%d个)长度不一致！\n', ...
                length(h_observed), length(L_true));
        % 取最小长度
        min_len = min(length(h_observed), length(L_true));
        h_observed = h_observed(1:min_len);
        L_true = L_true(1:min_len);
    end
    
    n_fractures = length(h_observed);
    fprintf('成功加载实际数据: %d 个裂隙\n', n_fractures);
    
elseif exist('all_apertures', 'var') && exist('all_traceLengths', 'var')
    % 使用之前代码中的变量名
    h_observed = all_apertures(:);
    L_true = all_traceLengths(:);
    
    % 检查数据长度一致
    if length(h_observed) ~= length(L_true)
        fprintf('警告：数据长度不一致，进行匹配处理...\n');
        min_len = min(length(h_observed), length(L_true));
        h_observed = h_observed(1:min_len);
        L_true = L_true(1:min_len);
    end
    
    n_fractures = length(h_observed);
    fprintf('成功加载实际数据: %d 个裂隙\n', n_fractures);
    
else
    fprintf('错误：未找到开度(h_surface)和迹长(L_surface)数据！\n');
    fprintf('文件中存在的变量：\n');
    whos
    
    % 尝试查找类似变量
    vars = who;
    h_var = vars(contains(vars, {'h', 'aperture', '开度'}, 'IgnoreCase', true));
    L_var = vars(contains(vars, {'L', 'trace', 'length', '迹长'}, 'IgnoreCase', true));

    fprintf('找到可能的开度变量: %s\n', h_var{1});
    fprintf('找到可能的迹长变量: %s\n', L_var{1});
        
    eval(sprintf('h_observed = %s(:);', h_var{1}));
    eval(sprintf('L_true = %s(:);', L_var{1}));
        
    % 检查数据长度
    if length(h_observed) ~= length(L_true)
        min_len = min(length(h_observed), length(L_true));
        h_observed = h_observed(1:min_len);
        L_true = L_true(1:min_len);
    end
        
    n_fractures = length(h_observed);
    fprintf('使用变量 %s 和 %s，共 %d 个数据\n', h_var{1}, L_var{1}, n_fractures);
end

% 数据质量检查
fprintf('\n数据质量检查:\n');
fprintf('开度范围: %.4f - %.4f mm\n', min(h_observed), max(h_observed));
fprintf('迹长范围: %.4f - %.4f m\n', min(L_true), max(L_true));
fprintf('开度中位数: %.4f mm, 迹长中位数: %.4f m\n', median(h_observed), median(L_true));

fprintf('最终有效数据: %d 个裂隙\n', n_fractures);

%% =============== 2. 物理模型定义（混合断裂模型） ===============
fprintf('\n=== 2. 物理模型定义 ===\n');
fprintf('混合断裂力学模型:\n');
fprintf('  h = η × α_I × L^{β_I} + (1-η) × α_II × L^{β_II}\n');
fprintf('参数物理意义:\n');
fprintf('  η: 混合比，I型裂隙占比 (0-1)\n');
fprintf('  α_I, β_I: I型(张开型)裂隙参数\n');
fprintf('  α_II, β_II: II型(滑开型)裂隙参数\n');
fprintf('理论约束:\n');
fprintf('  β_I ∈ [0.5, 1.0], β_II ∈ [0.3, 0.7]\n');
fprintf('  地质先验: η通常接近1（张开型主导）\n');

%% =============== 3. n_iter 消融实验主循环 ===============
fprintf('\n=== 3. n_iter 参数消融实验 ===\n');

% 定义要测试的n_iter值
n_iter_values = 500:5000:30000;
n_experiments = length(n_iter_values);

fprintf('将测试 %d 个不同的 n_iter 值:\n', n_experiments);
fprintf('n_iter = ');
fprintf('%d ', n_iter_values);
fprintf('\n\n');

% 数据分割 (固定不变)
train_ratio = 0.8;
n_train = round(train_ratio * n_fractures);
indices = randperm(n_fractures);
train_idx = indices(1:n_train);
val_idx = indices(n_train+1:end);

h_train = h_observed(train_idx);
L_train = L_true(train_idx);
h_val = h_observed(val_idx);
L_val = L_true(val_idx);

% 初始化存储所有实验结果的数组
experiment_results = cell(n_experiments, 1);
experiment_stats = struct();

% 定义统一的模型函数 (所有实验共享)
forward_model = @(params, L) ...
    max(1e-10, params.eta * params.alpha_I * (L .^ params.beta_I) + ...
    (1-params.eta) * params.alpha_II * (L .^ params.beta_II));

log_likelihood = @(params) ...
    -0.5 * length(h_train) * log(2*pi*params.sigma^2) ...
    - 0.5 * sum((log(h_train) - log(forward_model(params, L_train))).^2) / params.sigma^2;

log_prior = @(params) ...
    log(betapdf(params.eta, 8, 2)) + ...
    log(lognpdf(params.alpha_I, log(0.02), 0.3)) + ...
    log(lognpdf(params.alpha_II, log(0.02), 0.3)) + ...
    log(normpdf(params.beta_I, 0.7, 0.1)) + ...
    log(normpdf(params.beta_II, 0.5, 0.1)) + ...
    log(exppdf(params.sigma, 0.1));

log_posterior = @(params) log_likelihood(params) + log_prior(params);

% 主循环：对每个n_iter值运行完整的MCMC
for exp_idx = 1:n_experiments
    n_iter = n_iter_values(exp_idx);
    fprintf('\n=== 实验 %d/%d: n_iter = %d ===\n', exp_idx, n_experiments, n_iter);
    
    % 基础设置 (基于当前n_iter)
    n_chains = 4;  % 4条链
    n_burn = round(0.1 * n_iter);  % 老化期为10%
    n_thin = max(1, round(n_iter / 1000));  % 稀疏采样
    
    % 为每条链设置不同的初始点
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
    end
    
    % 存储所有链的结果
    all_chains_samples = cell(n_chains, 1);
    all_chains_accept = zeros(n_chains, 1);
    
    % 运行4条链
    fprintf('开始运行%d条MCMC链...\n', n_chains);
    
    for chain = 1:n_chains
        fprintf('\n--- 运行链 %d/%d ---\n', chain, n_chains);
        
        % 当前链的初始参数
        current_params = initial_params{chain};
        current_logpost = log_posterior(current_params);
        
        % 存储
        samples = zeros(n_iter, 6);
        logpost_trace = zeros(n_iter, 1);
        
        % 提议步长
%         proposal_sd = [0.03, 0.006, 0.012, 0.006, 0.012, 0.018];
        proposal_sd = [0.05, 0.01, 0.02, 0.01, 0.02, 0.03];
        accept_count = 0;
        
        for iter = 1:n_iter
            % 复制当前参数
            proposed_params = current_params;
            
            % 随机更新一个参数
            param_idx = randi(6);
            switch param_idx
                case 1  % η
                    proposed_params.eta = current_params.eta + proposal_sd(1) * randn;
                    proposed_params.eta = max(0.1, min(0.99, proposed_params.eta));
                case 2  % α_I
                    proposed_params.alpha_I = current_params.alpha_I * exp(proposal_sd(2) * randn);
                    proposed_params.alpha_I = max(0.001, min(0.1, proposed_params.alpha_I));
                case 3  % β_I
                    proposed_params.beta_I = current_params.beta_I + proposal_sd(3) * randn;
                    proposed_params.beta_I = max(0.5, min(1.0, proposed_params.beta_I));
                case 4  % α_II
                    proposed_params.alpha_II = current_params.alpha_II * exp(proposal_sd(4) * randn);
                    proposed_params.alpha_II = max(0.001, min(0.1, proposed_params.alpha_II));
                case 5  % β_II
                    proposed_params.beta_II = current_params.beta_II + proposal_sd(5) * randn;
                    proposed_params.beta_II = max(0.3, min(0.7, proposed_params.beta_II));
                case 6  % σ
                    proposed_params.sigma = current_params.sigma * exp(proposal_sd(6) * randn);
                    proposed_params.sigma = max(0.01, min(0.5, proposed_params.sigma));
            end
            
            % 计算接受概率
            try
                proposed_logpost = log_posterior(proposed_params);
                
                if isfinite(proposed_logpost)
                    log_alpha = proposed_logpost - current_logpost;
                    
                    % 接受或拒绝
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
            if mod(iter, max(1, floor(n_iter/10))) == 0
                accept_rate = accept_count / iter;
                fprintf('  链%d: 迭代 %d/%d, η=%.3f, 接受率=%.3f\n', ...
                    chain, iter, n_iter, current_params.eta, accept_rate);
            end
        end
        
        % 存储链结果
        all_chains_samples{chain} = samples;
        all_chains_accept(chain) = accept_count / n_iter;
        
        fprintf('链%d完成: 最终接受率=%.3f, η=%.3f, β_I=%.3f\n', ...
            chain, all_chains_accept(chain), current_params.eta, current_params.beta_I);
    end
    
    % 合并所有链的样本
    fprintf('合并%d条链的样本...\n', n_chains);
    
    all_samples = [];
    for chain = 1:n_chains
        burned_samples = all_chains_samples{chain}(n_burn+1:n_thin:end, :);
        all_samples = [all_samples; burned_samples];
    end
    
    fprintf('合并后总样本数: %d\n', size(all_samples, 1));
    
    % 计算后验统计
    param_names = {'eta', 'alpha_I', 'beta_I', 'alpha_II', 'beta_II', 'sigma'};
    post_stats = struct();
    
    for i = 1:6
        samples = all_samples(:, i);
        
        post_stats.([param_names{i} '_mean']) = mean(samples);
        post_stats.([param_names{i} '_std']) = std(samples);
        post_stats.([param_names{i} '_ci90']) = prctile(samples, [5, 95]);
    end
    
    % 创建params_mean
    params_mean = struct(...
        'eta', post_stats.eta_mean, ...
        'alpha_I', post_stats.alpha_I_mean, ...
        'beta_I', post_stats.beta_I_mean, ...
        'alpha_II', post_stats.alpha_II_mean, ...
        'beta_II', post_stats.beta_II_mean, ...
        'sigma', post_stats.sigma_mean);
    
    % 模型验证
    h_pred_train = forward_model(params_mean, L_train);
    R2_train = 1 - sum((h_pred_train - h_train).^2) / sum((h_train - mean(h_train)).^2);
    
    h_pred_val = forward_model(params_mean, L_val);
    R2_val = 1 - sum((h_pred_val - h_val).^2) / sum((h_val - mean(h_val)).^2);
    
    % 计算Gelman-Rubin R-hat统计量
    r_hat_values = zeros(1, 6);
    for p = 1:6
        chain_means = zeros(n_chains, 1);
        chain_vars = zeros(n_chains, 1);
        chain_sizes = zeros(n_chains, 1);
        
        for chain = 1:n_chains
            chain_samples = all_chains_samples{chain}(n_burn+1:end, p);
            chain_means(chain) = mean(chain_samples);
            chain_vars(chain) = var(chain_samples);
            chain_sizes(chain) = length(chain_samples);
        end
        
        n = min(chain_sizes);
        m = n_chains;
        
        overall_mean = mean(chain_means);
        B = n/(m-1) * sum((chain_means - overall_mean).^2);
        W = mean(chain_vars);
        
        if W > 0
            var_plus = (n-1)/n * W + B/n;
            r_hat_values(p) = sqrt(var_plus / W);
        else
            r_hat_values(p) = Inf;
        end
    end
    
    % 存储当前实验结果
    experiment_results{exp_idx} = struct();
    experiment_results{exp_idx}.n_iter = n_iter;
    experiment_results{exp_idx}.n_burn = n_burn;
    experiment_results{exp_idx}.params_mean = params_mean;
    experiment_results{exp_idx}.post_stats = post_stats;
    experiment_results{exp_idx}.R2_train = R2_train;
    experiment_results{exp_idx}.R2_val = R2_val;
    experiment_results{exp_idx}.r_hat = r_hat_values;
    experiment_results{exp_idx}.accept_rate = mean(all_chains_accept);
    experiment_results{exp_idx}.n_samples = size(all_samples, 1);
    
    fprintf('实验完成: R2_val=%.3f, η=%.3f, β_I=%.3f\n', ...
        R2_val, params_mean.eta, params_mean.beta_I);
end

%% =============== 4. n_iter ablation results visualization ===============
fprintf('\n=== 4. n_iter ablation results visualization ===\n');

% Extract all experiment results
n_iter_array = zeros(n_experiments, 1);
R2_val_array = zeros(n_experiments, 1);
R2_train_array = zeros(n_experiments, 1);
accept_rate_array = zeros(n_experiments, 1);
r_hat_mean_array = zeros(n_experiments, 1);
eta_array = zeros(n_experiments, 1);
beta_I_array = zeros(n_experiments, 1);
beta_II_array = zeros(n_experiments, 1);
n_samples_array = zeros(n_experiments, 1);

for i = 1:n_experiments
    n_iter_array(i) = experiment_results{i}.n_iter;
    R2_val_array(i) = experiment_results{i}.R2_val;
    R2_train_array(i) = experiment_results{i}.R2_train;
    accept_rate_array(i) = experiment_results{i}.accept_rate;
    r_hat_mean_array(i) = mean(experiment_results{i}.r_hat);
    eta_array(i) = experiment_results{i}.params_mean.eta;
    beta_I_array(i) = experiment_results{i}.params_mean.beta_I;
    beta_II_array(i) = experiment_results{i}.params_mean.beta_II;
    n_samples_array(i) = experiment_results{i}.n_samples;
end

% Figure 1: R2 vs n_iter
figure('Position', [100, 100, 1200, 500], 'Color', 'white');

subplot(1, 2, 1);
plot(n_iter_array, R2_train_array, 'b-o', 'LineWidth', 3, ...
    'MarkerSize', 10, 'MarkerFaceColor', 'b', 'DisplayName', 'train R2');
hold on;
plot(n_iter_array, R2_val_array, 'r-s', 'LineWidth', 3, ...
    'MarkerSize', 10, 'MarkerFaceColor', 'r', 'DisplayName', 'validation R2');

xlabel('n_iter', 'FontSize', 26, 'FontName', 'Times New Roman');
ylabel('R2', 'FontSize', 26, 'FontName', 'Times New Roman');
title('R2 vs n_iter', 'FontSize', 30, 'FontName', 'Times New Roman', 'FontWeight', 'bold');
legend('show', 'Location', 'best', 'FontSize', 22, 'FontName', 'Times New Roman');
grid off;
set(gca, 'FontSize', 24, 'FontName', 'Times New Roman', 'LineWidth', 2);
ylim([0, 1]);

subplot(1, 2, 2);
plot(n_iter_array, accept_rate_array * 100, 'g-^', 'LineWidth', 3, ...
    'MarkerSize', 10, 'MarkerFaceColor', 'g', 'DisplayName', 'accept rate');
xlabel('n_iter', 'FontSize', 26, 'FontName', 'Times New Roman');
ylabel('accept rate (%)', 'FontSize', 26, 'FontName', 'Times New Roman');
title('Accept rate vs n_iter', 'FontSize', 30, 'FontName', 'Times New Roman', 'FontWeight', 'bold');
grid off;
set(gca, 'FontSize', 24, 'FontName', 'Times New Roman', 'LineWidth', 2);
ylim([55, 85]);

% Figure 2: Key parameters vs n_iter
figure('Position', [100, 100, 1400, 500], 'Color', 'white');

subplot(1, 3, 1);
errorbar(n_iter_array, eta_array, ...
    arrayfun(@(i) experiment_results{i}.post_stats.eta_ci90(2)-experiment_results{i}.post_stats.eta_mean, 1:n_experiments), ...
    'b-o', 'LineWidth', 2, 'MarkerSize', 8, 'MarkerFaceColor', 'b', 'CapSize', 10);
xlabel('n_iter', 'FontSize', 24, 'FontName', 'Times New Roman');
ylabel('mixing ratio η', 'FontSize', 24, 'FontName', 'Times New Roman');
title('Mixing ratio η', 'FontSize', 28, 'FontName', 'Times New Roman', 'FontWeight', 'bold');
grid off;
set(gca, 'FontSize', 22, 'FontName', 'Times New Roman', 'LineWidth', 2);
ylim([0, 1]);

subplot(1, 3, 2);
errorbar(n_iter_array, beta_I_array, ...
    arrayfun(@(i) experiment_results{i}.post_stats.beta_I_ci90(2)-experiment_results{i}.post_stats.beta_I_mean, 1:n_experiments), ...
    'r-s', 'LineWidth', 2, 'MarkerSize', 8, 'MarkerFaceColor', 'r', 'CapSize', 10);
hold on;
plot([min(n_iter_array), max(n_iter_array)], [0.5, 0.5], 'k--', 'LineWidth', 1.5);
plot([min(n_iter_array), max(n_iter_array)], [1.0, 1.0], 'k--', 'LineWidth', 1.5);
xlabel('n_iter', 'FontSize', 24, 'FontName', 'Times New Roman');
ylabel('type I exponent β_I', 'FontSize', 24, 'FontName', 'Times New Roman');
title('Type I exponent β_I', 'FontSize', 28, 'FontName', 'Times New Roman', 'FontWeight', 'bold');
grid off;
set(gca, 'FontSize', 22, 'FontName', 'Times New Roman', 'LineWidth', 2);
ylim([0.4, 1.1]);

subplot(1, 3, 3);
errorbar(n_iter_array, beta_II_array, ...
    arrayfun(@(i) experiment_results{i}.post_stats.beta_II_ci90(2)-experiment_results{i}.post_stats.beta_II_mean, 1:n_experiments), ...
    'g-^', 'LineWidth', 2, 'MarkerSize', 8, 'MarkerFaceColor', 'g', 'CapSize', 10);
hold on;
plot([min(n_iter_array), max(n_iter_array)], [0.3, 0.3], 'k--', 'LineWidth', 1.5);
plot([min(n_iter_array), max(n_iter_array)], [0.7, 0.7], 'k--', 'LineWidth', 1.5);
xlabel('n_iter', 'FontSize', 24, 'FontName', 'Times New Roman');
ylabel('type II exponent β_II', 'FontSize', 24, 'FontName', 'Times New Roman');
title('Type II exponent β_II', 'FontSize', 28, 'FontName', 'Times New Roman', 'FontWeight', 'bold');
grid off;
set(gca, 'FontSize', 22, 'FontName', 'Times New Roman', 'LineWidth', 2);
ylim([0.2, 0.8]);

% Figure 3: Convergence diagnosis vs n_iter
figure('Position', [100, 100, 1200, 500], 'Color', 'white');

subplot(1, 2, 1);
plot(n_iter_array, r_hat_mean_array, 'm-d', 'LineWidth', 3, ...
    'MarkerSize', 10, 'MarkerFaceColor', 'm');
hold on;
plot([min(n_iter_array), max(n_iter_array)], [1.1, 1.1], 'r--', 'LineWidth', 2);
xlabel('n_iter', 'FontSize', 26, 'FontName', 'Times New Roman');
ylabel('average R-hat', 'FontSize', 26, 'FontName', 'Times New Roman');
title('Gelman-Rubin R-hat', 'FontSize', 30, 'FontName', 'Times New Roman', 'FontWeight', 'bold');
grid off;
set(gca, 'FontSize', 24, 'FontName', 'Times New Roman', 'LineWidth', 2);
ylim([1, max(1.2, max(r_hat_mean_array)*1.1)]);

subplot(1, 2, 2);
plot(n_iter_array, n_samples_array, 'c-p', 'LineWidth', 3, ...
    'MarkerSize', 10, 'MarkerFaceColor', 'c');
xlabel('n_iter', 'FontSize', 26, 'FontName', 'Times New Roman');
ylabel('effective sample size', 'FontSize', 26, 'FontName', 'Times New Roman');
title('Effective sample size', 'FontSize', 30, 'FontName', 'Times New Roman', 'FontWeight', 'bold');
grid off;
set(gca, 'FontSize', 24, 'FontName', 'Times New Roman', 'LineWidth', 2);

% Figure 4: Comprehensive performance
figure('Position', [100, 100, 1000, 700], 'Color', 'white');

% Calculate performance score
performance_score = R2_val_array * 0.4 + (1 - min(r_hat_mean_array-1, 0.5)) * 0.3 + ...
                   accept_rate_array * 0.2 + (n_samples_array / max(n_samples_array)) * 0.1;

plot(n_iter_array, performance_score, 'k-*', 'LineWidth', 3, ...
    'MarkerSize', 12, 'MarkerFaceColor', 'k');

% Mark best value
[best_score, best_idx] = max(performance_score);
hold on;
plot(n_iter_array(best_idx), best_score, 'ro', 'MarkerSize', 15, ...
    'LineWidth', 3, 'MarkerFaceColor', 'r');

xlabel('n_iter', 'FontSize', 28, 'FontName', 'Times New Roman');
ylabel('performance score', 'FontSize', 28, 'FontName', 'Times New Roman');
title(sprintf('Performance score vs n_iter (best: n_iter=%d)', n_iter_array(best_idx)), ...
    'FontSize', 32, 'FontName', 'Times New Roman', 'FontWeight', 'bold');

text(n_iter_array(best_idx), best_score + 0.02, 'best', ...
    'FontSize', 26, 'FontName', 'Times New Roman', ...
    'HorizontalAlignment', 'center', 'FontWeight', 'bold');

grid off;
set(gca, 'FontSize', 25, 'FontName', 'Times New Roman', 'LineWidth', 2);
ylim([min(performance_score)-0.1, max(performance_score)+0.1]);

% Figure 5: Parameter uncertainty vs n_iter
figure('Position', [100, 100, 1200, 500], 'Color', 'white');

% Calculate uncertainty (CI width)
eta_uncertainty = zeros(n_experiments, 1);
beta_I_uncertainty = zeros(n_experiments, 1);
beta_II_uncertainty = zeros(n_experiments, 1);

for i = 1:n_experiments
    eta_uncertainty(i) = experiment_results{i}.post_stats.eta_ci90(2) - experiment_results{i}.post_stats.eta_ci90(1);
    beta_I_uncertainty(i) = experiment_results{i}.post_stats.beta_I_ci90(2) - experiment_results{i}.post_stats.beta_I_ci90(1);
    beta_II_uncertainty(i) = experiment_results{i}.post_stats.beta_II_ci90(2) - experiment_results{i}.post_stats.beta_II_ci90(1);
end

subplot(1, 3, 1);
plot(n_iter_array, eta_uncertainty, 'b-o', 'LineWidth', 2, 'MarkerSize', 8, 'MarkerFaceColor', 'b');
xlabel('n_iter', 'FontSize', 22, 'FontName', 'Times New Roman');
ylabel('CI width (η)', 'FontSize', 22, 'FontName', 'Times New Roman');
title('η uncertainty', 'FontSize', 26, 'FontName', 'Times New Roman', 'FontWeight', 'bold');
grid off;
set(gca, 'FontSize', 20, 'FontName', 'Times New Roman', 'LineWidth', 2);

subplot(1, 3, 2);
plot(n_iter_array, beta_I_uncertainty, 'r-s', 'LineWidth', 2, 'MarkerSize', 8, 'MarkerFaceColor', 'r');
xlabel('n_iter', 'FontSize', 22, 'FontName', 'Times New Roman');
ylabel('CI width (β_I)', 'FontSize', 22, 'FontName', 'Times New Roman');
title('β_I uncertainty', 'FontSize', 26, 'FontName', 'Times New Roman', 'FontWeight', 'bold');
grid off;
set(gca, 'FontSize', 20, 'FontName', 'Times New Roman', 'LineWidth', 2);

subplot(1, 3, 3);
plot(n_iter_array, beta_II_uncertainty, 'g-^', 'LineWidth', 2, 'MarkerSize', 8, 'MarkerFaceColor', 'g');
xlabel('n_iter', 'FontSize', 22, 'FontName', 'Times New Roman');
ylabel('CI width (β_II)', 'FontSize', 22, 'FontName', 'Times New Roman');
title('β_II uncertainty', 'FontSize', 26, 'FontName', 'Times New Roman', 'FontWeight', 'bold');
grid off;
set(gca, 'FontSize', 20, 'FontName', 'Times New Roman', 'LineWidth', 2);

%% =============== 5. 结果汇总与保存 ===============
fprintf('\n=== 5. n_iter消融实验结果汇总 ===\n');

% 创建汇总表格
fprintf('\n%-10s %-8s %-8s %-8s %-8s %-8s %-8s %-8s\n', ...
    'n_iter', 'R2_val', 'R2_train', 'η', 'β_I', 'β_II', 'R-hat', '接受率');
fprintf('%s\n', repmat('-', 80, 1));

for i = 1:n_experiments
    fprintf('%-10d %-8.3f %-8.3f %-8.3f %-8.3f %-8.3f %-8.3f %-8.3f\n', ...
        experiment_results{i}.n_iter, ...
        experiment_results{i}.R2_val, ...
        experiment_results{i}.R2_train, ...
        experiment_results{i}.params_mean.eta, ...
        experiment_results{i}.params_mean.beta_I, ...
        experiment_results{i}.params_mean.beta_II, ...
        mean(experiment_results{i}.r_hat), ...
        experiment_results{i}.accept_rate);
end

% 找出最优实验
[~, best_idx] = max(performance_score);
fprintf('\n=== 最优参数设置 ===\n');
fprintf('n_iter = %d\n', experiment_results{best_idx}.n_iter);
fprintf('R?验证集 = %.3f\n', experiment_results{best_idx}.R2_val);
fprintf('η = %.3f, β_I = %.3f, β_II = %.3f\n', ...
    experiment_results{best_idx}.params_mean.eta, ...
    experiment_results{best_idx}.params_mean.beta_I, ...
    experiment_results{best_idx}.params_mean.beta_II);
fprintf('平均R-hat = %.3f, 平均接受率 = %.3f\n', ...
    mean(experiment_results{best_idx}.r_hat), ...
    experiment_results{best_idx}.accept_rate);

% 保存所有实验结果
save('niter_ablation_results.mat', 'experiment_results', 'n_iter_array', ...
    'R2_val_array', 'R2_train_array', 'accept_rate_array', 'r_hat_mean_array', ...
    'eta_array', 'beta_I_array', 'beta_II_array', 'performance_score');

fprintf('\n结果已保存到: niter_ablation_results.mat\n');
fprintf('=== n_iter消融实验完成 ===\n');