% This script performs model-based Representational Disimilarity Analysis (RSA)
% across the brain. A model (matrix of ones and zeros, see
% valence_model.mat for an example) is needed. For each sphere of the
% searchlight, this script will compute the dissimilarity matrix (RDM) of the
% neural data in that sphere. Afterwards, it will (Spearman) correlate the neural RDM
% with the model matrix, assigning the (Spearman's rho) value to the
% voxel in the center of the sphere.
%
% In order to do this, you need to add the function transres_valence.m to
% the output measures included in The Decoding Toolbox in the
% transform_results folder (e.g.
% C:\Users\carlos\Documents\decoding_toolbox_v3.99\transform_results\)
% Please take into account each output function (e.g. transres_valence)
% loads the required model (valence_model in this case), so change this
% accordingly if you test other models (or just add a new output function
% for each model you want to test).
%
% The Decoding Toolbox and SPM12 must be  added to the path. The RSA is done on beta images, so before using this
% script, you should have estimated a GLM to extract the betas of interests
% (e.g. one beta per condition and run, or one beta per trial).
%
% 25/01/2018 v.0.1.0: - initial commit
%
% Carlos González-García (carlos.gonzalezgarcia@ugent.be)

clear all
clc

subj = {'01' '02' '03'}; % cell list with participant numbers
label_order =  % do you want to specify an order for your beta images? (e.g. beta_conditionA_1; beta_conditionA_2; beta_conditionB_1; beta_conditionB_2;). This will be the order in the dissimilarity matrix
corr_type = 'Pearson'; % distance measure (usually Pearson's r -- to see other distance options do 'edit pattern_similarity' in the command window and check lines 14:23)
model = 'valence_model';
load(model);

for s = 1:length(subj)
    
    % Set defaults
    cfg = decoding_defaults;
    cfg.analysis = 'searchlight'; % potentially, you could only look at one ROI. If that's the case change to 'ROI'
    cfg.plot_design=0;
    cfg.results.overwrite = 1; % check to 0 if you don't want to overwrite
    
    % Set the output directory where data will be saved, e.g. 'c:\exp\results\buttonpress'
    cfg.results.dir =  ['/home/user/Carlos/Results/RSA_searchlight_valence/S0' num2str(subj{s})];
    
    % Set the filepath where your SPM.mat and all related betas are, e.g. 'c:\exp\glm\model_button'
    beta_loc = ['/home/user/Escritorio/UG_JUNIO/Datos Reso/MVPA/mvpa_respuesta/beta_run/S0' subj{s}];
    spm_loc = beta_loc;
    cfg.files.mask = [spm_loc '/mask.nii']; % this is the whole brain (output of SPM GLM)
    
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
    cfg.results.output = 'valence'; % this should be the name of your output function without the 'transres_' portion
    
    %% Set additional parameters
    % cfg.searchlight.unit = 'mm'; % change to vx (voxels) if wanted
    % cfg.searchlight.radius = 2; % change if needed
    % cfg.searchlight.spherical = 1;
    cfg.verbose = 0; % change to 1 or 2 if you want to get more feedback while the script is running
    
    %% Nothing needs to be changed below for a standard similarity analysis using all data
    regressor_names = design_from_spm(spm_loc);
    cfg = decoding_describe_data(cfg,labelnames,labels,regressor_names,beta_loc);
    cfg.design = make_design_similarity(cfg);
    cfg.design.unbalanced_data = 'ok';
    
    % Run decoding
    results = decoding(cfg);
end
