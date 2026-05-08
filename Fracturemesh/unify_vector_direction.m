function V_out = unify_vector_direction(V, normal_vec)
    % 统一向量朝向
    % 输入:
    %   V - N×3 向量矩阵
    %   normal_vec - 法向量 [0,0,1]
    % 输出:
    %   V_out - 统一朝向后的向量矩阵
    
    V_out = V;
    
    for i = 1:size(V, 1)
        if dot(V(i, :), normal_vec) < 0
            V_out(i, :) = -V(i, :);
        end
    end
end