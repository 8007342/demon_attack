# Spec Delta

## Purpose

Provides a reproducible, local-only workflow for turning model-generated image candidates into inspectable pixel-art game assets. It keeps model output, processed prototypes, and shipping game art distinct until a person reviews and selects a candidate.

## ADDED Requirements

### Requirement: Local-only inference and provenance
The asset workflow SHALL use local model inference and SHALL NOT send prompts, reference images, generated images, or derived project artwork to a hosted generation service. Each candidate SHALL record its prompt, negative prompt, model identity, seed, dimensions, inference backend, and local processing steps when those values are available.

#### Scenario: Local model produces a candidate
- **WHEN** an artist requests a candidate through the asset workflow
- **THEN** inference runs through an available local model, its provenance is recorded, and the workflow does not fall back to a hosted service

#### Scenario: Local inference is unavailable
- **WHEN** the local model backend cannot be reached or the requested local model is not installed
- **THEN** the workflow reports the local failure and does not send the request to a remote image service

### Requirement: Deterministic sprite preparation
The workflow SHALL transform local source images into reviewable sprite candidates on declared logical cell grids, with nearest-neighbor scaling, bounded palettes, stable frame bounds, and a machine-readable validation report. It SHALL retain the source image and SHALL NOT overwrite the shipping combat atlas during preparation.

#### Scenario: Candidate passes preparation
- **WHEN** a source image and manifest are valid
- **THEN** the workflow writes a separated source, prepared sprite sheet, preview, and report in the research output area without modifying existing game assets

#### Scenario: Candidate fails validation
- **WHEN** generated content cannot be isolated or violates declared frame, palette, or grid constraints
- **THEN** the workflow reports the failed checks and keeps the candidate out of shipping atlases

### Requirement: Human-reviewed local asset preview
The project SHALL provide a locally served review surface that presents source candidates alongside prepared sprites, frame previews, provenance, and validation results. Asset selection SHALL be an explicit human action before any candidate is promoted to shipping game assets.

#### Scenario: Review generated ship equipment
- **WHEN** the local asset review page is opened with a prepared candidate set
- **THEN** the reviewer can compare the generated hull, cannon, and force-field candidates and inspect their provenance and validation results

#### Scenario: No candidates are prepared
- **WHEN** the local review page is opened without a candidate output set
- **THEN** it explains how to run the local preparation workflow and does not present stale or shipping assets as new candidates
