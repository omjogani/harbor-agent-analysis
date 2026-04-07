Use Ansible to install Docker. After installation, use Ansible to bring up a Docker Compose stack with two services — Postgres (latest) and a NestJS app.

## Container requirements

- The Postgres container may be named `app-postgres` and expose default port.
- The NestJS container may be named `app-nestjs` and expose default port.
- The Compose setup must ensure NestJS only starts after Postgres is healthy.

## NestJS app requirements

The NestJS app should be minimal enough to expose a `GET /checkdb` endpoint that:

1. Runs a `SELECT 1` query against Postgres.
2. Returns the query result as JSON.

## Verification

End with a `curl` to `http://localhost:8080/checkdb` to verify the endpoint works.