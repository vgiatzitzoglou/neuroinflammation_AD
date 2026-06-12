function found = has_ssa_outputs(varargin)
% true if any expected SSA output exists in the given dirs

found = false;
for i = 1:nargin
    check_dir = varargin{i};
    if isempty(check_dir) || ~exist(check_dir, 'dir')
        continue;
    end
    listing = dir(check_dir);
    for k = 1:numel(listing)
        if listing(k).isdir
            continue;
        end
        name = lower(listing(k).name);
        is_cluster = startsWith(name, 'clusters') && ...
            (endsWith(name, '.nii') || endsWith(name, '.obj'));
        is_result = startsWith(name, 'results') && ...
            (endsWith(name, '.tsv') || endsWith(name, '.txt') || endsWith(name, '.csv'));
        if is_cluster || is_result
            found = true;
            return;
        end
    end
end
end
