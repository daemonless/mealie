# Mealie

Self-hosted recipe manager and meal planner on FreeBSD.

| | |
|---|---|
| **Port** | 9000 |
| **Registry** | `ghcr.io/daemonless/mealie` |
| **Source** | [https://github.com/mealie-recipes/mealie](https://github.com/mealie-recipes/mealie) |
| **Website** | [https://mealie.io/](https://mealie.io/) |

## Deployment

### Podman Compose

```yaml
services:
  mealie:
    image: ghcr.io/daemonless/mealie:latest
    container_name: mealie
    environment:
      - BASE_URL=http://localhost:9000
      - PUID=1000
      - PGID=1000
      - TZ=UTC
    volumes:
      - /path/to/containers/mealie:/config
    ports:
      - 9000:9000
    restart: unless-stopped
```

### Podman CLI

```bash
podman run -d --name mealie \
  -p 9000:9000 \
  -e BASE_URL=http://localhost:9000 \
  -e PUID=@PUID@ \
  -e PGID=@PGID@ \
  -e TZ=@TZ@ \
  -v /path/to/containers/mealie:/config \ 
  ghcr.io/daemonless/mealie:latest
```
Access at: `http://localhost:9000`

### Ansible

```yaml
- name: Deploy mealie
  containers.podman.podman_container:
    name: mealie
    image: ghcr.io/daemonless/mealie:latest
    state: started
    restart_policy: always
    env:
      BASE_URL: "http://localhost:9000"
      PUID: "1000"
      PGID: "1000"
      TZ: "UTC"
    ports:
      - "9000:9000"
    volumes:
      - "/path/to/containers/mealie:/config"
```

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `BASE_URL` | `http://localhost:9000` | The base URL for the application (e.g. https://mealie.example.com) |
| `PUID` | `1000` | User ID for the application process |
| `PGID` | `1000` | Group ID for the application process |
| `TZ` | `UTC` | Timezone for the container |

### Volumes

| Path | Description |
|------|-------------|
| `/config` | Data directory (database, images) |

### Ports

| Port | Protocol | Description |
|------|----------|-------------|
| `9000` | TCP | Web UI |

## Migrating from Linux

**SQLite:** No issues, just copy your data.

**PostgreSQL:** You cannot copy the postgres data directory between Linux and FreeBSD due to locale incompatibilities. Use `pg_dump`/`pg_restore` instead:

```bash
# On Linux
podman exec mealie-postgres pg_dump -U mealie mealie > mealie.sql

# On FreeBSD (start fresh postgres first, then restore)
cat mealie.sql | podman exec -i mealie-postgres psql -U mealie -d mealie
```

See [daemonless/postgres README](https://github.com/daemonless/postgres#migrating-from-linux) for details.


## Notes

- **User:** `bsd` (UID/GID set via PUID/PGID)
- **Base:** Built on `ghcr.io/daemonless/base` (FreeBSD)