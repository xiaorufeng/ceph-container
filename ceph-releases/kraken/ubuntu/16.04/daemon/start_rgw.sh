#!/bin/bash
set -e

function start_rgw {
  get_config
  check_config

  if [ ${CEPH_GET_ADMIN_KEY} -eq 1 ]; then
    get_admin_key
    check_admin_key
  fi

  # Check to see if our RGW has been initialized
  if [ ! -e /var/lib/ceph/radosgw/${RGW_NAME}/keyring ]; then

    if [ ! -e /var/lib/ceph/bootstrap-rgw/${CLUSTER}.keyring ]; then
      log "ERROR- /var/lib/ceph/bootstrap-rgw/${CLUSTER}.keyring must exist. You can extract it from your current monitor by running 'ceph auth get client.bootstrap-rgw -o /var/lib/ceph/bootstrap-rgw/${CLUSTER}.keyring'"
      exit 1
    fi

    timeout 10 ceph ${CEPH_OPTS} --name client.bootstrap-rgw --keyring /var/lib/ceph/bootstrap-rgw/${CLUSTER}.keyring health || exit 1

    # Generate the RGW key
    ceph ${CEPH_OPTS} --name client.bootstrap-rgw --keyring /var/lib/ceph/bootstrap-rgw/${CLUSTER}.keyring auth get-or-create client.rgw.${RGW_NAME} osd 'allow rwx' mon 'allow rw' -o /var/lib/ceph/radosgw/${RGW_NAME}/keyring
    chown ceph. /var/lib/ceph/radosgw/${RGW_NAME}/keyring
    chmod 0600 /var/lib/ceph/radosgw/${RGW_NAME}/keyring
  fi

  log "SUCCESS"

  RGW_FRONTENDS="civetweb port=$RGW_CIVETWEB_PORT"
  if [ "$RGW_REMOTE_CGI" -eq 1 ]; then
    RGW_FRONTENDS="fastcgi socket_port=$RGW_REMOTE_CGI_PORT socket_host=$RGW_REMOTE_CGI_HOST"
  fi

  exec /usr/bin/radosgw -d ${CEPH_OPTS} -n client.rgw.${RGW_NAME} -k /var/lib/ceph/radosgw/$RGW_NAME/keyring --rgw-socket-path="" --rgw-zonegroup="$RGW_ZONEGROUP" --rgw-zone="$RGW_ZONE" --rgw-frontends="$RGW_FRONTENDS" --setuser ceph --setgroup ceph
}

function create_rgw_user {

  # Check to see if our RGW has been initialized
  if [ ! -e /var/lib/ceph/radosgw/keyring ]; then
    log "ERROR- /var/lib/ceph/radosgw/keyring must exist. Please get it from your Rados Gateway"
    exit 1
  fi

  mv /var/lib/ceph/radosgw/keyring /var/lib/ceph/radosgw/${RGW_NAME}/keyring

  USER_KEY=""
  if [ -n "${RGW_USER_SECRET_KEY}" ]; then
    USER_KEY="--access-key=${RGW_USER_USER_KEY} --secret=${RGW_USER_SECRET_KEY}"
  fi

  exec radosgw-admin user create --uid=${RGW_USER} ${USER_KEY} --display-name="RGW ${RGW_USER} User" -c /etc/ceph/${CLUSTER}.conf
}
