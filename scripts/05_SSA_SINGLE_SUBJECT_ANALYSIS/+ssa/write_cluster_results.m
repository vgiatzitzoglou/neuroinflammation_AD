function write_cluster_results(cluster_file, pet_img, out_file)
%WRITE_CLUSTER_RESULTS Sample PET values for each labelled cluster.

cluster_vol = spm_vol(cluster_file);
clusters = spm_read_vols(cluster_vol);
pet_vol = spm_vol(pet_img);
pet_data = spm_read_vols(pet_vol);

labels = unique(clusters(:));
labels(labels == 0 | isnan(labels)) = [];

rows = {};
for i = 1:numel(labels)
    label = labels(i);
    values = pet_data(clusters == label);
    values = values(~isnan(values));
    if isempty(values)
        continue;
    end
    voxels = numel(values);
    mean_value = mean(values);
    rows(end + 1, :) = {label, voxels, mean_value, mean_value * voxels}; %#ok<AGROW>
end

table_out = cell2table(rows, ...
    'VariableNames', {'Label', 'Voxels', 'Mean', 'Mean_times_Voxels'});
writetable(table_out, out_file, 'FileType', 'text', 'Delimiter', '\t');
end
