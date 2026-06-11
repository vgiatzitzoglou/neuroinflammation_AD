function subjects = list_subject_dirs(group_dir)
%LIST_SUBJECT_DIRS Return subject directories, excluding hidden and output dirs.

if ~exist(group_dir, 'dir')
    subjects = struct('name', {}, 'folder', {}, 'date', {}, 'bytes', {}, 'isdir', {}, 'datenum', {});
    return;
end

subjects = dir(group_dir);
subjects = subjects([subjects.isdir]);
names = {subjects.name};
skip = startsWith(names, '.') | contains(names, 'Contrast') | ...
    ismember(names, {'Normalized_PET', 'SSA_Render_Images', 'weird'});
subjects = subjects(~skip);
end
