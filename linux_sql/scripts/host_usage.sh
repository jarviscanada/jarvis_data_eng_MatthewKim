
#!/bin/bash

# PostgreSQL connection arguments
psql_host=$1
psql_port=$2
db_name=$3
psql_user=$4
psql_password=$5

# Validate arguments
if [ "$#" -ne 5 ]; then
    echo "Illegal number of parameters"
    exit 1
fi

# Save machine statistics and hostname
vmstat_mb=$(vmstat --unit M)
hostname=$(hostname -f)

# Retrieve resource usage values
memory_free=$(echo "$vmstat_mb" | awk '{print $4}' | tail -n1 | xargs)
cpu_idle=$(echo "$vmstat_mb" | awk '{print $15}' | tail -n1 | xargs)
cpu_kernel=$(echo "$vmstat_mb" | awk '{print $14}' | tail -n1 | xargs)

# Disk I/O statistics
disk_io=$(vmstat -d | awk 'NR > 2 {sum += $10} END {print sum+0}')

# Available disk space in MB
disk_available=$(df -BM / | awk 'NR == 2 {gsub(/M/, "", $4); print $4}')

# Current UTC timestamp
timestamp=$(date -u '+%Y-%m-%d %H:%M:%S')

# Find matching host ID
host_id="(SELECT id FROM host_info WHERE hostname='$hostname')"

# Construct INSERT statement
insert_stmt="INSERT INTO host_usage (
    timestamp,
    host_id,
    memory_free,
    cpu_idle,
    cpu_kernel,
    disk_io,
    disk_available
) VALUES (
    '$timestamp',
    $host_id,
    $memory_free,
    $cpu_idle,
    $cpu_kernel,
    $disk_io,
    $disk_available
);"

# Set PostgreSQL password
export PGPASSWORD="$psql_password"

# Insert resource usage into PostgreSQL
psql -h "$psql_host" \
     -p "$psql_port" \
     -d "$db_name" \
     -U "$psql_user" \
     -v ON_ERROR_STOP=1 \
     -c "$insert_stmt"

exit $?
