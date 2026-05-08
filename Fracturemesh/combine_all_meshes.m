%% 辅助函数
function [combined_V, combined_F] = combine_all_meshes(all_3d_models)
    % 合并所有网格
    combined_V = [];
    combined_F = [];
    vertex_offset = 0;
    
    for cluster_id = 1:length(all_3d_models)
        cluster_models = all_3d_models{cluster_id};
        if isempty(cluster_models)
            continue;
        end
        
        for f_idx = 1:length(cluster_models)
            model = cluster_models{f_idx};
            if isempty(model)
                continue;
            end
            
            combined_V = [combined_V; model.vertices];
            combined_F = [combined_F; model.faces + vertex_offset];
            vertex_offset = vertex_offset + size(model.vertices, 1);
        end
    end
end
