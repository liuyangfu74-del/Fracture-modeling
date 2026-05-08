function L_predicted = predict_length_from_aperture(h_observed, D, Lmin, Lmax, a_log, b_log, ha, hb, tolerance)
    % 定义公式(14)：由长度L计算开度h
    function h_calc = model_h_from_L(L)
        g_ha = erf( (log(ha) - a_log) / (sqrt(2)*b_log) );
        g_hb = erf( (log(hb) - a_log) / (sqrt(2)*b_log) );
        Fl = ( L.^(-D) - Lmin^(-D) ) ./ ( Lmax^(-D) - Lmin^(-D) );
        Fl = min(max(Fl, 0), 1); % 钳制概率在[0,1]之间
        arg = Fl * (g_hb - g_ha) + g_ha;
        arg = min(max(arg, -1+1e-12), 1-1e-12); % 防止erfinv输入为±1
        ln_h = sqrt(2)*b_log .* erfinv(arg) + a_log;
        h_calc = exp(ln_h);
    end

    % 二分法求解 L: model_h_from_L(L) = h_observed
    low_bound = Lmin;
    high_bound = Lmax;

    while (high_bound - low_bound) > tolerance
        mid = (low_bound + high_bound) / 2;
        h_mid = model_h_from_L(mid);

        if h_mid > h_observed
            % 计算的开度太大，说明长度猜大了，应减小
            high_bound = mid;
        else
            % 计算的开度太小，说明长度猜小了，应增大
            low_bound = mid;
        end
    end

    L_predicted = (low_bound + high_bound) / 2;
end