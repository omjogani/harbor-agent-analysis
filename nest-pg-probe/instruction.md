Write a complete Ansible playbook and Docker Compose setup that does the following:
1. Ansible — Install Docker

Write an Ansible playbook (setup.yml) targeting localhost
Install Docker Engine and Docker Compose plugin (for Ubuntu/Debian)
Ensure the Docker service is started and enabled
Add the current user to the docker group

2. Docker Compose — PostgreSQL + NestJS

Write a docker-compose.yml that defines two services: postgres and nestjs
Both should be on a shared custom Docker network (e.g., app-network)
PostgreSQL service:

Use the official postgres image
Set env vars: POSTGRES_USER, POSTGRES_PASSWORD, POSTGRES_DB
Persist data via a named volume


NestJS service:

Build from a local Dockerfile (provide a minimal working Dockerfile too)
Expose port 8080
Depend on the postgres service
Pass DB connection env vars so NestJS can connect to Postgres over the Docker network

3. NestJS App — /checkdb endpoint

Scaffold a minimal NestJS app (or provide the relevant controller + service code)
Add a GET /checkdb endpoint that:

Connects to PostgreSQL using the env vars provided
Runs SELECT 1 query
Returns the result as a JSON response


Use pg (node-postgres) or TypeORM's raw query — keep it simple

4. Deliverables expected:

setup.yml — Ansible playbook
docker-compose.yml
Dockerfile for NestJS
NestJS controller/service snippet for /checkdb
Any necessary inventory file or ansible.cfg

Constraints:

Target OS: Ubuntu 22.04
NestJS should not start until Postgres is healthy (use healthcheck + depends_on condition)
No Kubernetes, no cloud — purely local Docker setup