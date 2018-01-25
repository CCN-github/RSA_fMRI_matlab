% This script performs Representational Disimilarity Analysis (RSA)
% in several ROIs and subjects. The Decoding Toolbox and SPM12 must be
% added to the path. The RSA is done on beta images, so before using this
% script, you should have estimated a GLM to extract the betas of interests
% (e.g. one beta per condition and run, or one beta per trial).
%
% The final output of the script is actually a similarity matrix (r), not dissimilarity (1 - r).
% If you decide to use some other distance measure (e.g. euclidean), bear
% in mind that the output would then be already a dissimilarity matrix (so
% no need to do 1 - output afterwards).
%
% 25/01/2018 v.0.1.0: - initial commit
%
% Carlos González-García (carlos.gonzalezgarcia@ugent.be)

clear all
clc

% set group parameters
subdir =  % list of participants (e.g. [1 2 3 4 5])
filebase =  % common folder where all your subjects subfolders are (e.g. 'D:/data/sub')
subfilebase =  % subject folder where beta images are stored (e.g. '/func/GLM_models/rsa/')
label_order =  % do you want to specify an order for your beta images? (e.g. beta_conditionA_1; beta_conditionA_2; beta_conditionB_1; beta_conditionB_2;). This will be the order in the dissimilarity matrix
corr_type = 'Pearson'; % distance measure (usually Pearson's r -- to see other distance options do 'edit pattern_similarity' in the command window and check lines 14:23)

rois =  % cell list with the ROI names (name of the nifti files, and specific folder if needed (e.g. {'FPN/FrontalRight' 'DMN/MPFC'})

for i = 1:length(subdir)
    fprintf(['Starting RSA for subject' num2str(subdir(1,i)) '\t'])
    
    % Set defaults
    cfg = decoding_defaults;
    cfg.plot_design=0;
    cfg.results.overwrite = 1; % check to 0 if you don't want to overwrite
    cfg.analysis = 'ROI'; % for searchlight see 'RSA_searchlight.m'
    fileroot = ([filebase num2str(subdir(1,i)) subfilebase]);
    
    % start looping over rois
    for r = 1:length(rois)
        fprintf(['ROI #' num2str(r) '\t'])
        
        cfg.results.dir = ([fileroot 'results_ROI/' rois{1,r}]) ; % where should results be stored
        beta_dir = fileroot; % beta images should be here
        cfg.files.mask = ([fileroot 'rois/' rois{1,r} '.nii']); % mask = roi in this case
        
        % If you didn't specifiy a label order before, set the label names to 
        % the regressor names which you want to use here, e.g. 'button left' and 'button right'
        % don't remember the names? -> run display_regressor_names(beta_loc)
        labelnames =  {'*Pos*', '*Neg*'};
        
        % since the labels are arbitrary, we will set them randomly to -1 and 1
        labels(1:2:length(labelnames)) = -1;
        labels(2:2:length(labelnames)) =  1;
        
        % set everything to similarity analysis
        cfg.decoding.software = 'similarity';
        cfg.decoding.method = 'classification';
        cfg.decoding.train.classification.model_parameters = corr_type;
        cfg.results.output = 'other';
        
        % cfg.searchlight.unit = 'mm'; % change to vx (voxels) if wanted
        % cfg.searchlight.radius = 2; % change if needed
        % cfg.searchlight.spherical = 1;
        cfg.verbose = 0; % change to 1 or 2 if you want to get more feedback while the script is running
        
        %% Nothing needs to be changed below for a standard similarity analysis using all data
        regressor_names = design_from_spm(beta_dir);
        cfg = decoding_describe_data(cfg,labelnames,labels,regressor_names,beta_dir);
        cfg.design = make_design_similarity(cfg);
        cfg.design.unbalanced_data = 'ok';
        % Run decoding
        results = decoding(cfg);
    end
end