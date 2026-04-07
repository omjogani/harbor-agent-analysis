import subprocess
import requests


def get_base_urls():
    return [
        "http://localhost:8080",
        "http://host.docker.internal:8080",
    ]


def test_checkdb_endpoint():
    # retry across endpoints + time to allow service readiness
    for _ in range(30):
        for base in get_base_urls():
            try:
                r = requests.get(f"{base}/checkdb", timeout=2)
                if r.status_code != 200:
                    continue
                data = r.json()
                # Normalize response instead of branching everywhere
                if isinstance(data, list):
                    assert data and list(data[0].values())[0] == 1
                    return
                if isinstance(data, dict):
                    assert data.get("connected") is True
                    result = data.get("result")
                    assert (
                            isinstance(result, list)
                            and result
                            and list(result[0].values())[0] == 1
                    )
                    return
            except Exception:
                pass
        import time

        time.sleep(2)
    raise AssertionError("checkdb endpoint not reachable or invalid response")


def test_docker_containers_running():
    result = subprocess.run(
        ["docker", "ps", "--format", "{{.Names}}"],
        capture_output=True,
        text=True,
    )
    containers = result.stdout.strip().splitlines()
    assert "app-postgres" in containers
    assert "app-nestjs" in containers


def test_exposed_ports():
    result = subprocess.run(
        ["docker", "ps", "--format", "{{.Names}} {{.Ports}}"],
        capture_output=True,
        text=True,
    )
    lines = result.stdout.strip().splitlines()
    port_map = {}
    for line in lines:
        parts = line.split(" ", 1)
        if len(parts) == 2:
            port_map[parts[0]] = parts[1]

    assert "app-postgres" in port_map
    assert "5432" in port_map["app-postgres"]

    assert "app-nestjs" in port_map
    assert "8080" in port_map["app-nestjs"]
