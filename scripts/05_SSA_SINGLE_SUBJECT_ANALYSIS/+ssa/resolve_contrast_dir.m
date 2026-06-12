function contrast_dir = resolve_contrast_dir(group_dir, subject_id)
% find a subject contrast folder across naming variants

contrast_dir = fullfile(group_dir, [subject_id 'Contrast']);
if exist(contrast_dir, 'dir')
    return;
end

candidates = dir(fullfile(group_dir, [subject_id '*Contrast*']));
candidates = candidates([candidates.isdir]);
if ~isempty(candidates)
    contrast_dir = fullfile(group_dir, candidates(1).name);
    return;
end

subject_dir = fullfile(group_dir, subject_id);
inner = fullfile(subject_dir, [subject_id 'Contrast']);
if exist(inner, 'dir')
    contrast_dir = inner;
    return;
end

contrast_dir = '';
end
