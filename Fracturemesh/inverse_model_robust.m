function [L_pred, exit_flag] = inverse_model_robust(h, params, L_range)
    % 稳健的裂隙迹长反演函数
    % 输入:
    %   h: 开度观测值 (m)
    %   params: 模型参数结构体
    %   L_range: 迹长搜索范围 [min, max] (可选)
    % 输出:
    %   L_pred: 预测的迹长 (m)
    %   exit_flag: 退出标志 (1=成功, 0=警告, -1=失败)
    
    % 检查输入参数
    if nargin < 2
        error('需要至少2个输入参数');
    end
    
    % 默认范围
    if nargin < 3 || isempty(L_range)
        % 智能范围估计
        if abs(params.eta*params.alpha_I + (1-params.eta)*params.alpha_II) < 1e-10
            L_range = [0.1, 50]; % 保守范围
        else
            % 基于加权平均的初值估计
            beta_avg = params.eta * params.beta_I + (1-params.eta) * params.beta_II;
            alpha_avg = params.eta * params.alpha_I + (1-params.eta) * params.alpha_II;
            
            if abs(beta_avg) < 1e-10 || abs(alpha_avg) < 1e-10
                L_guess = 5;
            else
                L_guess = (h / alpha_avg)^(1/beta_avg);
            end
            
            L_guess = max(0.1, min(100, L_guess));
            L_range = [max(0.05, L_guess/20), min(200, L_guess*20)];
        end
    end
    
    % 定义正向模型
    forward_func = @(L) params.eta * params.alpha_I * (L .^ params.beta_I) + ...
                       (1 - params.eta) * params.alpha_II * (L .^ params.beta_II);
    
    % 定义目标函数（平方误差更平滑）
    f = @(L) (h - forward_func(L)).^2;
    
    % 优化选项
    options = optimset('Display', 'off', ...
                      'TolX', 1e-6, ...
                      'TolFun', 1e-8, ...
                      'MaxFunEvals', 1000, ...
                      'MaxIter', 500);
    
    % 尝试多个起点
    L_starts = [L_range(1), ...
                mean(L_range), ...
                L_range(2), ...
                L_range(1) + 0.25*diff(L_range), ...
                L_range(1) + 0.75*diff(L_range)];
    
    best_L = L_starts(1);
    best_fval = inf;
    
    for i = 1:length(L_starts)
        try
            [L_i, fval_i, exitflag_i] = fminbnd(f, L_range(1), L_range(2), options);
            
            if exitflag_i > 0 && fval_i < best_fval
                best_L = L_i;
                best_fval = fval_i;
            end
        catch
            % 忽略优化错误，继续尝试其他起点
            continue;
        end
    end
    
    % 设置退出标志
    if best_fval < 1e-6
        exit_flag = 1;  % 成功
    elseif best_fval < 1e-3
        exit_flag = 0;  % 警告
    else
        exit_flag = -1; % 失败
    end
    
    % 边界约束
    L_pred = max(L_range(1), min(L_range(2), best_L));
    
    % 验证结果
    h_pred = forward_func(L_pred);
    rel_error = abs(h_pred - h) / max(h, 1e-6);
    
    if rel_error > 0.1 && exit_flag ~= -1
        % 误差过大但优化成功，降级为警告
        exit_flag = 0;
    end
end