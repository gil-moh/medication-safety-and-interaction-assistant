# Medication Safety and Interaction Assistant

Contest submission for InterSystems Programming Contest: AI Agents for FHIR.

## Repository

- GitHub/GitLab URL: use this repository root URL in the submission form
- License: see LICENSE

## Team

- Team lead: Gil Tavassy (InterSystems Developer Community profile: https://community.intersystems.com/user/gil-tavassy)
- LinkedIn: https://www.linkedin.com/in/gil-tavassy-5703b311b

Submission mode: solo project.

## What This App Does

Given FHIR patient context, the assistant produces:

- Strict warnings first, then conservative warnings with extra context
- Explainable findings with explicit reasoning text
- Interaction, allergy, black-box/population, lab-threshold, QT-risk, and anticholinergic burden findings
- Structured recommended actions with urgency SLA (actionType, priority, slaHours, sourceRisk)

## Main Implementation

- objectscript/cls/Sample/AI/Tools/MedicationSafetyReadOnly.cls
- objectscript/cls/Sample/AI/Examples/MedicationSafetyAssistant.cls
- scripts/create_medication_safety_profiles.py
- scripts/consolidate_med_safety_cases.py
- med_safety_io/*-case.json

## Quick Runbook

1. Start InterSystems IRIS / IRIS for Health CE with FHIR endpoint available.
2. Compile ObjectScript classes in your IRIS instance.
3. Generate and post synthetic profiles:

```bash
python scripts/create_medication_safety_profiles.py
```

4. Run assistant per generated patient profile in IRIS.
5. Consolidate input/output into single per-patient artifacts:

```bash
python scripts/consolidate_med_safety_cases.py
```

6. Review outputs under med_safety_io/.

## Demo

- Option A: add a video link with a short walk-through of setup, run, and outputs.
- Option B: use this README as detailed written walk-through.

## Example Artifacts

- med_safety_io/med-safe-interaction-001-case.json
- med_safety_io/med-safe-lab-001-case.json
- med_safety_io/med-safe-qt-001-case.json
- med_safety_io/med-safe-anticholinergic-001-case.json
