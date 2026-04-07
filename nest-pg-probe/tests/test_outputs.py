import subprocess


def test_checkdb_endpoint():
    result = subprocess.run(["bash", "/tests/verify.sh"], capture_output=True, text=True)
    assert "TEST PASSED" in result.stdout, "Did not pass test"


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