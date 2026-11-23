#!/bin/bash

# arguments
psql_host=$1
psql_port=$2
db_name=$3
psql_user=$4
psql_password=$5

# check # of arguments
if [ "$#" -ne 5 ]; then
    echo "Illegal number of parameters"
    exit 1
fi

# save info
cpu_info=$(lscpu)
hostname=$(hostname -f)

# Retrieve hwspec
cpu_number=$(echo "$cpu_info" | awk -F: '/^CPU\(s\):/ {print $2}' | xargs)
cpu_architecture=$(echo "$cpu_info" | awk -F: '/^Architecture:/ {print $2}' | xargs)
cpu_model=$(echo "$cpu_info" | awk -F: '/^Model name:/ {print $2}' | xargs)
cpu_mhz=$(echo "$cpu_info" | awk -F: '/^CPU MHz:/ {print $2}' | xargs)

if [ -z "$cpu_mhz" ]; then
    cpu_mhz=$(awk -F: '/^cpu MHz/ {print $2; exit}' /proc/cpuinfo | xargs)
fi

# L2 cache in kB
l2_cache=$(echo "$cpu_info" | awk -F: '/^L2 cache:/ {print $2}' | xargs)

# Convert common lscpu cache units to kB
l2_cache=$(echo "$l2_cache" | awk '{
    if ($2 == "MiB") print $1 * 1024;
    else if ($2 == "GiB") print $1 * 1048576;
    else print $1
}')

# Total memory in kB
total_mem=$(cat /proc/meminfo | awk '/^MemTotal:/ {print $2}')

# Current UTC timestamp
timestamp=$(date -u '+%Y-%m-%d %H:%M:%S')

# Subquery to check whether the hostname already exists
host_id="(SELECT id FROM host_info WHERE hostname='$hostname')"

# Construct SQL INSERT statement
insert_stmt="INSERT INTO host_info (
    hostname,
    cpu_number,
    cpu_architecture,
    cpu_model,
    cpu_mhz,
    l2_cache,
    total_mem,
    timestamp
) VALUES (
    '$hostname',
    $cpu_number,
    '$cpu_architecture',
    '$cpu_model',
    $cpu_mhz,
    $l2_cache,
    $total_mem,
    '$timestamp'
);"

# Set PostgreSQL password
export PGPASSWORD="$psql_password"

# Insert hardware information into PostgreSQL
psql -h "$psql_host" \
     -p "$psql_port" \
     -d "$db_name" \
     -U "$psql_user" \
     -v ON_ERROR_STOP=1 \
     -c "$insert_stmt"

exit $?
