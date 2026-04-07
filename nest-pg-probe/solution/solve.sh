#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR/nest-pg-stack"

if ! command -v ansible-playbook &> /dev/null; then
    echo "========================================="
    echo " Installing Ansible"
    echo "========================================="
    apt-get update -qq
    apt-get install -y -qq ansible curl socat iproute2 > /dev/null
fi

echo "========================================="
echo " Creating project in: $PROJECT_DIR"
echo "========================================="
rm -rf "$PROJECT_DIR"
mkdir -p "$PROJECT_DIR/nestjs-app/src"

cp "$SCRIPT_DIR/.env" "$PROJECT_DIR/.env"
cp "$SCRIPT_DIR/docker-compose.yml" "$PROJECT_DIR/docker-compose.yml"
cp "$SCRIPT_DIR/ansible/ansible.cfg" "$PROJECT_DIR/ansible.cfg"
cp "$SCRIPT_DIR/ansible/inventory" "$PROJECT_DIR/inventory"
cp "$SCRIPT_DIR/ansible/setup.yml" "$PROJECT_DIR/setup.yml"
cp "$SCRIPT_DIR/nestjs-app/Dockerfile" "$PROJECT_DIR/nestjs-app/Dockerfile"
cp "$SCRIPT_DIR/nestjs-app/package.json" "$PROJECT_DIR/nestjs-app/package.json"
cp "$SCRIPT_DIR/nestjs-app/tsconfig.json" "$PROJECT_DIR/nestjs-app/tsconfig.json"
cp "$SCRIPT_DIR/nestjs-app/src/main.ts" "$PROJECT_DIR/nestjs-app/src/main.ts"
cp "$SCRIPT_DIR/nestjs-app/src/app.module.ts" "$PROJECT_DIR/nestjs-app/src/app.module.ts"
cp "$SCRIPT_DIR/nestjs-app/src/app.controller.ts" "$PROJECT_DIR/nestjs-app/src/app.controller.ts"
cp "$SCRIPT_DIR/nestjs-app/src/app.service.ts" "$PROJECT_DIR/nestjs-app/src/app.service.ts"

echo "All files copied."

echo ""
echo "========================================="
echo " Step 1: Install Docker via Ansible"
echo "========================================="
cd "$PROJECT_DIR"
if [ "$(id -u)" -eq 0 ]; then
    ansible-playbook setup.yml
else
    ansible-playbook setup.yml --ask-become-pass
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

socat TCP-LISTEN:8080,fork,reuseaddr TCP:$DOCKER_HOST_IP:8080 &
socat TCP-LISTEN:5432,fork,reuseaddr TCP:$DOCKER_HOST_IP:5432 &
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