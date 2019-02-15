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
% 15/02/2019 v 0.2.0: - implemented crossvalidation
%                     - implemented multivariate noise normalization (see
%                     https://www.sciencedirect.com/science/article/pii/S1053811915011258)
%
% Carlos González-García (carlos.gonzalezgarcia@ugent.be)

clear all
clc

% set group parameters
subdir =  % list of participants (e.g. [1 2 3 4 5])
filebase =   % common folder where all your subjects subfolders are (e.g. 'D:/data/sub')
subfilebase =  % subject folder where beta images are stored (e.g. '/func/GLM_models/rsa/')
label_order =  % do you want to specify an order for your beta images? (e.g. beta_conditionA_1; beta_conditionA_2; beta_conditionB_1; beta_conditionB_2;). This will be the order in the dissimilarity matrix
corr_type = % distance measure (usually Pearson's r -- to see other distance options do 'edit pattern_similarity' in the command window and check lines 14:23)

rois =  % cell list with the ROI names (name of the nifti files, and specific folder if needed (e.g. {'FPN/FrontalRight' 'DMN/MPFC'})

do_cv = 1; % compute cross-validated distance (please, keep in mind this will use euclidean distance instance of Pearson's r)
do_MNN = 1; % do noise normalization (using residuals from SPM.mat)
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
        beta_loc = fileroot; % beta images should be here
        cfg.files.mask = ([fileroot 'rois/' rois{1,r} '.nii']); % mask = roi in this case
        
        % If you didn't specifiy a label order before, set the label names to
        % the regressor names which you want to use here, e.g. 'button left' and 'button right'
        % don't remember the names? -> run display_regressor_names(beta_loc)
        labelnames =  {'*Pos*', '*Neg*'};
        
        % since the labels are arbitrary, we will set them randomly to -1 and 1
        labels(1:2:length(labelnames)) = -1;
        labels(2:2:length(labelnames)) =  1;
        
        % set similarity analysis
        if do_cv == 0
            cfg.decoding.software = 'similarity';
            cfg.decoding.method = 'classification';
            cfg.decoding.train.classification.model_parameters = corr_type;
            cfg.results.output = 'other';
        elseif do_cv == 1
            cfg.decoding.software = 'distance';
            cfg.decoding.method = 'classification';
            cfg.decoding.train.classification.model_parameters = 'cveuclidean';
            % 'other_average' average means averaged across folds. Alternatively, you could use the output 'RSA_beta' which is
            % more general purpose, but a little more complex. Also, you can use
            % 'other_meandist', which averages across (dis)similarity matrices of each
            % cross-validation iteration and across all cells of the lower diagonal
            % (i.e. all distance comparisons).
            cfg.results.output = 'other_average'; %
        end
        
        % set normalization
        % These parameters carry out the multivariate noise normalization using the
        % residuals.
        % The crossnobis distance is identical to the cross-validated Euclidean
        % distance after prewhitening (multivariate noise normalization). It has
        % been shown that a good estimate for the multivariate noise is provided
        % by the residuals of the first-level model, in addition with Ledoit-Wolf
        % regularization. Here we calculate those residuals. If you have them
        % available already, you can load them into misc.residuals using only the
        % voxels from cfg.files.mask
        if do_MNN == 1
            if ~exist(fullfile(beta_loc,['residuals_' rois{r} '.mat']),'file')
                cfg.scale.method = 'cov'; % we scale by noise covariance
                cfg.scale.estimation = 'separate'; % we scale all data for each run separately while iterating across searchlight spheres
                cfg.scale.shrinkage = 'lw2'; % Ledoit-Wolf shrinkage retaining variances
                [misc.residuals,cfg.files.residuals.chunk] = residuals_from_spm(fullfile(beta_loc,'SPM.mat'),cfg.files.mask); % this only needs to be run once and can be saved and loaded
                save((fullfile(beta_loc,['residuals_' rois{r} '.mat'])),'misc')
            else
                load(fullfile(beta_loc,['residuals_' rois{r} '.mat']))
            end
        end
        
        % cfg.searchlight.unit = 'mm'; % change to vx (voxels) if wanted
        % cfg.searchlight.radius = 2; % change if needed
        % cfg.searchlight.spherical = 1;
        cfg.verbose = 0; % change to 1 or 2 if you want to get more feedback while the script is running
        
        %% Nothing needs to be changed below for a standard similarity analysis using all data
        
        regressor_names = design_from_spm(beta_dir);
        
        
        cfg = decoding_describe_data(cfg,labelnames,labels,regressor_names,beta_dir);
        if do_cv == 0
            cfg.design = make_design_similarity(cfg);
        elseif do_cv == 1
            % This creates a design in which cross-validation is done between the distance estimates
            cfg.design = make_design_similarity_cv(cfg);
        end
        
        cfg.design.unbalanced_data = 'ok';
        % Run decoding
        if do_MNN == 0
            results = decoding(cfg);
        elseif do_MNN == 1
            results = decoding(cfg,[],misc);
        end
        
    end
end