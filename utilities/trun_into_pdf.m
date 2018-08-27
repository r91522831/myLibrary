clear; close all; clc
ROOT_DIR_folder = uigetdir;

switch input('Do you want to select orientation for each figure?(y/N)', 's');
    case {'y', 'Y'}
        choose_orientation = true;
    otherwise
        switch input('Select orientation for all figures [1:portrait, 2:landscape]:');
            case 1
                orientation = 'portrait';
            case 2
                orientation = 'landscape';
        end
        choose_orientation = false;
end


figure_size = [0, 0, 1, 1];

tmp_list = dir( fullfile(ROOT_DIR_folder, '*.fig') );
for i = 1:length(tmp_list)
    
    h = openfig(fullfile(ROOT_DIR_folder, tmp_list(i).name));
    set(h, 'units', 'normalized', 'outerposition', figure_size)
    
    filename = fullfile(ROOT_DIR_folder, tmp_list(i).name(1:(end-4)));
        
    if choose_orientation
        switch input('Select orientation for this figure [1:portrait, 2:landscape]:');
            case 1
                orientation = 'portrait';
            case 2
                orientation = 'landscape';
        end
    end
    
    set(h, 'PaperType', 'usletter', ...
           'PaperOrientation', orientation, ...
           'PaperPositionMode', 'manual', ...
           'PaperUnits', 'normalized', ...
           'Paperposition', figure_size )
       
    pause(0.4) 
  
    print(h, '-dpdf', filename)
    close all
end