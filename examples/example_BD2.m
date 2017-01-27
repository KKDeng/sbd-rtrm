clc; clear;

% Import Manopt and initialize the SBD package
run('../../manopt/importmanopt'); disp('Manopt imported.')
run('../init_sbd');

%% I. SIMULATE DATA FOR SBD:
%  =========================
%% 1. Get kernel A:
kerneltype = 'simulated';       % select from below
n = 1;                          % number of kernel slices
k = [49 49];                    % kernel size

switch kerneltype
    case 'random'
    % Randomly generate n kernel slices
        A0 = randn([k n]);
    
    case 'simulated_STM'
    % Randomly choose n kernel slices from simulated LDoS data
        load('example_data\LDoS_sim.mat');
        sliceidx = randperm(size(LDoS_sim,3), n);
        
        A0 = NaN([k n]);
        for i = 1:n
            A0 = imresize(LDoS_sim(:,:,sliceidx), k);
        end
        
    otherwise
        error('Invalid kernel type specified.')
end

% Need to put each slice back onto the sphere
A0 = proj2oblique(A0);

%% 2. Simulate activation map:
m = [256 256];      % image size for each slice / observation grid

% Each pixel has probability theta of being a kernel location
theta = 1e-3;       % activation concentration
eta = 1e-3;         % additive noise variance


% Generate activation map
X0_good = false;
while ~X0_good
    X0 = double(rand(m) <= theta);
    X0_good = sum(X0(:) ~= 0) > 0;
end

%% 3. Simulate convolutional observation:
Y = cconvfft2(A0, X0) + sqrt(eta)*randn(m);

%% II. Sparse Blind Deconvolution:
%  ===============================
%% 1. Settings
% A function for showing updates as RTRM runs
dispfun = @( Y, A, X, k, kplus, idx ) showims(Y,A0,X0,A,X,k,kplus,idx);

% SBD settings
params.lambda1 = 1e-1;              % regularization parameter for Phase I

params.phase2 = true;               % whether to do Phase II (refinement)
params.kplus = ceil(0.5 * k);       % padding for sphere lifting
params.lambda2 = 1e-2;              % FINAL reg. param. value for Phase II
params.nrefine = 2;                 % number of refinements

% Want entries of X to be nonnegative: see SBD_main.m
params.signflip = 0.2;
params.xpos     = true;

%% 2. The fun part
[Aout, Xout, extras] = SBD_main( Y, k, params, dispfun );