# AI Layer

This folder contains model logic, inference services, and training pipelines.

## Structure
- `src/inference/` model loading, serving adapters, and response formatting
- `src/training/` training jobs, experiment scripts, and evaluation
- `src/features/` feature extraction and preprocessing
- `models/` local model artifacts (gitignored in real projects)
- `prompts/` prompt templates and prompt versioning files
- `notebooks/` exploratory notebooks and experiments

## Next implementation steps
1. Define AI tasks (classification, ranking, generation, etc.).
2. Add an inference contract shared with backend API.
3. Add model versioning policy and evaluation metrics.
4. Add batch and online inference paths.
