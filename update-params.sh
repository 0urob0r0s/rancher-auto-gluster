#!/bin/bash
# Script to update the parameters passed to container image

: ${GB_LOGDIR:=/var/log/glusterfs/gluster-block}
: ${TCMU_LOGDIR:=/var/log/glusterfs/gluster-block}
: ${GB_GLFS_LRU_COUNT:=15}
: ${GB_CLI_TIMEOUT:=900}
: ${HOST_DEV_DIR:=/mnt/host-dev}
: ${CGROUP_PIDS_MAX:=max}

set_cgroup_pids() {
  local ret=0
  local pids=$1
  local cgroup max

  cgroup=$(awk -F: '/:pids:/{print $3}' /proc/self/cgroup)

  max=$(cat /sys/fs/cgroup/pids/"${cgroup}"/pids.max)
  echo "maximum number of pids configured in cgroups: ${max}"

  echo "${pids}" > /sys/fs/cgroup/pids/"${cgroup}"/pids.max
  ret=$?

  max=$(cat /sys/fs/cgroup/pids/"${cgroup}"/pids.max)
  echo "maximum number of pids configured in cgroups (reconfigured): ${max}"

  return ${ret}
}

# do not change cgroup/pids when CGROUP_PIDS_MAX is set to 0
if [[ "${CGROUP_PIDS_MAX}" != '0' ]]
then
  set_cgroup_pids ${CGROUP_PIDS_MAX}
fi

echo "env variable is set. Update in gluster-blockd.service"
#FIXME To update in environment file
sed -i '/GB_GLFS_LRU_COUNT=/s/GB_GLFS_LRU_COUNT=.*/'GB_GLFS_LRU_COUNT="$GB_GLFS_LRU_COUNT"\"'/'  /usr/lib/systemd/system/gluster-blockd.service
sed -i '/EnvironmentFile/i Environment="GB_LOGDIR='$GB_LOGDIR'"' /usr/lib/systemd/system/gluster-blockd.service

sed -i "s/^#GB_CLI_TIMEOUT=.*/GB_CLI_TIMEOUT=${GB_CLI_TIMEOUT}/" /etc/sysconfig/gluster-blockd

sed -i "s#TCMU_LOGDIR=.*#TCMU_LOGDIR='$TCMU_LOGDIR'#g" /etc/sysconfig/tcmu-runner-params

sed -i '/ExecStart/i EnvironmentFile=-/etc/sysconfig/tcmu-runner-params' /usr/lib/systemd/system/tcmu-runner.service
sed -i  '/tcmu-log-dir=/s/tcmu-log-dir.*/tcmu-log-dir $TCMU_LOGDIR/' /usr/lib/systemd/system/tcmu-runner.service

if [ -c "${HOST_DEV_DIR}/zero" ] && [ -c "${HOST_DEV_DIR}/null" ]; then
    # looks like an alternate "host dev" has been provided
    # to the container. Use that as our /dev ongoing
    mount --rbind "${HOST_DEV_DIR}" /dev
fi

#Export ENV
declare -p | grep -Ev 'BASHOPTS|BASH_VERSINFO|EUID|PPID|SHELLOPTS|UID' > /container.env

# Hand off to CMD
exec "$@"
