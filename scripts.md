# Scripts Reference

This document describes all the scripts included in this Valheim server container.

## Host Scripts (Run on Docker host)

### safe-stop.sh
**Location:** Repository root  
**Purpose:** Interactive script for safely stopping the server with save verification

**Usage:**
```bash
./safe-stop.sh [OPTIONS]

Options:
  -f, --force-save    Force a save before stopping
  -h, --help         Show help message
```

**What it does:**
1. Checks if container is running
2. Optionally checks world save status
3. Prompts user if save is needed
4. Optionally forces a save
5. Stops the container safely

**Examples:**
```bash
./safe-stop.sh                # Interactive - checks and prompts
./safe-stop.sh --force-save   # Always force save first
```

---

## Container Scripts (Run inside container)

### check-world-status
**Location:** `/usr/local/bin/check-world-status`  
**Purpose:** Check current world save status and age

**Usage:**
```bash
# From host
docker exec valheim-server /usr/local/bin/check-world-status

# From inside container
/usr/local/bin/check-world-status
```

**Exit codes:**
- `0` - World recently saved (< 2 minutes), safe to stop
- `1` - No save file exists, world only in memory
- `2` - Save exists but is old (> 2 minutes), recommend force-save

**Output includes:**
- Last save timestamp
- File size
- Age of save file
- Safety recommendation

---

### force-save
**Location:** `/usr/local/bin/force-save`  
**Purpose:** Force an immediate world save with timestamp verification

**Usage:**
```bash
# From host
docker exec valheim-server /usr/local/bin/force-save

# From inside container
/usr/local/bin/force-save
```

**What it does:**
1. Records current .db file timestamp (if exists)
2. Records restart time
3. Restarts Valheim server (triggers SIGTERM save)
4. Waits up to 120 seconds
5. Checks if .db file was updated with new timestamp
6. Reports success or failure with timestamps

**Exit codes:**
- `0` - Save verified with new timestamp
- `1` - Save failed or could not verify

---

### pre-stop-hook
**Location:** `/usr/local/bin/pre-stop-hook`  
**Purpose:** Automatically verify world save during container shutdown

**Usage:** Runs automatically during shutdown (called by valheim-server script)

**What it does:**
1. Records stop time
2. Gets current .db timestamp
3. Waits for SIGTERM save to complete (up to 90 seconds)
4. Verifies .db file was updated after stop time
5. Reports success/failure to logs

**This runs automatically** - you don't need to call it manually.

---

### debug-worlds
**Location:** `/usr/local/bin/debug-worlds`  
**Purpose:** Comprehensive debugging information about world file locations

**Usage:**
```bash
docker exec valheim-server /usr/local/bin/debug-worlds
```

**Output includes:**
- Unity config directory status and symlink info
- Server directory status
- Persistent storage directory contents
- Search results for all .db and .fwl files
- Server configuration
- Process status
- Recent server logs

---

### valheim-server
**Location:** `/usr/local/bin/valheim-server`  
**Purpose:** Main server startup and shutdown script

**Managed by:** Supervisord (runs automatically)

**Features:**
- Sets up world persistence symlinks
- Starts Valheim server process
- Handles graceful shutdown with SIGTERM
- Calls pre-stop-hook during shutdown
- Waits for world save completion

---

### valheim-updater
**Location:** `/usr/local/bin/valheim-updater`  
**Purpose:** Automatically check for and install Valheim server updates

**Managed by:** Supervisord (runs automatically)

**Features:**
- Initial server installation via SteamCMD
- Periodic update checks (default: every 15 minutes)
- Compares build IDs to detect updates
- Restarts server when update found

---

### valheim-backup
**Location:** `/usr/local/bin/valheim-backup`  
**Purpose:** Create automatic backups of world files

**Managed by:** Supervisord (runs automatically)

**Features:**
- Creates ZIP backups of worlds_local directory
- Runs on configurable schedule (default: hourly)
- Automatic cleanup of old backups
- Only backs up if .db file exists

---

### valheim-sync
**Location:** `/usr/local/bin/valheim-sync`  
**Purpose:** Monitor and verify world file symlink integrity

**Managed by:** Supervisord (runs automatically)

**Features:**
- Checks symlink every 30 seconds
- Detects if symlink becomes a directory
- Automatically syncs orphaned files
- Reports status every 5 minutes

---

## Workflow Examples

### Normal Stop Procedure
```bash
# Option 1: Use safe-stop script (recommended)
./safe-stop.sh

# Option 2: Manual with force-save
docker exec valheim-server /usr/local/bin/force-save && docker compose stop

# Option 3: Just stop (relies on SIGTERM)
docker compose stop
```

### Check if Safe to Stop
```bash
docker exec valheim-server /usr/local/bin/check-world-status
# Exit code 0 = safe
# Exit code 2 = should save first
```

### Force Save Only (Don't Stop)
```bash
docker exec valheim-server /usr/local/bin/force-save
```

### Debug World Issues
```bash
docker exec valheim-server /usr/local/bin/debug-worlds
```

---

## Understanding Timestamps

All save verification scripts work by comparing timestamps:

1. **Before action:** Record current time and .db file timestamp
2. **Trigger save:** Restart server or send SIGTERM
3. **After action:** Check if .db file timestamp is >= action time
4. **Verify:** If timestamp is newer, save succeeded

This ensures you can trust that the world was actually saved, not just that the process completed.

---

## Log Locations

When troubleshooting, check these logs:

```bash
# All server output
docker compose logs valheim-server

# Recent shutdown logs
docker compose logs valheim-server | grep -A 20 "SHUTDOWN"

# Pre-stop hook verification
docker compose logs valheim-server | grep -A 10 "PRE-STOP"

# Supervisor logs (inside container)
docker exec valheim-server tail -f /var/log/supervisor/*.log
```