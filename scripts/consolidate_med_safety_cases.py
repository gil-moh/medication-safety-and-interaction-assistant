from __future__ import annotations

import json
from datetime import datetime
from pathlib import Path

IO_DIR = Path(__file__).resolve().parents[1] / "med_safety_io"


def patient_id_from_name(name: str) -> str:
    if name.endswith("-input.json"):
        return name[: -len("-input.json")]
    if name.endswith("-output.txt"):
        return name[: -len("-output.txt")]
    return name


def build_case_file(patient_id: str, input_path: Path, output_path: Path) -> Path:
    with input_path.open("r", encoding="utf-8") as f:
        input_resources = json.load(f)

    with output_path.open("r", encoding="utf-8") as f:
        output_text = f.read()

    case_obj = {
        "patientId": patient_id,
        "generatedAt": datetime.now().isoformat(timespec="seconds"),
        "inputResources": input_resources,
        "assistantOutput": output_text,
        "sourceFiles": {
            "input": input_path.name,
            "output": output_path.name,
        },
    }

    case_path = IO_DIR / f"{patient_id}-case.json"
    with case_path.open("w", encoding="utf-8") as f:
        json.dump(case_obj, f, indent=2)

    return case_path


def main() -> int:
    input_files = sorted(IO_DIR.glob("*-input.json"))
    output_files = sorted(IO_DIR.glob("*-output.txt"))

    output_map = {patient_id_from_name(p.name): p for p in output_files}

    merged = 0
    skipped = 0

    for in_file in input_files:
        patient_id = patient_id_from_name(in_file.name)
        out_file = output_map.get(patient_id)
        if out_file is None:
            print(f"SKIP {patient_id}: missing output file")
            skipped += 1
            continue

        case_path = build_case_file(patient_id, in_file, out_file)

        # Keep exactly one artifact per patient by removing split files.
        in_file.unlink(missing_ok=True)
        out_file.unlink(missing_ok=True)

        print(f"OK   {patient_id}: {case_path}")
        merged += 1

    print(f"Done. merged={merged} skipped={skipped}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
