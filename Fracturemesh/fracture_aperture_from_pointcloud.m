function [L, h_rep, s, h_profile] = fracture_aperture_from_pointcloud(pts, D, Lmin, Lmax, a_log, b_log, ha, hb, n_points, p)
% 从裂隙点云生成迹长、代表性开度和沿迹长的开度分布
%
% 输入:
%   pts      - n x 3 裂隙点云坐标 (无序)
%   D        - 迹长分形维数 (论文参数)
%   Lmin,Lmax- 迹长分布截断范围
%   a_log    - ln(h) 的均值 (对数正态参数)
%   b_log    - ln(h) 的标准差
%   ha,hb    - 开度截断下限与上限
%   n_points - 裂隙上开度分布采样点数
%   p        - 开度分布衰减指数 (p=2 抛物线, p=4 更陡峭)
%
% 输出:
%   L         - 裂隙迹长
%   h_rep     - 代表性开度 (来自论文公式)
%   s         - 沿裂隙位置 (0~L)
%   h_profile - 开度分布 (与 s 对应)

    % ===== 1. 计算迹长 =====
    mu = mean(pts,1);
    C = bsxfun(@minus, pts, mu);
    [~,~,V] = svd(C,'econ');   % PCA 主方向
    dir = V(:,1);
    t = (pts - mu) * dir;      % 投影坐标
    [t_sorted, I] = sort(t);
    projPts = pts(I,:);
    L = sum( sqrt(sum(diff(projPts,1,1).^2,2)) );

    % ===== 2. 论文公式 (14): L -> h_rep =====
    g_ha = erf( (log(ha) - a_log) / (sqrt(2)*b_log) );
    g_hb = erf( (log(hb) - a_log) / (sqrt(2)*b_log) );
    Fl = ( L.^(-D) - Lmin^(-D) ) ./ ( Lmax^(-D) - Lmin^(-D) );
    Fl = min(max(Fl,0),1);
    arg = Fl * (g_hb - g_ha) + g_ha;
    arg = min(max(arg, -0.999999), 0.999999);
    ln_h = sqrt(2)*b_log .* erfinv(arg) + a_log;
    h_rep = exp(ln_h);

    % ===== 3. 沿裂隙生成开度分布 =====
    s = linspace(0,L,n_points);
    h_profile = h_rep * (1 - abs(2*s/L - 1).^p);

    % ===== 4. 可视化 =====
    figure;
    subplot(2,1,1);
    plot3(projPts(:,1),projPts(:,2),projPts(:,3),'-ok'); axis equal;
    title(sprintf('裂隙点云投影与迹长 L = %.3f',L));
    subplot(2,1,2);
    plot(s,h_profile,'-b','LineWidth',2);
    xlabel('沿迹长位置 s'); ylabel('开度 h(s)');
    title(sprintf('裂隙开度分布: h_{rep}=%.4g, p=%d',h_rep,p));
    grid on;
end
