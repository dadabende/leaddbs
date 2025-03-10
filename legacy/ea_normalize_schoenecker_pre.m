function varargout=ea_normalize_schoenecker_pre(options)
% This is a function that normalizes both a copy of transversal and coronal
% images into MNI-space. The goal was to make the procedure both robust and
% automatic, but still, it must be said that normalization results should
% be taken with much care because all reconstruction results heavily depend
% on these results. Normalization of DBS-MR-images is especially
% problematic since usually, the field of view doesn't cover the whole
% brain (to reduce SAR-levels during acquisition) and since electrode
% artifacts can impair the normalization process. Therefore, normalization
% might be best archieved with other tools that have specialized on
% normalization of such image data.
%
% The procedure used here follows the approach of Schoenecker 2008 which was
% originally programmed for use with FSL. To be able to combine both
% normalization and reconstruction steps, the principle approach was
% programmed once more using SPM.
%
% The function uses some code snippets written by Ged Ridgway.
% __________________________________________________________________________________
% Copyright (C) 2014 Charite University Medicine Berlin, Movement Disorders Unit
% Andreas Horn

usecombined=0; % if set, eauto will try to fuse coronal and transversal images before normalizing them.

if ischar(options) % return name of method.
    varargout{1}='Schoenecker 2009 linear threestep (Include Pre-OP) [MR/CT]';
    varargout{2}={'SPM8'};
    return
end

if exist([options.root,options.prefs.patientdir,filesep,options.prefs.tranii_unnormalized,'.gz'],'file')
    try
        gunzip([options.root,options.prefs.patientdir,filesep,options.prefs.cornii_unnormalized,'.gz']);
    catch
        system(['gunzip ',options.root,options.prefs.patientdir,filesep,options.prefs.cornii_unnormalized,'.gz']);
    end
    try
        gunzip([options.root,options.prefs.patientdir,filesep,options.prefs.tranii_unnormalized,'.gz']);
        gunzip([options.root,options.prefs.patientdir,filesep,options.prefs.prenii_unnormalized,'.gz']);
    catch
        system(['gunzip ',options.root,options.prefs.patientdir,filesep,options.prefs.tranii_unnormalized,'.gz']);
        system(['gunzip ',options.root,options.prefs.patientdir,filesep,options.prefs.prenii_unnormalized,'.gz']);
    end
end

% now segment the pre-op version to get some normalization weights.
matlabbatch{1}.spm.spatial.preproc.data = {[options.root,options.prefs.patientdir,filesep,options.prefs.prenii_unnormalized,',1']};
matlabbatch{1}.spm.spatial.preproc.output.GM = [0 0 1];
matlabbatch{1}.spm.spatial.preproc.output.WM = [0 0 1];
matlabbatch{1}.spm.spatial.preproc.output.CSF = [0 0 0];
matlabbatch{1}.spm.spatial.preproc.output.biascor = 0;
matlabbatch{1}.spm.spatial.preproc.output.cleanup = 0;
matlabbatch{1}.spm.spatial.preproc.opts.tpm = {
                                               fullfile(fileparts(which('spm')),'tpm','grey.nii');
                                               fullfile(fileparts(which('spm')),'tpm','white.nii');
                                               fullfile(fileparts(which('spm')),'tpm','csf.nii')
                                               };
matlabbatch{1}.spm.spatial.preproc.opts.ngaus = [2; 2; 2; 4];
matlabbatch{1}.spm.spatial.preproc.opts.regtype = 'mni'; %'mni';
matlabbatch{1}.spm.spatial.preproc.opts.warpreg = 1;
matlabbatch{1}.spm.spatial.preproc.opts.warpco = 25;
matlabbatch{1}.spm.spatial.preproc.opts.biasreg = 0.0001;
matlabbatch{1}.spm.spatial.preproc.opts.biasfwhm = 60;
matlabbatch{1}.spm.spatial.preproc.opts.samp = 3;
matlabbatch{1}.spm.spatial.preproc.opts.msk = {''};
jobs{1}=matlabbatch;
try
spm_jobman('run',jobs);
normlog(1)=1;
disp('*** Segmentation worked.');
catch
disp('*** Segmentation failed.');
end
clear matlabbatch jobs;




% Now fuse c1 and c2 to get a weight.

matlabbatch{1}.spm.util.imcalc.input = {[options.root,options.prefs.patientdir,filesep,'c1',options.prefs.prenii_unnormalized,',1'];
                                        [options.root,options.prefs.patientdir,filesep,'c2',options.prefs.prenii_unnormalized,',1']
                                        };
matlabbatch{1}.spm.util.imcalc.output = 'c1c2mask.nii';
matlabbatch{1}.spm.util.imcalc.outdir = {[options.root,options.prefs.patientdir,filesep]};
matlabbatch{1}.spm.util.imcalc.expression = 'i1+i2';
matlabbatch{1}.spm.util.imcalc.options.dmtx = 0;
matlabbatch{1}.spm.util.imcalc.options.mask = 0;
matlabbatch{1}.spm.util.imcalc.options.interp = 1;
matlabbatch{1}.spm.util.imcalc.options.dtype = 4;

jobs{1}=matlabbatch;
try
spm_jobman('run',jobs);
end
clear matlabbatch jobs;





% first step, coregistration between transversal and coronal versions. on full brain


normlog=zeros(4,1); % log success of processing steps. 4 steps: 1. coreg tra and cor, 2. grand mean normalization 3. subcortical normalization 4. subcortical fine normalization that spares the ventricles.





matlabbatch{1}.spm.spatial.coreg.estimate.ref = {[options.root,options.prefs.patientdir,filesep,options.prefs.tranii_unnormalized,',1']};
matlabbatch{1}.spm.spatial.coreg.estimate.source = {[options.root,options.prefs.patientdir,filesep,options.prefs.cornii_unnormalized,',1']};
matlabbatch{1}.spm.spatial.coreg.estimate.other = {''};
matlabbatch{1}.spm.spatial.coreg.estimate.eoptions.cost_fun = 'ncc';
matlabbatch{1}.spm.spatial.coreg.estimate.eoptions.sep = [4 2];
matlabbatch{1}.spm.spatial.coreg.estimate.eoptions.tol = [0.02 0.02 0.02 0.001 0.001 0.001 0.01 0.01 0.01 0.001 0.001 0.001];
matlabbatch{1}.spm.spatial.coreg.estimate.eoptions.fwhm = [7 7];

jobs{1}=matlabbatch;
try
spm_jobman('run',jobs);
normlog(1)=1;
disp('*** Coregistration between transversal and coronal versions worked.');
catch
disp('*** Coregistration between transversal and coronal versions failed.');
end
clear matlabbatch jobs;


% second step, coregistration between post and preoperative images on full
% brain.



matlabbatch{1}.spm.spatial.coreg.estimate.ref = {[options.root,options.prefs.patientdir,filesep,options.prefs.prenii_unnormalized,',1']};
matlabbatch{1}.spm.spatial.coreg.estimate.source = {[options.root,options.prefs.patientdir,filesep,options.prefs.tranii_unnormalized,',1']};
matlabbatch{1}.spm.spatial.coreg.estimate.other = {[options.root,options.prefs.patientdir,filesep,options.prefs.cornii_unnormalized,',1']};
matlabbatch{1}.spm.spatial.coreg.estimate.eoptions.cost_fun = 'ncc';
matlabbatch{1}.spm.spatial.coreg.estimate.eoptions.sep = [4 2];
matlabbatch{1}.spm.spatial.coreg.estimate.eoptions.tol = [0.02 0.02 0.02 0.001 0.001 0.001 0.01 0.01 0.01 0.001 0.001 0.001];
matlabbatch{1}.spm.spatial.coreg.estimate.eoptions.fwhm = [7 7];

jobs{1}=matlabbatch;
try
spm_jobman('run',jobs);
normlog(1)=1;
disp('*** Coregistration between preop and postop versions worked.');
catch
disp('*** Coregistration between preop and postop versions failed.');
%ea_error('This normalization cannot be performed automatically with eAuto. Try using different software for the normalization step. Examples are to use SPM directly, or to use FSL, Slicer or Bioimaging Suite.');
end
clear matlabbatch jobs;



%% 1/3: grand mean normalize
matlabbatch{1}.spm.spatial.normalise.estwrite.subj.source = {[options.root,options.prefs.patientdir,filesep,options.prefs.prenii_unnormalized,',1']};
matlabbatch{1}.spm.spatial.normalise.estwrite.subj.wtsrc = {[options.root,options.prefs.patientdir,filesep,'c1c2mask.nii,1']};
matlabbatch{1}.spm.spatial.normalise.estwrite.subj.resample = {[options.root,options.prefs.patientdir,filesep,options.prefs.prenii_unnormalized,',1'];
                                                               [options.root,options.prefs.patientdir,filesep,'c1c2mask.nii,1']};
matlabbatch{1}.spm.spatial.normalise.estwrite.eoptions.template = {[ea_space,'t2.nii,1']};
matlabbatch{1}.spm.spatial.normalise.estwrite.eoptions.weight = '';
matlabbatch{1}.spm.spatial.normalise.estwrite.eoptions.smosrc = 10;
matlabbatch{1}.spm.spatial.normalise.estwrite.eoptions.smoref = 10;
matlabbatch{1}.spm.spatial.normalise.estwrite.eoptions.regtype = 'mni';
matlabbatch{1}.spm.spatial.normalise.estwrite.eoptions.cutoff = 25;
matlabbatch{1}.spm.spatial.normalise.estwrite.eoptions.nits = 0;
matlabbatch{1}.spm.spatial.normalise.estwrite.eoptions.reg = 1;
matlabbatch{1}.spm.spatial.normalise.estwrite.roptions.preserve = 0;
matlabbatch{1}.spm.spatial.normalise.estwrite.roptions.bb = [-78 -112 -50; 78 76 85];
matlabbatch{1}.spm.spatial.normalise.estwrite.roptions.vox = [0.4 0.4 0.4];
matlabbatch{1}.spm.spatial.normalise.estwrite.roptions.interp = 1;
matlabbatch{1}.spm.spatial.normalise.estwrite.roptions.wrap = [0 0 0];
matlabbatch{1}.spm.spatial.normalise.estwrite.roptions.prefix = 'w1';
jobs{1}=matlabbatch;
try
spm_jobman('run',jobs);
normlog(2)=1;
disp('*** Grand mean normalization (1/3) worked.');
catch
disp('*** Grand mean normalization (1/3) failed.');
ea_error('This normalization cannot be performed automatically with eAuto. Try using different software for the normalization step. Examples are to use SPM directly, or to use FSL, Slicer or Bioimaging Suite.');
end
clear matlabbatch jobs;

%% 2/3: subcortical normalize




matlabbatch{1}.spm.spatial.normalise.estwrite.subj.source = {[options.root,options.prefs.patientdir,filesep,'w1',options.prefs.prenii_unnormalized,',1']};
matlabbatch{1}.spm.spatial.normalise.estwrite.subj.wtsrc = {[options.root,options.prefs.patientdir,filesep,'w1c1c2mask.nii,1']};
matlabbatch{1}.spm.spatial.normalise.estwrite.subj.resample = {[options.root,options.prefs.patientdir,filesep,'w1',options.prefs.prenii_unnormalized,',1'];
                                                                [options.root,options.prefs.patientdir,filesep,'w1c1c2mask.nii,1']};
matlabbatch{1}.spm.spatial.normalise.estwrite.eoptions.template = {[ea_space,'t2.nii,1']};
matlabbatch{1}.spm.spatial.normalise.estwrite.eoptions.weight = {[ea_space(options,'subcortical'),'secondstepmask.nii,1']};
matlabbatch{1}.spm.spatial.normalise.estwrite.eoptions.smosrc = 8;
matlabbatch{1}.spm.spatial.normalise.estwrite.eoptions.smoref = 8;
matlabbatch{1}.spm.spatial.normalise.estwrite.eoptions.regtype = 'mni';
matlabbatch{1}.spm.spatial.normalise.estwrite.eoptions.cutoff = 25;
matlabbatch{1}.spm.spatial.normalise.estwrite.eoptions.nits = 0;
matlabbatch{1}.spm.spatial.normalise.estwrite.eoptions.reg = 1;
matlabbatch{1}.spm.spatial.normalise.estwrite.roptions.preserve = 0;
matlabbatch{1}.spm.spatial.normalise.estwrite.roptions.bb = [-78 -112 -50; 78 76 85];
matlabbatch{1}.spm.spatial.normalise.estwrite.roptions.vox = [0.4 0.4 0.4];
matlabbatch{1}.spm.spatial.normalise.estwrite.roptions.interp = 1;
matlabbatch{1}.spm.spatial.normalise.estwrite.roptions.wrap = [0 0 0];
matlabbatch{1}.spm.spatial.normalise.estwrite.roptions.prefix = 'w2';



jobs{1}=matlabbatch;
try
    spm_jobman('run',jobs);
    normlog(3)=1;
    disp('*** Subcortical normalization (2/3) worked.');
catch
    disp('*** Subcortical normalization (2/3) failed.');
    warning('Probably, this normalization is not accurate enough. Please try normalizing the MR-images with a different software suite.');
end
clear matlabbatch jobs;



%% 3/3: small mask normalize



matlabbatch{1}.spm.spatial.normalise.estwrite.subj.source = {[options.root,options.prefs.patientdir,filesep,'w2w1',options.prefs.prenii_unnormalized,',1']};
matlabbatch{1}.spm.spatial.normalise.estwrite.subj.wtsrc = {[options.root,options.prefs.patientdir,filesep,'w2w1c1c2mask.nii,1']};
matlabbatch{1}.spm.spatial.normalise.estwrite.subj.resample = {[options.root,options.prefs.patientdir,filesep,'w2w1',options.prefs.prenii_unnormalized,',1']};
matlabbatch{1}.spm.spatial.normalise.estwrite.eoptions.template = {[ea_space,'t2.nii,1']};
matlabbatch{1}.spm.spatial.normalise.estwrite.eoptions.weight = {[ea_space(options,'subcortical'),'thirdstepmask.nii,1']};
matlabbatch{1}.spm.spatial.normalise.estwrite.eoptions.smosrc = 8;
matlabbatch{1}.spm.spatial.normalise.estwrite.eoptions.smoref = 8;
matlabbatch{1}.spm.spatial.normalise.estwrite.eoptions.regtype = 'mni';
matlabbatch{1}.spm.spatial.normalise.estwrite.eoptions.cutoff = 25;
matlabbatch{1}.spm.spatial.normalise.estwrite.eoptions.nits = 0;
matlabbatch{1}.spm.spatial.normalise.estwrite.eoptions.reg = 1;
matlabbatch{1}.spm.spatial.normalise.estwrite.roptions.preserve = 0;
matlabbatch{1}.spm.spatial.normalise.estwrite.roptions.bb = [-55 45 9.5; 55 -65 -25.0];
matlabbatch{1}.spm.spatial.normalise.estwrite.roptions.vox = [0.4 0.4 0.4];
matlabbatch{1}.spm.spatial.normalise.estwrite.roptions.interp = 1;
matlabbatch{1}.spm.spatial.normalise.estwrite.roptions.wrap = [0 0 0];
matlabbatch{1}.spm.spatial.normalise.estwrite.roptions.prefix = 'w3';
jobs{1}=matlabbatch;
try
    spm_jobman('run',jobs);
    normlog(4)=1;
    disp('*** Subcortical fine normalization (3/3) worked.');
catch
    disp('*** Subcortical fine normalization (3/3) failed.');
    warning('This normalization might not be accurate enough. Please check normalization thoroughly.');
end
clear matlabbatch jobs;


% apply estimated transformations to cor and tra.



[~,nm]=fileparts(options.prefs.prenii_unnormalized); % cut off file extension
includedefs=1:3;
for def=includedefs(logical(normlog(2:4)))
    voxi=[NaN NaN NaN];
    bbi=[NaN NaN NaN; NaN NaN NaN];
    switch def
        case 1
            wstr='';
        case 2
            wstr='w1';
        case 3
            wstr='w2w1';

    end

    if def==max(find(normlog)-1) % last normalization
        voxi=[0.22 0.22 0.5]; % export highres
        bbi=[-55 45 9.5; 55 -65 -25]; % ?with small bounding box
    end
    matlabbatch{1}.spm.util.defs.comp{def}.sn2def.matname = {[options.root,options.prefs.patientdir,filesep,wstr,nm,'_sn.mat']};
    matlabbatch{1}.spm.util.defs.comp{def}.sn2def.vox = voxi;
    matlabbatch{1}.spm.util.defs.comp{def}.sn2def.bb = bbi;
end

matlabbatch{1}.spm.util.defs.ofname = '';
matlabbatch{1}.spm.util.defs.fnames = {
                                       [options.root,options.prefs.patientdir,filesep,options.prefs.tranii_unnormalized,',1'];
                                       [options.root,options.prefs.patientdir,filesep,options.prefs.cornii_unnormalized,',1'];
                                       [options.root,options.prefs.patientdir,filesep,options.prefs.prenii_unnormalized,',1']
                                       };
matlabbatch{1}.spm.util.defs.savedir.saveusr = {[options.root,options.prefs.patientdir,filesep]};
matlabbatch{1}.spm.util.defs.interp = 6;

jobs{1}=matlabbatch;
try
    spm_jobman('run',jobs);
catch % CT

    matlabbatch{1}.spm.util.defs.fnames = {
        [options.root,options.prefs.patientdir,filesep,options.prefs.ctnii_coregistered,',1'];
        [options.root,options.prefs.patientdir,filesep,options.prefs.prenii_unnormalized,',1']
        };
    jobs{1}=matlabbatch;


    spm_jobman('run',jobs);

end
clear matlabbatch jobs;




% write out combined transformation matrix
for tmat=includedefs(logical(normlog(2:4)))
switch tmat
    case 1
        wstr='';
        w2str='w1';
    case 2
        wstr='w1';
        w2str='w2w1';
    case 3
        wstr='w2w1';
        w2str='w3w2w1';
end
T{tmat}=load([options.root,options.prefs.patientdir,filesep,wstr,nm,'_sn.mat']);
T{tmat}.M = T{tmat}.VG(1).mat*inv(T{tmat}.Affine)*inv(T{tmat}.VF(1).mat); % get mmM that transforms from mm to mm space.
T{tmat}.VFM=worldmat2flirtmat(T{tmat}.M,[options.root,options.prefs.patientdir,filesep,wstr,options.prefs.prenii_unnormalized],[options.root,options.prefs.patientdir,filesep,w2str,options.prefs.prenii_unnormalized]);

switch tmat
    case 1
        FLIRTMAT=T{tmat}.VFM;
        M=T{tmat}.M;
    otherwise
        FLIRTMAT=FLIRTMAT*T{tmat}.VFM;
        M=M*T{tmat}.M;

end
end



% % Save transformation for later use in FLIRT
% flirtmat_write([options.root,options.prefs.patientdir,filesep,'flirt_transform'],FLIRTMAT);
%
% mmFLIRT=flirtmat2worldmat(FLIRTMAT,[options.root,options.prefs.patientdir,filesep,options.prefs.prenii_unnormalized],[options.root,options.prefs.patientdir,filesep,'w',options.prefs.prenii_unnormalized]);
% flirtmat_write([options.root,options.prefs.patientdir,filesep,'mmflirt_transform'],mmFLIRT);
% % Save transformation matrix M that maps from mm space in native acquisition to mm space in MNI space.
% save([options.root,options.prefs.patientdir,filesep,'ea_normparams'],'T','M');


% now the files have been normalized, cleanup first
ea_delete([options.root,options.prefs.patientdir,filesep,'w1',options.prefs.prenii_unnormalized]);
ea_delete([options.root,options.prefs.patientdir,filesep,'w2w1',options.prefs.prenii_unnormalized]);
ea_delete([options.root,options.prefs.patientdir,filesep,'w3w2w1',options.prefs.prenii_unnormalized]);

ea_delete([options.root,options.prefs.patientdir,filesep,'c1',options.prefs.tranii_unnormalized]);
ea_delete([options.root,options.prefs.patientdir,filesep,'c2',options.prefs.tranii_unnormalized]);


ea_delete([options.root,options.prefs.patientdir,filesep,'c1c2mask.nii']);
ea_delete([options.root,options.prefs.patientdir,filesep,'w1c1c2mask.nii']);
ea_delete([options.root,options.prefs.patientdir,filesep,'w2w1c1c2mask.nii']);

ea_delete([options.root,options.prefs.patientdir,filesep,nm,'_sn.mat']);
ea_delete([options.root,options.prefs.patientdir,filesep,'w1',nm,'_sn.mat']);
ea_delete([options.root,options.prefs.patientdir,filesep,'w2w1',nm,'_sn.mat']);

% make normalization "permanent" and include correct bounding box.
for export=2:5
    switch export
        case 2
            outf=options.prefs.tranii;
            infile=[options.root,options.prefs.patientdir,filesep,'w',options.prefs.tranii_unnormalized,',1'];
        case 3
            outf=options.prefs.cornii;
            infile=[options.root,options.prefs.patientdir,filesep,'w',options.prefs.cornii_unnormalized,',1'];
        case 4 % ct
            outf=options.prefs.ctnii;
            infile=[options.root,options.prefs.patientdir,filesep,'w',options.prefs.ctnii_coregistered,',1'];
        case 5 % pre
            outf=options.prefs.prenii;
            infile=[options.root,options.prefs.patientdir,filesep,'w',options.prefs.prenii_unnormalized,',1'];
    end
matlabbatch{1}.spm.util.imcalc.input = {[ea_space,'bb.nii,1'];
                                        infile};
matlabbatch{1}.spm.util.imcalc.output = outf;
matlabbatch{1}.spm.util.imcalc.outdir = {[options.root,options.prefs.patientdir,filesep]};
matlabbatch{1}.spm.util.imcalc.expression = ['i2'];
matlabbatch{1}.spm.util.imcalc.options.dmtx = 0;
matlabbatch{1}.spm.util.imcalc.options.mask = 0;
matlabbatch{1}.spm.util.imcalc.options.interp = 1;
matlabbatch{1}.spm.util.imcalc.options.dtype = 4;
jobs{1}=matlabbatch;
try
spm_jobman('run',jobs);
end
clear matlabbatch jobs;
end





% cleanup wfilename files if prefs are set differently
% transversal images
if ~strcmp(options.prefs.tranii,['w',options.prefs.tranii_unnormalized])
    ea_delete([options.root,options.prefs.patientdir,filesep,'w',options.prefs.tranii_unnormalized]);
end
% coronal images
if ~strcmp(options.prefs.cornii,['w',options.prefs.cornii_unnormalized])
    ea_delete([options.root,options.prefs.patientdir,filesep,'w',options.prefs.cornii_unnormalized]);
end

% ct images
if ~strcmp(options.prefs.ctnii,['w',options.prefs.rawctnii_unnormalized])
    ea_delete([options.root,options.prefs.patientdir,filesep,'w',options.prefs.cornii_unnormalized]);
end

% now the files have been normalized, cleanup.
ea_delete([options.root,options.prefs.patientdir,filesep,'w1',options.prefs.tranii_unnormalized]);
ea_delete([options.root,options.prefs.patientdir,filesep,'w2w1',options.prefs.tranii_unnormalized]);
ea_delete([options.root,options.prefs.patientdir,filesep,'w3w2w1',options.prefs.tranii_unnormalized]);

ea_delete([options.root,options.prefs.patientdir,filesep,'c1',options.prefs.tranii_unnormalized]);
ea_delete([options.root,options.prefs.patientdir,filesep,'c2',options.prefs.tranii_unnormalized]);

ea_delete([options.root,options.prefs.patientdir,filesep,'c',options.prefs.cornii_unnormalized]);
ea_delete([options.root,options.prefs.patientdir,filesep,'rc',options.prefs.cornii_unnormalized]);


ea_delete([options.root,options.prefs.patientdir,filesep,'c1c2mask.nii']);
ea_delete([options.root,options.prefs.patientdir,filesep,'w1c1c2mask.nii']);
ea_delete([options.root,options.prefs.patientdir,filesep,'w2w1c1c2mask.nii']);

ea_delete([options.root,options.prefs.patientdir,filesep,nm,'_sn.mat']);
ea_delete([options.root,options.prefs.patientdir,filesep,'w1',nm,'_sn.mat']);
ea_delete([options.root,options.prefs.patientdir,filesep,'w2w1',nm,'_sn.mat']);






function [flirtmat spmvoxmat fslvoxmat] = worldmat2flirtmat(worldmat, src, trg)
%worldmat2flirtmat: convert NIfTI world (mm) coordinates matrix to flirt
%
% Example:
%  [flirtmat spmvoxmat fslvoxmat] = worldmat2flirtdmat(worldmat, src, trg);
%
% See also: flirtmat2worldmat, flirtmat_write

% Copyright 2009 Ged Ridgway <ged.ridgway gmail.com>

if ischar(src)
    src = nifti(src);
end
if ischar(trg)
    trg = nifti(trg);
end

spmvoxmat = inv(src.mat) * worldmat * trg.mat;
addone = eye(4); addone(:, 4) = 1;
fslvoxmat = inv(addone) * spmvoxmat * addone;
trgscl = nifti2scl(trg);
srcscl = nifti2scl(src);
flirtmat = inv( srcscl * fslvoxmat * inv(trgscl) );



function flirtmat_write(fname, mat)
%flirtmat_write: save a 4-by-4 matrix to a file as handled by flirt -init
% Example:
%  flirtmat_write(fname, affinemat)
% See also: flirtmat_read, flirtmat2worldmat, worldmat2flirtmat

% Copyright 2009 Ged Ridgway <ged.ridgway gmail.com>

fid = fopen(fname, 'w');
% Note that transpose is needed to go from MATLAB's column-major matrix to
% writing the file in a row-major way (see also flirtmat_read)
str = sprintf('%f  %f  %f  %f\n', mat');
fprintf(fid, str(1:end-1)); % drop final newline
fclose(fid);




function [worldmat spmvoxmat fslvoxmat] = flirtmat2worldmat(flirtmat, src, trg)
%flirtmat2worldmat: convert saved flirt matrix to NIfTI world coords matrix
% flirt matrix is from text file specified in "flirt -omat mat.txt" command
% world matrix maps from NIfTI world coordinates in target to source. Note:
% mat.txt contains a mapping from source to target in FSL's *scaled* coords
% which are not NIfTI world coordinates, and note src-trg directionality!
% worldmat from this script reproduces "img2imgcoord -mm ...".
%
% The script can also return a matrix to map from target to source voxels
% in MATLAB/SPM's one-based convention, or in FSL's zero-based convention
%
% Example:
%  [worldmat spmvoxmat fslvoxmat] = flirtmat2worldmat(flirtmat, src, trg);
%
% See also: worldmat2flirtmat, flirtmat_read, flirtmat_write

% Copyright 2009 Ged Ridgway <ged.ridgway gmail.com>

if ischar(src)
    src = nifti(src);
end
if ischar(trg)
    trg = nifti(trg);
end

if ischar(flirtmat)
    flirtmat = flirtmat_read(flirtmat);
end

% src = inv(flirtmat) * trg
% srcvox = src.mat \ inv(flirtmat) * trg.mat * trgvox
% BUT, flirt doesn't use src.mat, only absolute values of the
% scaling elements from it,
% AND, if images are not radiological, the x-axis is flipped, see:
%  https://www.jiscmail.ac.uk/cgi-bin/webadmin?A2=ind0810&L=FSL&P=185638
%  https://www.jiscmail.ac.uk/cgi-bin/webadmin?A2=ind0903&L=FSL&P=R93775
trgscl = nifti2scl(trg);
srcscl = nifti2scl(src);
fslvoxmat = inv(srcscl) * inv(flirtmat) * trgscl;

% AND, Flirt's voxels are zero-based, while SPM's are one-based...
addone = eye(4); addone(:, 4) = 1;
spmvoxmat = addone * fslvoxmat * inv(addone);

worldmat = src.mat * spmvoxmat * inv(trg.mat);


%%
function scl = nifti2scl(N)
% not sure if this is always correct with rotations in mat, but seems okay!
scl = diag([sqrt(sum(N.mat(1:3,1:3).^2)) 1]);
if det(N.mat) > 0
    % neurological, x-axis is flipped, such that [3 2 1 0] and [0 1 2 3]
    % have the same *scaled* coordinates:
    xflip = diag([-1 1 1 1]);
    xflip(1, 4) = N.dat.dim(1)-1; % reflect about centre
    scl = scl * xflip;
end
