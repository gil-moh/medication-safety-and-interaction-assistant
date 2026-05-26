"""
Create focused Medication Safety test profiles and save input artifacts.

Profiles created:
- med-safe-dup-001: duplicate therapy signal
- med-safe-allergy-001: medication-allergy overlap signal
- med-safe-interaction-001: medication-medication interaction signal
- med-safe-food-001: medication-food counseling caution signal
- med-safe-population-preg-001: pregnancy contraindication signal
- med-safe-population-age-001: pediatric age contraindication signal
- med-safe-activity-001: driving/heavy-machinery caution signal with occupation context
- med-safe-blackbox-001: isotretinoin (Accutane) pregnancy black-box warning signal
- med-safe-condition-001: drug-condition warning signal
- med-safe-condition-002: drug-liver condition warning signal
- med-safe-condition-003: malabsorption + diarrhea-risk drug warning signal
- med-safe-mental-001: mental health condition + medication warning signal
- med-safe-family-001: family-history + medication warning signal
- med-safe-lab-001: medication + lab-threshold warning signal (low eGFR)
- med-safe-qt-001: QT-risk combination warning signal with low potassium context
- med-safe-anticholinergic-001: high anticholinergic burden scoring signal

Also writes input JSON files to:
    <repo-root>/med_safety_io/<patient-id>-input.json
"""

from __future__ import annotations

import json
from datetime import datetime
from pathlib import Path
from typing import Any

import requests

BASE_URL = "http://localhost:52773/fhir/r4"
AUTH = ("_SYSTEM", "SYS")

OUT_DIR = Path(__file__).resolve().parents[1] / "med_safety_io"
OUT_DIR.mkdir(parents=True, exist_ok=True)


def cc(system: str, code: str, display: str) -> dict[str, Any]:
    return {"coding": [{"system": system, "code": code, "display": display}], "text": display}


def tx_entry(resource: dict[str, Any]) -> dict[str, Any]:
    return {
        "resource": resource,
        "request": {"method": "PUT", "url": f"{resource['resourceType']}/{resource['id']}"},
    }


def build_profiles() -> dict[str, list[dict[str, Any]]]:
    profiles: dict[str, list[dict[str, Any]]] = {}

    p = "med-safe-dup-001"
    profiles[p] = [
        {
            "resourceType": "Patient",
            "id": p,
            "name": [{"use": "official", "family": "Shalev", "given": ["Eitan"]}],
            "gender": "male",
            "birthDate": "1972-03-19",
        },
        {
            "resourceType": "MedicationRequest",
            "id": "medrx-med-safe-dup-001-metformin-500",
            "subject": {"reference": f"Patient/{p}"},
            "status": "active",
            "intent": "order",
            "medicationCodeableConcept": cc(
                "http://www.nlm.nih.gov/research/umls/rxnorm", "860975", "Metformin 500 MG Oral Tablet"
            ),
            "authoredOn": "2026-05-15",
        },
        {
            "resourceType": "MedicationRequest",
            "id": "medrx-med-safe-dup-001-metformin-1000",
            "subject": {"reference": f"Patient/{p}"},
            "status": "active",
            "intent": "order",
            "medicationCodeableConcept": cc(
                "http://www.nlm.nih.gov/research/umls/rxnorm", "861007", "Metformin 1000 MG Oral Tablet"
            ),
            "authoredOn": "2026-05-18",
        },
        {
            "resourceType": "Condition",
            "id": "cond-med-safe-dup-001-dm2",
            "subject": {"reference": f"Patient/{p}"},
            "code": cc("http://snomed.info/sct", "44054006", "Type 2 diabetes mellitus"),
            "clinicalStatus": cc(
                "http://terminology.hl7.org/CodeSystem/condition-clinical", "active", "Active"
            ),
            "recordedDate": "2019-01-08",
        },
        {
            "resourceType": "Observation",
            "id": "obs-med-safe-dup-001-a1c",
            "status": "final",
            "code": cc("http://loinc.org", "4548-4", "Hemoglobin A1c/Hemoglobin.total in Blood"),
            "subject": {"reference": f"Patient/{p}"},
            "effectiveDateTime": "2026-05-20",
            "valueQuantity": {"value": 8.7, "unit": "%", "system": "http://unitsofmeasure.org", "code": "%"},
        },
    ]

    p = "med-safe-allergy-001"
    profiles[p] = [
        {
            "resourceType": "Patient",
            "id": p,
            "name": [{"use": "official", "family": "Naim", "given": ["Lior"]}],
            "gender": "female",
            "birthDate": "1988-12-02",
        },
        {
            "resourceType": "AllergyIntolerance",
            "id": "allergy-med-safe-allergy-001-amoxicillin",
            "patient": {"reference": f"Patient/{p}"},
            "code": cc("http://snomed.info/sct", "372687004", "Amoxicillin"),
            "clinicalStatus": cc(
                "http://terminology.hl7.org/CodeSystem/allergyintolerance-clinical", "active", "Active"
            ),
            "verificationStatus": cc(
                "http://terminology.hl7.org/CodeSystem/allergyintolerance-verification", "confirmed", "Confirmed"
            ),
            "criticality": "high",
            "reaction": [
                {
                    "manifestation": [cc("http://snomed.info/sct", "271807003", "Skin rash")],
                    "severity": "moderate",
                }
            ],
            "recordedDate": "2024-08-10",
        },
        {
            "resourceType": "MedicationRequest",
            "id": "medrx-med-safe-allergy-001-augmentin",
            "subject": {"reference": f"Patient/{p}"},
            "status": "active",
            "intent": "order",
            "medicationCodeableConcept": cc(
                "http://www.nlm.nih.gov/research/umls/rxnorm", "617425", "Amoxicillin and clavulanate potassium 875 MG / 125 MG Oral Tablet"
            ),
            "authoredOn": "2026-05-22",
        },
        {
            "resourceType": "Condition",
            "id": "cond-med-safe-allergy-001-sinus",
            "subject": {"reference": f"Patient/{p}"},
            "code": cc("http://snomed.info/sct", "36971009", "Acute sinusitis"),
            "clinicalStatus": cc(
                "http://terminology.hl7.org/CodeSystem/condition-clinical", "active", "Active"
            ),
            "recordedDate": "2026-05-21",
        },
    ]

    p = "med-safe-interaction-001"
    profiles[p] = [
        {
            "resourceType": "Patient",
            "id": p,
            "name": [{"use": "official", "family": "Dror", "given": ["Noam"]}],
            "gender": "male",
            "birthDate": "1959-09-13",
        },
        {
            "resourceType": "MedicationRequest",
            "id": "medrx-med-safe-interaction-001-warfarin",
            "subject": {"reference": f"Patient/{p}"},
            "status": "active",
            "intent": "order",
            "medicationCodeableConcept": cc(
                "http://www.nlm.nih.gov/research/umls/rxnorm", "855332", "Warfarin sodium 5 MG Oral Tablet"
            ),
            "authoredOn": "2026-05-14",
        },
        {
            "resourceType": "MedicationRequest",
            "id": "medrx-med-safe-interaction-001-aspirin",
            "subject": {"reference": f"Patient/{p}"},
            "status": "active",
            "intent": "order",
            "medicationCodeableConcept": cc(
                "http://www.nlm.nih.gov/research/umls/rxnorm", "1191", "Aspirin 81 MG Oral Tablet"
            ),
            "authoredOn": "2026-05-15",
        },
        {
            "resourceType": "Condition",
            "id": "cond-med-safe-interaction-001-af",
            "subject": {"reference": f"Patient/{p}"},
            "code": cc("http://snomed.info/sct", "49436004", "Atrial fibrillation"),
            "clinicalStatus": cc(
                "http://terminology.hl7.org/CodeSystem/condition-clinical", "active", "Active"
            ),
            "recordedDate": "2021-02-20",
        },
    ]

    p = "med-safe-food-001"
    profiles[p] = [
        {
            "resourceType": "Patient",
            "id": p,
            "name": [{"use": "official", "family": "Harari", "given": ["Maya"]}],
            "gender": "female",
            "birthDate": "1990-01-23",
        },
        {
            "resourceType": "MedicationRequest",
            "id": "medrx-med-safe-food-001-levothyroxine",
            "subject": {"reference": f"Patient/{p}"},
            "status": "active",
            "intent": "order",
            "medicationCodeableConcept": cc(
                "http://www.nlm.nih.gov/research/umls/rxnorm", "966251", "Levothyroxine sodium 50 MCG Oral Tablet"
            ),
            "authoredOn": "2026-05-20",
        },
        {
            "resourceType": "Condition",
            "id": "cond-med-safe-food-001-hypothyroidism",
            "subject": {"reference": f"Patient/{p}"},
            "code": cc("http://snomed.info/sct", "40930008", "Hypothyroidism"),
            "clinicalStatus": cc(
                "http://terminology.hl7.org/CodeSystem/condition-clinical", "active", "Active"
            ),
            "recordedDate": "2022-10-05",
        },
    ]

    p = "med-safe-population-preg-001"
    profiles[p] = [
        {
            "resourceType": "Patient",
            "id": p,
            "name": [{"use": "official", "family": "Cohen", "given": ["Yael"]}],
            "gender": "female",
            "birthDate": "1997-04-11",
        },
        {
            "resourceType": "MedicationRequest",
            "id": "medrx-med-safe-population-preg-001-valproate",
            "subject": {"reference": f"Patient/{p}"},
            "status": "active",
            "intent": "order",
            "medicationCodeableConcept": cc(
                "http://www.nlm.nih.gov/research/umls/rxnorm", "68439", "Valproate sodium 500 MG Oral Tablet"
            ),
            "authoredOn": "2026-05-21",
        },
        {
            "resourceType": "Condition",
            "id": "cond-med-safe-population-preg-001-pregnancy",
            "subject": {"reference": f"Patient/{p}"},
            "code": cc("http://snomed.info/sct", "77386006", "Pregnant"),
            "clinicalStatus": cc(
                "http://terminology.hl7.org/CodeSystem/condition-clinical", "active", "Active"
            ),
            "recordedDate": "2026-05-10",
        },
    ]

    p = "med-safe-population-age-001"
    profiles[p] = [
        {
            "resourceType": "Patient",
            "id": p,
            "name": [{"use": "official", "family": "Levi", "given": ["Omer"]}],
            "gender": "male",
            "birthDate": "2017-09-15",
        },
        {
            "resourceType": "MedicationRequest",
            "id": "medrx-med-safe-population-age-001-codeine",
            "subject": {"reference": f"Patient/{p}"},
            "status": "active",
            "intent": "order",
            "medicationCodeableConcept": cc(
                "http://www.nlm.nih.gov/research/umls/rxnorm", "2670", "Codeine phosphate 15 MG Oral Tablet"
            ),
            "authoredOn": "2026-05-22",
        },
        {
            "resourceType": "Condition",
            "id": "cond-med-safe-population-age-001-cough",
            "subject": {"reference": f"Patient/{p}"},
            "code": cc("http://snomed.info/sct", "49727002", "Cough"),
            "clinicalStatus": cc(
                "http://terminology.hl7.org/CodeSystem/condition-clinical", "active", "Active"
            ),
            "recordedDate": "2026-05-22",
        },
    ]

    p = "med-safe-activity-001"
    profiles[p] = [
        {
            "resourceType": "Patient",
            "id": p,
            "name": [{"use": "official", "family": "Koren", "given": ["Avi"]}],
            "gender": "male",
            "birthDate": "1986-07-02",
            "extension": [
                {
                    "url": "http://example.org/fhir/StructureDefinition/patient-occupation",
                    "valueString": "Forklift operator",
                }
            ],
        },
        {
            "resourceType": "MedicationRequest",
            "id": "medrx-med-safe-activity-001-diazepam",
            "subject": {"reference": f"Patient/{p}"},
            "status": "active",
            "intent": "order",
            "medicationCodeableConcept": cc(
                "http://www.nlm.nih.gov/research/umls/rxnorm", "3322", "Diazepam 5 MG Oral Tablet"
            ),
            "authoredOn": "2026-05-23",
        },
        {
            "resourceType": "Observation",
            "id": "obs-med-safe-activity-001-occupation",
            "status": "final",
            "category": [cc("http://terminology.hl7.org/CodeSystem/observation-category", "social-history", "Social History")],
            "code": cc("http://loinc.org", "11341-5", "History of Occupation"),
            "subject": {"reference": f"Patient/{p}"},
            "effectiveDateTime": "2026-05-23",
            "valueString": "Forklift operator",
        },
    ]

    p = "med-safe-blackbox-001"
    profiles[p] = [
        {
            "resourceType": "Patient",
            "id": p,
            "name": [{"use": "official", "family": "Bar", "given": ["Dana"]}],
            "gender": "female",
            "birthDate": "1998-05-06",
        },
        {
            "resourceType": "MedicationRequest",
            "id": "medrx-med-safe-blackbox-001-isotretinoin",
            "subject": {"reference": f"Patient/{p}"},
            "status": "active",
            "intent": "order",
            "medicationCodeableConcept": cc(
                "http://www.nlm.nih.gov/research/umls/rxnorm", "76390", "Isotretinoin 20 MG Oral Capsule"
            ),
            "authoredOn": "2026-05-24",
        },
        {
            "resourceType": "Condition",
            "id": "cond-med-safe-blackbox-001-pregnancy",
            "subject": {"reference": f"Patient/{p}"},
            "code": cc("http://snomed.info/sct", "77386006", "Pregnant"),
            "clinicalStatus": cc(
                "http://terminology.hl7.org/CodeSystem/condition-clinical", "active", "Active"
            ),
            "recordedDate": "2026-05-20",
        },
    ]

    p = "med-safe-condition-001"
    profiles[p] = [
        {
            "resourceType": "Patient",
            "id": p,
            "name": [{"use": "official", "family": "Arad", "given": ["Matan"]}],
            "gender": "male",
            "birthDate": "1971-11-09",
        },
        {
            "resourceType": "MedicationRequest",
            "id": "medrx-med-safe-condition-001-ibuprofen",
            "subject": {"reference": f"Patient/{p}"},
            "status": "active",
            "intent": "order",
            "medicationCodeableConcept": cc(
                "http://www.nlm.nih.gov/research/umls/rxnorm", "5640", "Ibuprofen 400 MG Oral Tablet"
            ),
            "authoredOn": "2026-05-24",
        },
        {
            "resourceType": "Condition",
            "id": "cond-med-safe-condition-001-ckd",
            "subject": {"reference": f"Patient/{p}"},
            "code": cc("http://snomed.info/sct", "709044004", "Chronic kidney disease stage 3"),
            "clinicalStatus": cc(
                "http://terminology.hl7.org/CodeSystem/condition-clinical", "active", "Active"
            ),
            "recordedDate": "2025-10-12",
        },
    ]

    p = "med-safe-condition-002"
    profiles[p] = [
        {
            "resourceType": "Patient",
            "id": p,
            "name": [{"use": "official", "family": "Halevi", "given": ["Roni"]}],
            "gender": "female",
            "birthDate": "1979-03-12",
        },
        {
            "resourceType": "MedicationRequest",
            "id": "medrx-med-safe-condition-002-methotrexate",
            "subject": {"reference": f"Patient/{p}"},
            "status": "active",
            "intent": "order",
            "medicationCodeableConcept": cc(
                "http://www.nlm.nih.gov/research/umls/rxnorm", "6851", "Methotrexate 2.5 MG Oral Tablet"
            ),
            "authoredOn": "2026-05-24",
        },
        {
            "resourceType": "Condition",
            "id": "cond-med-safe-condition-002-liver",
            "subject": {"reference": f"Patient/{p}"},
            "code": cc("http://snomed.info/sct", "128302006", "Chronic liver disease"),
            "clinicalStatus": cc(
                "http://terminology.hl7.org/CodeSystem/condition-clinical", "active", "Active"
            ),
            "recordedDate": "2024-11-08",
        },
    ]

    p = "med-safe-condition-003"
    profiles[p] = [
        {
            "resourceType": "Patient",
            "id": p,
            "name": [{"use": "official", "family": "Benari", "given": ["Tal"]}],
            "gender": "male",
            "birthDate": "1984-08-27",
        },
        {
            "resourceType": "MedicationRequest",
            "id": "medrx-med-safe-condition-003-orlistat",
            "subject": {"reference": f"Patient/{p}"},
            "status": "active",
            "intent": "order",
            "medicationCodeableConcept": cc(
                "http://www.nlm.nih.gov/research/umls/rxnorm", "47660", "Orlistat 120 MG Oral Capsule"
            ),
            "authoredOn": "2026-05-24",
        },
        {
            "resourceType": "Condition",
            "id": "cond-med-safe-condition-003-malabsorption",
            "subject": {"reference": f"Patient/{p}"},
            "code": cc("http://snomed.info/sct", "32230006", "Intestinal malabsorption syndrome"),
            "clinicalStatus": cc(
                "http://terminology.hl7.org/CodeSystem/condition-clinical", "active", "Active"
            ),
            "recordedDate": "2025-06-01",
        },
    ]

    p = "med-safe-mental-001"
    profiles[p] = [
        {
            "resourceType": "Patient",
            "id": p,
            "name": [{"use": "official", "family": "Gal", "given": ["Neta"]}],
            "gender": "female",
            "birthDate": "1992-02-18",
        },
        {
            "resourceType": "MedicationRequest",
            "id": "medrx-med-safe-mental-001-prednisone",
            "subject": {"reference": f"Patient/{p}"},
            "status": "active",
            "intent": "order",
            "medicationCodeableConcept": cc(
                "http://www.nlm.nih.gov/research/umls/rxnorm", "8640", "Prednisone 20 MG Oral Tablet"
            ),
            "authoredOn": "2026-05-24",
        },
        {
            "resourceType": "Condition",
            "id": "cond-med-safe-mental-001-bipolar",
            "subject": {"reference": f"Patient/{p}"},
            "code": cc("http://snomed.info/sct", "13746004", "Bipolar disorder"),
            "clinicalStatus": cc(
                "http://terminology.hl7.org/CodeSystem/condition-clinical", "active", "Active"
            ),
            "recordedDate": "2021-03-14",
        },
    ]

    p = "med-safe-family-001"
    profiles[p] = [
        {
            "resourceType": "Patient",
            "id": p,
            "name": [{"use": "official", "family": "Mor", "given": ["Eli"]}],
            "gender": "male",
            "birthDate": "1987-01-30",
        },
        {
            "resourceType": "MedicationRequest",
            "id": "medrx-med-safe-family-001-oxycodone",
            "subject": {"reference": f"Patient/{p}"},
            "status": "active",
            "intent": "order",
            "medicationCodeableConcept": cc(
                "http://www.nlm.nih.gov/research/umls/rxnorm", "7804", "Oxycodone hydrochloride 5 MG Oral Tablet"
            ),
            "authoredOn": "2026-05-24",
        },
        {
            "resourceType": "FamilyMemberHistory",
            "id": "fh-med-safe-family-001-father-sud",
            "status": "completed",
            "patient": {"reference": f"Patient/{p}"},
            "relationship": cc("http://terminology.hl7.org/CodeSystem/v3-RoleCode", "FTH", "father"),
            "condition": [
                {
                    "code": cc("http://snomed.info/sct", "191816009", "Family history of psychoactive substance abuse")
                }
            ],
        },
    ]

    p = "med-safe-lab-001"
    profiles[p] = [
        {
            "resourceType": "Patient",
            "id": p,
            "name": [{"use": "official", "family": "Lavi", "given": ["Shai"]}],
            "gender": "male",
            "birthDate": "1968-10-14",
        },
        {
            "resourceType": "MedicationRequest",
            "id": "medrx-med-safe-lab-001-ibuprofen",
            "subject": {"reference": f"Patient/{p}"},
            "status": "active",
            "intent": "order",
            "medicationCodeableConcept": cc(
                "http://www.nlm.nih.gov/research/umls/rxnorm", "5640", "Ibuprofen 400 MG Oral Tablet"
            ),
            "authoredOn": "2025-10-01",
        },
        {
            "resourceType": "Observation",
            "id": "obs-med-safe-lab-001-egfr",
            "status": "final",
            "code": cc("http://loinc.org", "33914-3", "Glomerular filtration rate/1.73 sq M.predicted [Volume Rate/Area] in Serum or Plasma by Creatinine-based formula (MDRD)"),
            "subject": {"reference": f"Patient/{p}"},
            "effectiveDateTime": "2026-05-20",
            "valueQuantity": {
                "value": 24,
                "unit": "mL/min/1.73m2",
                "system": "http://unitsofmeasure.org",
                "code": "mL/min/{1.73_m2}",
            },
        },
    ]

    p = "med-safe-qt-001"
    profiles[p] = [
        {
            "resourceType": "Patient",
            "id": p,
            "name": [{"use": "official", "family": "Peleg", "given": ["Nir"]}],
            "gender": "male",
            "birthDate": "1976-03-22",
        },
        {
            "resourceType": "MedicationRequest",
            "id": "medrx-med-safe-qt-001-citalopram",
            "subject": {"reference": f"Patient/{p}"},
            "status": "active",
            "intent": "order",
            "medicationCodeableConcept": cc(
                "http://www.nlm.nih.gov/research/umls/rxnorm", "2556", "Citalopram 20 MG Oral Tablet"
            ),
            "authoredOn": "2026-05-22",
        },
        {
            "resourceType": "MedicationRequest",
            "id": "medrx-med-safe-qt-001-haloperidol",
            "subject": {"reference": f"Patient/{p}"},
            "status": "active",
            "intent": "order",
            "medicationCodeableConcept": cc(
                "http://www.nlm.nih.gov/research/umls/rxnorm", "5093", "Haloperidol 2 MG Oral Tablet"
            ),
            "authoredOn": "2026-05-22",
        },
        {
            "resourceType": "Observation",
            "id": "obs-med-safe-qt-001-potassium",
            "status": "final",
            "code": cc("http://loinc.org", "2823-3", "Potassium [Moles/volume] in Serum or Plasma"),
            "subject": {"reference": f"Patient/{p}"},
            "effectiveDateTime": "2026-05-23",
            "valueQuantity": {
                "value": 3.1,
                "unit": "mmol/L",
                "system": "http://unitsofmeasure.org",
                "code": "mmol/L",
            },
        },
    ]

    p = "med-safe-anticholinergic-001"
    profiles[p] = [
        {
            "resourceType": "Patient",
            "id": p,
            "name": [{"use": "official", "family": "Sharir", "given": ["Erez"]}],
            "gender": "male",
            "birthDate": "1954-09-17",
        },
        {
            "resourceType": "MedicationRequest",
            "id": "medrx-med-safe-anticholinergic-001-diphenhydramine",
            "subject": {"reference": f"Patient/{p}"},
            "status": "active",
            "intent": "order",
            "medicationCodeableConcept": cc(
                "http://www.nlm.nih.gov/research/umls/rxnorm", "3498", "Diphenhydramine 25 MG Oral Capsule"
            ),
            "authoredOn": "2026-05-21",
        },
        {
            "resourceType": "MedicationRequest",
            "id": "medrx-med-safe-anticholinergic-001-oxybutynin",
            "subject": {"reference": f"Patient/{p}"},
            "status": "active",
            "intent": "order",
            "medicationCodeableConcept": cc(
                "http://www.nlm.nih.gov/research/umls/rxnorm", "32675", "Oxybutynin chloride 5 MG Oral Tablet"
            ),
            "authoredOn": "2026-05-21",
        },
        {
            "resourceType": "MedicationRequest",
            "id": "medrx-med-safe-anticholinergic-001-amitriptyline",
            "subject": {"reference": f"Patient/{p}"},
            "status": "active",
            "intent": "order",
            "medicationCodeableConcept": cc(
                "http://www.nlm.nih.gov/research/umls/rxnorm", "704", "Amitriptyline hydrochloride 25 MG Oral Tablet"
            ),
            "authoredOn": "2026-05-21",
        },
    ]

    return profiles


def send_transaction(resources: list[dict[str, Any]]) -> tuple[bool, str]:
    bundle = {
        "resourceType": "Bundle",
        "type": "transaction",
        "entry": [tx_entry(r) for r in resources],
    }
    s = requests.Session()
    s.auth = AUTH
    s.headers.update({"Content-Type": "application/fhir+json", "Accept": "application/fhir+json"})
    r = s.post(BASE_URL, json=bundle, timeout=120)
    if r.status_code not in (200, 201):
        return False, f"HTTP {r.status_code}: {r.text[:250]}"
    return True, "OK"


def main() -> int:
    print(f"[{datetime.now().isoformat(timespec='seconds')}] Creating medication safety profiles")
    profiles = build_profiles()
    failed = False

    for patient_id, resources in profiles.items():
        input_path = OUT_DIR / f"{patient_id}-input.json"
        with input_path.open("w", encoding="utf-8") as f:
            json.dump(resources, f, indent=2)

        ok, msg = send_transaction(resources)
        print(f"- {patient_id}: {'OK' if ok else 'FAIL'} ({len(resources)} resources) {msg}")
        print(f"  input: {input_path}")
        if not ok:
            failed = True

    print("Done.")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
