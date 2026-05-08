# Rock3DModeling

Rock3DModeling is a MATLABbased framework designed to reconstruct continuous 3D structural planes of unstable rock masses from outcrop point cloud data. The method integrates three core algorithms: point cloud feature extraction, fracturemechanicsconstrained Bayesian MCMC inversion, and sweepbased 3D modeling.

Traditional measurement methods cannot obtain highprecision structural plane information hidden at rock mass interfaces. By embedding theoretical fracture mechanics into Bayesian priors, the framework provides probabilistic predictions of internal trace lengths from limited field observations. A physicsinformed multichain initialization strategy (ModeI dominant, mixedmode, ModeII dominant, and random exploration) ensures reliable convergence. The sweepbased modeling algorithm generates continuous 3D structural planes.

Our methodology is validated using point cloud data collected from highsteep rock slopes. The framework eliminates the need for manual structural plane interpretation and expands the application of remote sensing technology in rock mass surveying.



## Key Features

✅ **PhysicsConstrained Bayesian MCMC Inversion**
 Fracturemechanicsbased priors derived from linear elastic fracture mechanics and shear dilation theory.
 Physicsinformed multichain initialization covering distinct mechanical hypotheses.
 Probabilistic prediction of aperturetrace length relationship with uncertainty quantification (7 confidence intervals).

✅ **Point Cloud Feature Extraction**
 Densitybased segmentation and anisotropy analysis for fracture identification.
 Automatically extracts structural plane centerlines, apertures, propagation directions, and normal vectors from noisy and incomplete point cloud data.

✅ **SweepBased 3D Modeling**
 Generates continuous 3D structural planes with variable crosssections using sweep lofting.
 Supports multiconfidencelevel predictions (7 intervals from 35% to 95%).
 Mesh output (vertices and faces) compatible with standard visualization tools.

✅ **EndtoEnd Workflow**
 Complete pipeline from raw point cloud (.ply, .mat) to 3D structural plane models.
 Batch processing for multiple fracture clusters.
 Parallel computing support for multichain MCMC sampling.



## Results

<img width="498" height="665" alt="image" src="https://github.com/user-attachments/assets/9da9e778-9b70-4440-bbdc-3c9acc6f8839" />


## Installation

### Requirements

 MATLAB R2019b
 Toolboxes: Statistics and Machine Learning Toolbox, Parallel Computing Toolbox (recommended)

### Dependencies

The framework calls the following custom functions (included in the repository):

| Function | Description |
|||
| bayesian_mcmc_inversion.m | Main MCMC inversion with fracturemechanicsbased priors |
| DSdensity.m | Density calculation for point cloud segmentation |
| PCdensity_test.m | Point cloud density mapping and anisotropy visualization |
| extractMaxValueLine2.m | Centerline extraction from density map |
| sweep_loft_mesh_variable.m | Sweepbased 3D structural plane generation with variable crosssections |
| assign_centerline_segments.m | Centerline segmentation for variable crosssection modeling |
| combine_all_meshes.m | Mesh merging utility for multifracture surfaces |
| visualize_sweep_loft.m | Visualization utilities for sweep modeling results |

## Architecture


Rock3DModeling/
├── bayesian_mcmc_inversion.m    # Main MCMC inversion with fracturemechanics priors
├── DSdensity.m                   # Densitybased point cloud segmentation
├── PCdensity_test.m              # Point cloud density mapping and visualization
├── extractMaxValueLine2.m        # Centerline extraction from density map
├── sweep_loft_mesh_variable.m    # Sweepbased 3D modeling engine
├── assign_centerline_segments.m  # Centerline segmentation for sweep modeling
├── combine_all_meshes.m          # Mesh merging and postprocessing
├── visualize_sweep_loft.m        # Visualization utilities
└── examples/
    └── main_workflow.m           # Complete workflow example




## Workflow

The framework operates in four stages:


Raw Point Cloud (.ply/.mat)
        ↓
[Stage 1] MCMC Bayesian Inversion Training
         Load aperturetrace length data
         Multichain parallel MCMC sampling
         Fracturemechanicsbased priors
         Posterior distribution and 7 prediction functions
        ↓
[Stage 2] Point Cloud Feature Extraction
         Density mapping and normalization
         Centerline extraction
         Aperture calculation
         Normal vector estimation
         Fracture clustering
        ↓
[Stage 3] Trace Length Prediction & Sweep Modeling
         Probabilistic prediction (7 confidence intervals)
         Centerline segmentation
         Variable crosssection generation
         Multifracture surface construction
        ↓
[Stage 4] 3D Structural Plane Model




## Usage

### Quick Start
A demo dataset is included. Replace the file paths in "Main_Fracture_modeling.m" with the provided "2..mat" and "3.ply" paths, then run the script.

matlab
%% Stage 1: MCMC Bayesian inversion training
[results, params_mean, post_samples] = bayesian_mcmc_inversion(...
    'data.mat', ...
    'n_chains', 4, ...
    'n_iter', 30000, ...
    'n_burn', 70, ...
    'train_ratio', 0.8, ...
    'scale_factor', 10, ...
    'use_parallel', true);

%% Stage 2: Point cloud feature extraction
ptCloud = pcread('pointcloud.ply');
[density_map, ~] = PCdensity_test(ptCloud, searchrange, datadensity);
[FractureProperties, Fractioninformations] = extractMaxValueLine2(...
    ptCloud.Location, density_map, 0.2, 50, referencePoints);

%% Stage 3: Sweepbased 3D modeling
for conf_idx = 1:7
    predict_func = results.predict_funcs_by_quantile{conf_idx};
    L_predicted = predict_func(apertures);
    [V, F, upper, lower] = sweep_loft_mesh_variable(...
        centerline, seg_idx, apertures, L_predicted, normal_vector, 20);
end

%% Stage 4: Visualization
visualize_sweep_loft(centerline, V, F, upper_surface, lower_surface);


### Supported Input Formats

 **Point clouds**: .ply, .mat (N×3 array)
 **Training data**: .mat containing aperture and trace length pairs

### Outputs

 Trained model with posterior samples (trained_model.mat)
 3D structural plane meshes for 7 confidence intervals (fracture_3d_model_confidence_*.mat)
 Merged fracture surfaces for visualization (combined_meshes)



## Tutorials

📌 **Stepbystep guides:**

 **MCMC inversion parameter setup** – docs/mcmc_parameters.md
 **Point cloud preprocessing and density mapping** – docs/pointcloud_processing.md
 **Centerline extraction algorithm** – docs/centerline_extraction.md
 **Sweep modeling variable crosssection** – docs/sweep_modeling.md
 **Complete workflow example** – examples/main_workflow.m
