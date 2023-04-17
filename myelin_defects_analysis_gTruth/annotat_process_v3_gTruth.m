clear; clc; close all;

% load annotated_data and create directories
folder = pwd;

if ~exist([folder 'vesicle'],'dir')
    mkdir vesicle;
end

if ~exist([folder 'myelin'],'dir')
    mkdir myelin;
end

if ~exist([folder 'axonal'],'dir')
    mkdir axonal;
end

if ~exist([folder 'total_abnormalities'],'dir')
    mkdir total_abnormalities;
end

data = load_data();

% show for each file coordinates of the ROIs
supp_folder = [folder, '\supplementary_info'];
img_folder = [supp_folder, '\PSOCT_size_0.1X'];

% load the image file
cd(img_folder);
img_files = dir('*PSOCT_0.1X.tif');

% analyze number of abnormalities per sample
summary = {};
for img_n = 1: length(img_files)
    img_name = img_files(img_n).name;
    % find statistic for each image
    img_fn = extractBefore(img_name,"_PSOCT");
    tot_N_vesicle = zeros(1, length(data));
    tot_N_myelin_def = zeros(1, length(data));
    tot_N_balloons = zeros(1, length(data));
    tot_N_abn = zeros(1, length(data));

    for i = 1:length(data)
        img_cur = extractBefore(data(i).original_image," - Z 20x");
        if strcmp(img_fn, img_cur)
            tot_N_vesicle(i) = data(i).N_vesicles;
            tot_N_myelin_def(i) = data(i).N_myelin_def;
            tot_N_balloons(i) = data(i).N_balloons;
            tot_N_abn(i) = data(i).N_abnorm;
        end
    end
    % write values in summary file
    summary(img_n).img_name = img_fn;
    summary(img_n).N_vesicle = sum(tot_N_vesicle);
    summary(img_n).N_myelin_def = sum(tot_N_myelin_def);
    summary(img_n).N_balloons = sum(tot_N_balloons);
    summary(img_n).N_abn = sum(tot_N_abn);
end

% initialise four types of plots
vars = {extractfield(data, 'N_vesicles'), extractfield(data, 'N_myelin_def'), ...
    extractfield(data, 'N_balloons'), extractfield(data, 'N_abnorm')};
names = {'_N_vesicles', '_N_myelin_def', '_N_balloons', '_N_abnorm'};
dirs = {'.\vesicle', '.\myelin', '.\axonal', '.\total_abnormalities'};

for i = 1:length(vars)
    plot(img_files, data, vars{i}, names{i}, dirs{i});
end


% finds index of the files in struct list
function ind = find_idx(list, member)
    fn = strtok(member, '.');
    fn = [fn, '.tif'];
    X = contains(cellstr(list),fn);
    ind = find(X);
end

function data = load_data()
    % load annotated files 
    folder = pwd;
    data_folder = [folder, '\annotated'];
    supp_folder = [folder, '\supplementary_info'];
    coord_folder = [supp_folder, '\Coordinates'];
    cd(data_folder);
    Files=dir('*.mat');
    load([supp_folder, '\ID_list.mat']);
    
    % load all coordinates data
    cd(coord_folder);
    coord_files = dir('*.txt');
    for i = 1:length(coord_files)
        filename = coord_files(i).name;
        temp = tdfread(filename);
        if i == 1
            coord_data = temp;
        else
            coord_data = horzcat(coord_data,temp);
        end
    end
    
    % create a struct to save all data
    data = {};
    cd(data_folder);
    
    % load data from the files
    for i = 1:length(Files)
        filename = Files(i).name;
        load(filename);
        % get ID of the current image
        num1 = strtok(filename, '_');
        % find which file name corresponds to current index
        ind = find(ismember({ID_list.id}, num1));
        origin_fn = strtok(ID_list(ind).name, '.');
        % find which file has the coord
        for j = 1:length(coord_data)
            temp = coord_data(j).Original_image;
            o_name = temp(j,:);
            if strcmp(o_name, origin_fn)
                coord_file_idx = j;
            end
        end
        % find coordinates of the img
        coord_ind = find_idx(coord_data(coord_file_idx).ROI_image, filename);
        % fill up data struct
        data(i).x_start = coord_data(coord_file_idx).x_start(coord_ind);
        data(i).x_end = coord_data(coord_file_idx).x_end(coord_ind);
        data(i).y_start = coord_data(coord_file_idx).y_start(coord_ind);
        data(i).y_end = coord_data(coord_file_idx).y_end(coord_ind);
        data(i).ROI_image = coord_data(coord_file_idx).ROI_image(coord_ind,:);
        data(i).original_image = coord_data(coord_file_idx).Original_image(coord_ind,:);
        % find info about vesicles
        if isempty(gTruth.vesicle)
            data(i).vesicle_coord = NaN;
            data(i).N_vesicles = 0;  
        else
            data(i).vesicle_coord = gTruth.vesicle;
            data(i).N_vesicles = numel(data(i).vesicle_coord);
        end
        % find info about myelin abnormalities
        if isempty(gTruth.myelin)
            data(i).myelin_def_coord = NaN;
            data(i).N_myelin_def = 0;
        else
            data(i).myelin_def_coord = gTruth.myelin;
            data(i).N_myelin_def = numel(data(i).myelin_def_coord);
        end
        % find info about balloons
        if isempty(gTruth.axonal)
            data(i).balloon_coord = NaN;
            data(i).N_balloons = 0;
        else
            data(i).balloon_coord = gTruth.axonal;
            data(i).N_balloons = numel(data(i).balloon_coord);
        end
        data(i).N_abnorm = data(i).N_vesicles + data(i).N_myelin_def + data(i).N_balloons;
    end
end

% plot the image with ROIs (filled with value for variable of choice) and save
function plot(img_files, data, var, name, dir)
    if ~strcmp(name, 'none')
        % create colormap
        cmap = hot(length(var)+1);
        max_var = max(var);
        min_var = min(var);
        tot = max_var - min_var;
        d_var = tot/(length(var));
    end
    for img_n = 1: length(img_files)
        % plot the image
        f = figure;
        hold on;
        img_name = img_files(img_n).name;
        img = imread(img_name);
        imshow(img);
        colormap gray;
        maxPx = max(max(img));
        ax = gca;
        ax.CLim = [0 round(maxPx*0.05)];
        scale = 0.1;
        
        % plot each roi on the image
        img_fn = extractBefore(img_name,"_PSOCT");
        for i = 1:length(data)
            img_cur = extractBefore(data(i).original_image," - Z 20x");
            if strcmp(img_fn, img_cur)
                x = data(i).x_start*scale;
                y = data(i).y_start*scale;
                w = (data(i).x_end-data(i).x_start)*scale;
                h = (data(i).y_end-data(i).y_start)*scale;
                pos = [x y w h];
                if strcmp(name, 'none')
                    rectangle('Position',pos,'EdgeColor','r');
                else
                    % fill rectangle with color of corresponding variable
                    cmap_idx = round(var(i)/d_var) + 1;
                    cmap_value = cmap(cmap_idx,:);
                    rectangle('Position',pos, 'FaceColor',cmap_value,'EdgeColor','r');
                end
            end
        end
        hold off;
        cd ..\..\
        cd(dir)
        exportgraphics(ax,[img_fn, name, '_ROIs.tif'],'Resolution',300);
        cd ..\
        cd('.\supplementary_info\PSOCT_size_0.1X')
        close all;
    end
    % plot colorbar
     cd ..\..\
     cd(dir)
     hf = plot_colorbar(cmap, [min_var max_var]);
     exportgraphics(hf,[name, '_colorbar.tif'],'Resolution',300);
     cd ..\
     cd('.\supplementary_info\PSOCT_size_0.1X')
end

% plots the colorbar
function hf = plot_colorbar(cmap, limits)
    hf = figure('Units','normalized'); 
    colormap (cmap);
    hCB = colorbar('west');
    set(gca,'Visible',false);
    clim(limits);
end