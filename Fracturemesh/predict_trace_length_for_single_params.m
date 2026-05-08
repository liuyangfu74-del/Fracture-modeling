function L_pred = predict_trace_length_for_single_params(h_values, params)
    % 使用单组参数预测迹长
    n_h = length(h_values);
    L_pred = zeros(n_h, 1);
    
    for i = 1:n_h
        L_pred(i) = inverse_model_robust(h_values(i), params);
    end
end