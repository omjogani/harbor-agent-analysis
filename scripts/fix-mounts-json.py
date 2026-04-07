#!/usr/bin/env python3
"""Fix mounts_json entries in harbor job configs.

Harbor's CLI serializes docker mounts as strings (e.g. "/var/run/docker.sock:/var/run/docker.sock")
but the viewer expects ServiceVolumeConfig objects with type, source, and target fields.
This script converts all string entries to the correct object format.
"""

import json
import sys
from pathlib import Path


def fix_mounts(mounts: list) -> list | None:
    """Convert string mount entries to ServiceVolumeConfig objects. Returns None if no fix needed."""
    if not any(isinstance(m, str) for m in mounts):
        return None
    new_mounts = []
    for m in mounts:
        if isinstance(m, str):
            parts = m.split(":")
            source, target = parts[0], parts[1] if len(parts) > 1 else parts[0]
            new_mounts.append({"type": "bind", "source": source, "target": target})
        else:
            new_mounts.append(m)
    return new_mounts


def process_file(path: Path, env_path: list[str]) -> bool:
    """Fix mounts_json in a JSON file. env_path is the key path to the environment object."""
    data = json.loads(path.read_text())
    obj = data
    for key in env_path:
        obj = obj.get(key, {})
    mounts = obj.get("mounts_json")
    if not isinstance(mounts, list):
        return False
    fixed = fix_mounts(mounts)
    if fixed is None:
        return False
    obj["mounts_json"] = fixed
    path.write_text(json.dumps(data, indent=4) + "\n")
    return True


def main():
    jobs_dir = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("../jobs")
    if not jobs_dir.is_dir():
        print(f"Error: {jobs_dir} is not a directory", file=sys.stderr)
        sys.exit(1)

    fixed = 0

    # Fix config.json files (job-level and trial-level)
    for config_path in sorted(jobs_dir.glob("**/config.json")):
        if process_file(config_path, ["environment"]):
            print(f"  Fixed {config_path.relative_to(jobs_dir)}")
            fixed += 1

    # Fix result.json files (trial results have mounts at config.environment)
    for result_path in sorted(jobs_dir.glob("**/result.json")):
        if process_file(result_path, ["config", "environment"]):
            print(f"  Fixed {result_path.relative_to(jobs_dir)}")
            fixed += 1

    print(f"\nFixed {fixed} files total.")


if __name__ == "__main__":
    main()