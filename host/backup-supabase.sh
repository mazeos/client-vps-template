#!/bin/bash
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR=/root/backups/supabase
mkdir -p $BACKUP_DIR

docker exec supabase-db pg_dump -U postgres -d postgres --clean --if-exists > $BACKUP_DIR/backup_$DATE.sql

# Mantener solo los últimos 30 backups
ls -t $BACKUP_DIR/backup_*.sql | tail -n +31 | xargs rm -f 2>/dev/null

echo "Backup guardado: $BACKUP_DIR/backup_$DATE.sql ($(du -sh $BACKUP_DIR/backup_$DATE.sql | cut -f1))"

