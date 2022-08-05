#!/bin/sh -ex

# For quincy, the last_opt_revision remains at 1 since last_opt_revision
# was phased out for fresh installs of quincy.
LAST_OPT_REVISION=$(ceph config get mgr mgr/telemetry/last_opt_revision)
if [ $LAST_OPT_REVISION -ne 1 ]; then
    echo "last_opt_revision is incorrect"
    exit 1
fi

# Assert that new collections are available
ceph telemetry collection ls | grep 'perf_perf\|basic_mds_metadata\|basic_pool_usage\|basic_rook_v01\|perf_memory_metrics'

# Check the warning:
ceph -s

#Run preview commands
ceph telemetry preview
ceph telemetry preview-device

# Opt in to new collections
ceph telemetry on --license sharing-1-0

# Check warning again:
ceph -s

# Run show commands
ceph telemetry show
ceph telemetry show-device
ceph telemetry show

# Opt out
ceph telemetry off

echo OK

