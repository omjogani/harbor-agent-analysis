#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if ! command -v ansible-playbook &> /dev/null; then
    echo "========================================="
    echo " Installing Ansible"
    echo "========================================="
    apt-get update -qq
    apt-get install -y -qq ansible curl socat iproute2 > /dev/null
fi

echo ""
echo "========================================="
echo " Step 1: Install Docker via Ansible"
echo "========================================="
cd "$SCRIPT_DIR"
if [ "$(id -u)" -eq 0 ]; then
    ANSIBLE_CONFIG="$SCRIPT_DIR/ansible/ansible.cfg" ansible-playbook "$SCRIPT_DIR/ansible/setup.yml"
else
    ANSIBLE_CONFIG="$SCRIPT_DIR/ansible/ansible.cfg" ansible-playbook "$SCRIPT_DIR/ansible/setup.yml" --ask-become-pass
fi

echo ""
echo "========================================="
echo " Step 2: Build and start Docker Compose"
echo "========================================="
docker compose up --build -d

echo ""
echo "========================================="
echo " Step 3: Set up port forwarding"
echo "========================================="
DOCKER_HOST_IP=$(ip route | grep default | awk '{print $3}')
echo "Docker host IP: $DOCKER_HOST_IP"

socat TCP-LISTEN:8080,fork,reuseaddr "TCP:$DOCKER_HOST_IP:8080" &
socat TCP-LISTEN:5432,fork,reuseaddr "TCP:$DOCKER_HOST_IP:5432" &
sleep 1

echo ""
echo "========================================="
echo " Step 4: Wait for services to be healthy"
echo "========================================="
echo "Waiting for NestJS to be ready..."
for i in $(seq 1 30); do
    if curl -s http://localhost:8080/checkdb > /dev/null 2>&1; then
        echo "Services are up!"
        break
    fi
    if [ "$i" -eq 30 ]; then
        echo "Timed out waiting for services."
        docker compose logs
        exit 1
    fi
    sleep 2
done

echo ""
echo "========================================="
echo " Step 5: Verify /checkdb endpoint"
echo "========================================="
echo "GET http://localhost:8080/checkdb"
curl -s http://localhost:8080/checkdb | python3 -m json.tool

echo ""
echo "========================================="
echo " Step 6: Verify Docker containers"
echo "========================================="
docker ps --filter "name=app-postgres" --filter "name=app-nestjs" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "========================================="
echo " Done! Stack is running."
echo "========================================="