function InternalfrcatureVisualization(fractureLine,V,F,selSign)
%% 可视化
figure('Position', [100, 100, 1200, 500]); % 设置图形窗口大小
% 子图1：三角网格曲面
subplot(1, 2, 1);
trisurf(F, V(:,1), V(:,2), V(:,3), 'FaceColor', 'cyan', 'FaceAlpha', 0.7, 'EdgeColor', 'k');
hold on;
plot3(fractureLine(:,1), fractureLine(:,2), fractureLine(:,3), 'r-', 'LineWidth', 3);
plot3(fractureLine(:,1), fractureLine(:,2), fractureLine(:,3), 'ro', 'MarkerSize', 8, 'MarkerFaceColor', 'r');
axis equal;
xlabel('X', 'FontName', 'Times New Roman', 'FontSize', 4);
ylabel('Y', 'FontName', 'Times New Roman', 'FontSize', 4);
zlabel('Z', 'FontName', 'Times New Roman', 'FontSize', 4);
title(['Generated Triangular Mesh (selSign = ', num2str(selSign), ')'], 'FontName', 'Times New Roman', 'FontSize', 20);
grid on;

% 子图2：散点图
subplot(1, 2, 2);
scatter3(V(:,1), V(:,2), V(:,3), 40, 'b', 'filled');
hold on;
plot3(fractureLine(:,1), fractureLine(:,2), fractureLine(:,3), 'r-', 'LineWidth', 2);
plot3(fractureLine(:,1), fractureLine(:,2), fractureLine(:,3), 'ro', 'MarkerSize', 8, 'MarkerFaceColor', 'r');
axis equal;
xlabel('X', 'FontName', 'Times New Roman', 'FontSize', 4);
ylabel('Y', 'FontName', 'Times New Roman', 'FontSize', 4);
zlabel('Z', 'FontName', 'Times New Roman', 'FontSize', 4);
title('Mesh Vertex Scatter Plot', 'FontName', 'Times New Roman', 'FontSize', 20);
grid on;