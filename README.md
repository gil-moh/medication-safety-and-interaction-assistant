# Medication Safety and Interaction Assistant

An AI agent built on InterSystems IRIS AI Hub that analyses a patient's FHIR medication record for safety signals. Given a patient ID, it queries a FHIR R4 server and runs deterministic checks across 12 safety categories, producing structured findings and recommended clinician actions.

**Safety categories checked:**
Black box warnings · Drug-drug interactions · Drug-food cautions · Population contraindications (age, pregnancy/lactation) · Activity cautions (driving, machinery) · Drug-condition warnings · Lab threshold warnings · QT/arrhythmia risk · Anticholinergic burden · Mental health warnings · Family history risks · Duplicate therapy · Allergy cross-check · Adherence signals

## Team

- Gil Tavassy — [Developer Community profile](https://community.intersystems.com/user/gil-tavassy) · [LinkedIn](https://www.linkedin.com/in/gil-tavassy-5703b311b)

Submission mode: solo project.

## Architecture

Two containers work together:

| Container | Image | Purpose |
|---|---|---|
| `fhir` | `intersystemsdc/irishealth-community:latest` | FHIR R4 server — stores and serves patient data |
| `iris` | `irishealth-community:2026.2.0AI.162.0` (AI Hub EAP) | Runs the ObjectScript safety engine |

## Prerequisites

- **Docker Desktop** (Windows / Mac) or Docker Engine (Linux)
- **InterSystems IRIS AI Hub EAP image** — the AI Hub is baked into this image.
  1. Register / log in at https://evaluation.intersystems.com/Eval/early-access/AIHub and select the **AI Hub** program.
  2. Download **two files**:
     - `irishealth-community-2026.2.0AI.162.0-docker.tar.gz` (x64) — or the `arm64` variant for Mac M-series
     - `iris-container-x64.key` (or `iris-container-arm64.key` for ARM64)
  3. Load and tag the image (one-time step per machine):
     ```
     docker image load -i irishealth-community-2026.2.0AI.162.0-docker.tar.gz
     docker tag docker.iscinternal.com/docker-intersystems/intersystems/irishealth-community:2026.2.0AI.162.0 irishealth-community:2026.2.0AI.162.0
     ```

## Quick start

1. Clone this repository.
2. Copy your `iris-container-x64.key` into the `keys/` folder at the repo root.
3. Build and start both containers:
   ```
   docker compose build
   docker compose up -d
   ```
4. Wait ~60 seconds for both containers to become healthy.
5. Load patient data into the FHIR server (see [Patient data](#patient-data) below).
6. Run a safety analysis.

## Patient data

The safety engine requires at least one patient in the `fhir` container's FHIR R4 server (`http://localhost:52776/fhir/r4`).

**Option A — Load from the included test cases**

Each file in `med_safety_io/` contains a ready-made FHIR patient bundle under `inputResources`. Use the included helper script to post all test profiles at once:

```
python scripts/create_medication_safety_profiles.py
```

This creates patients covering the main safety scenarios: duplicate therapy, drug-drug interaction, allergy conflict, QT risk, anticholinergic burden, and more.

**Option B — Load your own FHIR R4 patient**

Use any FHIR R4 client (Postman, HAPI FHIR CLI, curl) to POST patient data to `http://localhost:52776/fhir/r4`.

Note the patient ID — you'll use it in the run command below.

## Running a safety analysis

Replace `<patientId>` with your patient's FHIR ID:

```bash
docker exec medication-safety-and-interaction-assistant-iris-1 bash -c \
  "printf 'Do ##class(Sample.AI.Examples.MedicationSafetyAssistant).Demo(\"<patientId>\",\"detailed\")\nHalt\n' \
  | iris session IRIS -U USER 2>&1 | grep -Ev '^(USER>|Node:)'"
```

**Test case patient IDs** (after running `create_medication_safety_profiles.py`):

| Patient ID | Scenario |
|---|---|
| `med-safe-dup-001` | Duplicate therapy (two Metformin strengths) |
| `med-safe-interaction-001` | Drug-drug interaction (Warfarin + Aspirin) |
| `med-safe-allergy-001` | Allergy conflict (Penicillin allergy + Amoxicillin Rx) |
| `med-safe-qt-001` | QT prolongation risk |
| `med-safe-anticholinergic-001` | Anticholinergic burden |
| `med-safe-blackbox-001` | Black box warning |
| `med-safe-condition-001` | Drug-condition warning |
| `med-safe-lab-001` | Medication + lab threshold warning |
| `med-safe-mental-001` | Mental health medication warning |
| `med-safe-family-001` | Family history risk |
| `med-safe-population-age-001` | Age-related contraindication |
| `med-safe-population-preg-001` | Pregnancy contraindication |

## Environment variables

| Variable | Default | Purpose |
|---|---|---|
| `FHIR_BASE_URL` | `http://fhir:52773/fhir/r4` | FHIR R4 endpoint |
| `FHIR_BASIC_USER` | `_SYSTEM` | Basic auth username |
| `FHIR_BASIC_PASS` | `SYS` | Basic auth password |
| `FHIR_BEARER_TOKEN` | _(none)_ | Bearer token (alternative to basic auth) |

## FHIR resources used

`Patient` · `MedicationRequest` · `MedicationStatement` · `AllergyIntolerance` · `Condition` · `Observation` · `FamilyMemberHistory`

## Output structure

Each analysis produces:

- **Patient Overview** — demographics and evidence inventory
- **Clinical Snapshot** — findings across all 12 safety categories (strict warnings first, then conservative)
- **Recommended Actions** — structured list with `actionType`, `priority`, `slaHours`, `sourceRisk`
- **Counseling Summary** — plain-language guidance for the clinician
- **Context-Aware Guidance** — vector search snippets when configured
- **Review Notes** — resource counts for audit

## Example artifacts

Pre-generated outputs are in `med_safety_io/` — each `*-case.json` file contains the input FHIR resources and the assistant's full output for that safety scenario.
