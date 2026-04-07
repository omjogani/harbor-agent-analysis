#!/bin/bash
set -e

if ! command -v ansible-playbook &> /dev/null; then
    echo "========================================="
    echo " Installing Ansible"
    echo "========================================="
    apt-get update -qq
    apt-get install -y -qq ansible curl > /dev/null
fi

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)/nest-pg-stack"

echo "========================================="
echo " Creating project in: $PROJECT_DIR"
echo "========================================="
rm -rf "$PROJECT_DIR"
mkdir -p "$PROJECT_DIR/nestjs-app/src"

cat > "$PROJECT_DIR/.env" << 'EOF'
POSTGRES_USER=appuser
POSTGRES_PASSWORD=apppassword
POSTGRES_DB=appdb
POSTGRES_HOST=postgres
POSTGRES_PORT=5432
EOF

# --- ansible.cfg ---
cat > "$PROJECT_DIR/ansible.cfg" << 'EOF'
[defaults]
inventory = inventory
host_key_checking = False
EOF

# --- inventory ---
cat > "$PROJECT_DIR/inventory" << 'EOF'
[local]
localhost ansible_connection=local
EOF

# --- setup.yml ---
cat > "$PROJECT_DIR/setup.yml" << 'YAML'
---
- name: Install Docker on Ubuntu
  hosts: local
  become: true
  tasks:
    - name: Install prerequisite packages
      apt:
        name:
          - ca-certificates
          - curl
          - gnupg
          - lsb-release
        state: present
        update_cache: true

    - name: Create keyrings directory
      file:
        path: /etc/apt/keyrings
        state: directory
        mode: "0755"

    - name: Add Docker GPG key
      shell: |
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
      args:
        creates: /etc/apt/keyrings/docker.gpg

    - name: Add Docker repository
      apt_repository:
        repo: >-
          deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.gpg]
          https://download.docker.com/linux/ubuntu
          {{ ansible_distribution_release }} stable
        state: present
        filename: docker

    - name: Install Docker Engine and Compose plugin
      apt:
        name:
          - docker-ce
          - docker-ce-cli
          - containerd.io
          - docker-buildx-plugin
          - docker-compose-plugin
        state: present
        update_cache: true

    - name: Start Docker daemon (non-systemd)
      shell: |
        dockerd &
        sleep 3
      args:
        executable: /bin/bash

    - name: Add current user to docker group
      user:
        name: "{{ ansible_env.SUDO_USER | default(ansible_user_id) }}"
        groups: docker
        append: true
YAML

# --- docker-compose.yml ---
cat > "$PROJECT_DIR/docker-compose.yml" << 'EOF'
services:
  postgres:
    image: postgres:16-alpine
    container_name: app-postgres
    env_file: .env
    ports:
      - "5432:5432"
    volumes:
      - pgdata:/var/lib/postgresql/data
    networks:
      - app-network
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U $POSTGRES_USER -d $POSTGRES_DB"]
      interval: 5s
      timeout: 5s
      retries: 5

  nestjs:
    build:
      context: ./nestjs-app
      dockerfile: Dockerfile
    container_name: app-nestjs
    ports:
      - "8080:8080"
    env_file: .env
    depends_on:
      postgres:
        condition: service_healthy
    networks:
      - app-network

volumes:
  pgdata:

networks:
  app-network:
    driver: bridge
EOF

# --- Dockerfile ---
cat > "$PROJECT_DIR/nestjs-app/Dockerfile" << 'EOF'
FROM node:20-alpine AS build

WORKDIR /app

COPY package.json package-lock.json* ./
RUN npm install

COPY tsconfig.json ./
COPY src ./src
RUN npm run build

FROM node:20-alpine

WORKDIR /app

COPY --from=build /app/dist ./dist
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/package.json ./

EXPOSE 8080

CMD ["node", "dist/main.js"]
EOF

# --- package.json ---
cat > "$PROJECT_DIR/nestjs-app/package.json" << 'EOF'
{
  "name": "nestjs-app",
  "version": "1.0.0",
  "scripts": {
    "build": "nest build",
    "start": "nest start",
    "start:dev": "nest start --watch"
  },
  "dependencies": {
    "@nestjs/common": "^10.0.0",
    "@nestjs/core": "^10.0.0",
    "@nestjs/platform-express": "^10.0.0",
    "pg": "^8.13.0",
    "reflect-metadata": "^0.2.0",
    "rxjs": "^7.8.0"
  },
  "devDependencies": {
    "@nestjs/cli": "^10.0.0",
    "@nestjs/schematics": "^10.0.0",
    "typescript": "^5.0.0",
    "@types/node": "^20.0.0"
  }
}
EOF

# --- tsconfig.json ---
cat > "$PROJECT_DIR/nestjs-app/tsconfig.json" << 'EOF'
{
  "compilerOptions": {
    "module": "commonjs",
    "declaration": true,
    "removeComments": true,
    "emitDecoratorMetadata": true,
    "experimentalDecorators": true,
    "allowSyntheticDefaultImports": true,
    "target": "ES2021",
    "sourceMap": true,
    "outDir": "./dist",
    "rootDir": "./src",
    "baseUrl": "./",
    "incremental": true,
    "skipLibCheck": true,
    "strictNullChecks": false,
    "noImplicitAny": false,
    "strictBindCallApply": false,
    "forceConsistentCasingInFileNames": false,
    "noFallthroughCasesInSwitch": false
  }
}
EOF

# --- main.ts ---
cat > "$PROJECT_DIR/nestjs-app/src/main.ts" << 'EOF'
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  await app.listen(8080);
  console.log('NestJS app listening on port 8080');
}
bootstrap();
EOF

# --- app.module.ts ---
cat > "$PROJECT_DIR/nestjs-app/src/app.module.ts" << 'EOF'
import { Module } from '@nestjs/common';
import { AppController } from './app.controller';
import { AppService } from './app.service';

@Module({
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}
EOF

# --- app.controller.ts ---
cat > "$PROJECT_DIR/nestjs-app/src/app.controller.ts" << 'EOF'
import { Controller, Get } from '@nestjs/common';
import { AppService } from './app.service';

@Controller()
export class AppController {
  constructor(private readonly appService: AppService) {}

  @Get('checkdb')
  async checkDb() {
    return this.appService.checkDb();
  }
}
EOF

# --- app.service.ts ---
cat > "$PROJECT_DIR/nestjs-app/src/app.service.ts" << 'EOF'
import { Injectable } from '@nestjs/common';
import { Pool } from 'pg';

@Injectable()
export class AppService {
  private pool: Pool;

  constructor() {
    this.pool = new Pool({
      host: process.env.POSTGRES_HOST,
      port: parseInt(process.env.POSTGRES_PORT, 10) || 5432,
      user: process.env.POSTGRES_USER,
      password: process.env.POSTGRES_PASSWORD,
      database: process.env.POSTGRES_DB,
    });
  }

  async checkDb() {
    const result = await this.pool.query('SELECT 1 AS status');
    return {
      connected: true,
      result: result.rows,
    };
  }
}
EOF

echo "All files generated."


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
echo "Waiting for Docker daemon..."
for i in $(seq 1 30); do
    if docker info > /dev/null 2>&1; then
        echo "Docker daemon is ready!"
        break
    fi
    if [ "$i" -eq 30 ]; then
        echo "Timed out waiting for Docker daemon."
        exit 1
    fi
    sleep 2
done


echo ""
echo "========================================="
echo " Step 2: Build and start Docker Compose"
echo "========================================="
docker compose up --build -d


echo ""
echo "========================================="
echo " Step 3: Wait for services to be healthy"
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
echo " Step 4: Verify /checkdb endpoint"
echo "========================================="
echo "GET http://localhost:8080/checkdb"
curl -s http://localhost:8080/checkdb | python3 -m json.tool


echo ""
echo "========================================="
echo " Step 5: Verify Docker containers"
echo "========================================="
docker ps --filter "name=app-postgres" --filter "name=app-nestjs" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "========================================="
echo " Done! Stack is running."
echo "========================================="