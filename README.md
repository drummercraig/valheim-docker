# Valheim Server Docker

A simple Valheim dedicated server running in a Docker container on Ubuntu 24.04 with world persistence and verified graceful shutdown.

## Features

- **Automatic Updates**: Checks for Valheim server updates every 15 minutes (configurable)
- **World Persistence**: Worlds stored in `/userfiles/worlds_local` directory
- **Automatic Backups**: Creates compressed backups of your worlds every hour
- **Graceful Shutdown**: Verifies world save during container stop with timestamp validation
- **Easy Configuration**: Configure via environment variables
- **Supervisor Management**: All services managed by supervisord
- **Save Verification**: Scripts to check and force world saves with timestamp verification

## Quick Start

### Using Docker Compose (Recommended)

1. Clone this repository:
```bash
git clone <your-repo-url>
cd valheim-server-docker
```

2. Create required directories:
```bash
mkdir -p userfiles/worlds_local userfiles/backups serverfiles
```

3. Edit `docker-compose.yaml` to configure your server settings

4. Start the server:
```bash
docker compose up -d
```

5. View logs:
```bash
docker compose logs -f
```

### Using Docker CLI

```bash
docker run -d \
  --name valheim-server \
  --cap-add=sys_nice \
  -p 2456-2457:2456-2457/udp \
  -v $(pwd)/userfiles:/userfiles \
  -v $(pwd)/serverfiles:/opt/valheim \
  -e SERVER_NAME="My Server" \
  -e WORLD_NAME="Dedicated" \
  -e SERVER_PASS="secret123" \
  -e SERVER_PUBLIC=true \
  valheim-server:latest
```

## Configuration

Configure your server using environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `SERVER_NAME` | `My Valheim Server` | Server name shown in browser |
| `SERVER_PORT` | `2456` | UDP port (also opens 2457 automatically) |
| `WORLD_NAME` | `Dedicated` | World name without file extension |
| `SERVER_PASS` | `secret` | Server password (min 5 characters) |
| `SERVER_PUBLIC` | `true` | List in server browser |
| `SERVER_ARGS` | `` | Additional server arguments (e.g., `-crossplay`) |
| `UPDATE_INTERVAL` | `900` | Update check interval in seconds |
| `BACKUPS_ENABLED` | `true` | Enable automatic backups |
| `BACKUPS_INTERVAL` | `3600` | Backup interval in seconds |
| `BACKUPS_DIRECTORY` | `/userfiles/backups` | Backup location |
| `BACKUPS_MAX_AGE` | `3` | Delete backups older than X days |
| `TZ` | `Etc/UTC` | Timezone |

## Volume Mounts

- `/userfiles` - Server configuration, world files, and backups
  - `/userfiles/worlds_local/` - World save files (`.db`, `.fwl`)
  - `/userfiles/backups/` - Automatic backup files
- `/opt/valheim` - Valheim server installation (can be reused across rebuilds)

## Ports

| Port | Protocol | Description |
|------|----------|-------------|
| `2456` | UDP | Game traffic |
| `2457` | UDP | Server query |
| `2458` | UDP | Crossplay (if enabled) |

## World Persistence

Your world files are stored in `/userfiles/worlds_local/` and mounted as a volume. The container uses a symlink to redirect Valheim's world directory to this persistent location.

**How it works:**
1. On first start, the container creates a symlink: `/root/.config/unity3d/IronGate/Valheim/worlds_local` → `/userfiles/worlds_local`
2. Valheim server saves worlds to this location
3. A sync monitor runs every 30 seconds to ensure files are in the persistent location
4. World files persist across container restarts

**World files consist of:**
- `<WORLD_NAME>.fwl` - World metadata (created immediately)
- `<WORLD_NAME>.db` - Main world database (saved every 20 minutes and on shutdown)
- `<WORLD_NAME>.db.old` - Previous world state (backup)

**Important: World Save Timing**
- The `.fwl` file appears immediately when the world is created
- The `.db` file (actual world data) is only written:
  - Every **20 minutes** during gameplay
  - When the server **shuts down gracefully**
  - When a **backup is triggered**

**To force a world save:**
```bash
# Use the force-save script (easiest)
docker exec valheim-server /usr/local/bin/force-save

# Or graceful restart (saves world first)
docker compose restart

# Or send save command via supervisor
docker exec valheim-server supervisorctl restart valheim-server
```

**Verifying world sync:**
```bash
# Check that worlds are in the persistent location
ls -la userfiles/worlds_local/

# Should show files like:
# Dedicated.fwl  (appears immediately)
# Dedicated.db   (appears after 20 min or on save)
# Dedicated.db.old
```

## Graceful Shutdown

The container is configured to **gracefully shutdown** the Valheim server when stopping:

1. Docker sends SIGTERM to the container
2. Container forwards SIGTERM to Valheim server
3. Pre-stop hook monitors the save process
4. Server saves the world and exits (up to 90 seconds)
5. Hook verifies the .db file was updated
6. Container stops

**Important:** The `stop_grace_period: 2m` in docker-compose ensures Docker waits long enough for the world to save.

### Recommended Shutdown Workflow

**Easiest: Use the safe-stop script (on host)**
```bash
# Make it executable first
chmod +x safe-stop.sh

# Interactive - checks status and prompts you
./safe-stop.sh

# Force save then stop
./safe-stop.sh --force-save
```

**Option 1: Check status first, then stop (manual)**
```bash
# Check if world needs saving
docker exec valheim-server /usr/local/bin/check-world-status

# Exit codes:
#   0 = Recently saved (safe to stop)
#   2 = Needs save (run force-save first)
#   1 = No save file (world only in memory - will be lost!)

# If status is not recent, force a save
docker exec valheim-server /usr/local/bin/force-save

# Then stop (will verify save during shutdown)
docker compose stop
```

**Option 2: Force save and stop in one command**
```bash
# This is safe and recommended for routine stops
docker exec valheim-server /usr/local/bin/force-save && docker compose stop
```

**Option 3: Just stop (relies on SIGTERM save)**
```bash
# Container will attempt to save during shutdown
# Pre-stop hook will verify the save completed
docker compose stop

# Check logs to see if save was successful
docker compose logs valheim-server | tail -50
```

### Understanding the Scripts

For detailed information about all scripts, see [SCRIPTS.md](SCRIPTS.md).

**check-world-status** - Check current save status
- Shows when world was last saved
- Tells you if it's safe to stop
- Exit codes: 0 (safe), 1 (no save), 2 (old save)

**force-save** - Force immediate save with verification  
- Records .db timestamp before restart
- Triggers server restart (SIGTERM save)
- Waits up to 120 seconds for new timestamp
- Verifies timestamp is newer than restart time

**pre-stop-hook** - Automatic verification during shutdown
- Runs automatically when container stops
- Records .db timestamp before SIGTERM  
- Waits up to 90 seconds for .db update
- Verifies timestamp is newer than stop time

### What NOT to Do

**❌ Never use these commands:**
```bash
docker compose kill          # Sends SIGKILL - no save!
docker kill valheim-server   # Sends SIGKILL - no save!
docker stop -t 0             # No time to save!
```

### Troubleshooting Failed Saves

If a stop doesn't save the world:

```bash
# Check recent logs
docker compose logs valheim-server | grep -A 20 "SHUTDOWN"

# Check world file age
docker exec valheim-server ls -lh /userfiles/worlds_local/

# Force a save manually
docker exec valheim-server /usr/local/bin/force-save
```

## Backups

Automatic backups are created every hour (configurable) and stored in `/userfiles/backups/`.

- Backups are compressed ZIP files
- Old backups are automatically cleaned up based on `BACKUPS_MAX_AGE`
- Backup naming: `worlds_backup_YYYYMMDD_HHMMSS.zip`

### Manual Backup

You can trigger a manual backup by restarting the backup service:

```bash
docker exec valheim-server supervisorctl restart valheim-backup
```

## Importing Existing Worlds

To use an existing world:

1. Copy your world files to `./userfiles/worlds_local/`:
   ```bash
   cp /path/to/YourWorld.db ./userfiles/worlds_local/
   cp /path/to/YourWorld.fwl ./userfiles/worlds_local/
   ```

2. Set `WORLD_NAME` environment variable to match (without extension):
   ```yaml
   environment:
     - WORLD_NAME=YourWorld
   ```

3. Restart the container

## Crossplay Support

To enable crossplay (PC, Xbox, etc.):

1. Add `-crossplay` to `SERVER_ARGS`:
   ```yaml
   environment:
     - SERVER_ARGS=-crossplay
   ```

2. Make sure port 2458/udp is exposed

## Troubleshooting

### Server not starting

Check logs:
```bash
docker compose logs valheim-server
```

### Can't find server in browser

- Ensure ports are forwarded in your router
- Check firewall allows UDP ports 2456-2457
- Verify `SERVER_PUBLIC=true` if you want it listed

### World files not appearing in userfiles/worlds_local

**If you only see .fwl but no .db file:**

This is normal! The `.db` file (actual world data) is only saved every 20 minutes or on graceful shutdown.

To force an immediate save:
```bash
docker exec valheim-server /usr/local/bin/force-save
```

**For other issues, run the debug script:**
```bash
# Run the debug script
docker exec valheim-server /usr/local/bin/debug-worlds
```

This will show you:
- Where the symlink points
- Contents of both directories
- Any orphaned world files
- Server configuration
- Process status

**Manual checks:**
```bash
# Check server logs
docker compose logs valheim-server | grep -i world

# Check if symlink exists
docker exec valheim-server ls -la /opt/valheim/worlds_local

# Check userfiles directory
docker exec valheim-server ls -la /userfiles/worlds_local

# Search for world files anywhere
docker exec valheim-server find /opt/valheim /userfiles -name "*.db" -o -name "*.fwl"

# Force a sync
docker exec valheim-server supervisorctl restart valheim-sync
```

**If worlds are still not syncing:**
1. Stop the container: `docker compose down`
2. Check host directory permissions: `ls -la userfiles/worlds_local/`
3. Rebuild and restart: `docker compose up -d --build`
4. Monitor sync in real-time: `docker compose logs -f valheim-sync`

### Password too short error

Server password must be at least 5 characters long.

### Checking service status

```bash
docker exec valheim-server supervisorctl status
```

## Resource Requirements

**Minimum:**
- 2 CPU cores
- 4 GB RAM
- 2 GB disk space

**Recommended:**
- 4 CPU cores (high clock speed preferred)
- 8 GB RAM
- 5 GB disk space

## Building the Image

```bash
docker build -t valheim-server:latest .
```

## License

This container is not affiliated with or endorsed by Iron Gate Studio.

Valheim is © Iron Gate Studio.