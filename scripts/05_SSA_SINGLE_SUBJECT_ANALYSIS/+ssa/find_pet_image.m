function pet_file = find_pet_image(subject_dir, pet_patterns)
% first likely PET image in a subject folder

pet_file = '';
for k = 1:numel(pet_patterns)
    matches = dir(fullfile(subject_dir, pet_patterns{k}));
    matches = matches(~[matches.isdir]);
    if ~isempty(matches)
        pet_file = fullfile(subject_dir, matches(1).name);
        return;
    end
end

fallback = dir(fullfile(subject_dir, '*.nii*'));
fallback = fallback(~[fallback.isdir]);
for k = 1:numel(fallback)
    name = fallback(k).name;
    is_excluded = contains(name, 'GMmask') || ...
        contains(name, 'Clusters') || ...
        contains(name, 'Skull') || ...
        contains(name, 'ObjectMap') || ...
        contains(name, 'GMObjectmap') || ...
        contains(name, '_GM_ObjectMap');
    if ~is_excluded
        pet_file = fullfile(subject_dir, name);
        return;
    end
end
end
