#!/bin/bash

set -e
cd /opt/adobe

# Sync Local AEM DAM Assets From S3 to AMS
#
# Pulls previously backed-up DAM asset packages from the S3 bucket
# 'zeppelincom-aem-backup', uploads them to the local AEM service and triggers
# their installation. Must be run by the root user from the AEM instance in
# AWS. Run only on the Author instance; replication of the packages to the
# publishers is triggered here and managed by the AEM service itself.
#
# Recommended to use in a tmux session, as the runtime can extend to several
# hours.
#
# DEPENDENCIES: GNU find, stat; cURL; s3fs-fuse; awscli >= v1.16;
#   IAM permissions to read 'zeppelin-aem-backup', and Amazon Secrets Manager

# Set up our logfile
export _LOGFILE="$(mktemp /tmp/send2adobe.XXXXXX.log)"
. /opt/adobe/common.sh # provide log(), error(), get_credentials(), and $zenv

usage() {
    printf '
Usage: %s [ date_filter ] [ source_zenv ] [aws_region] [source_aem_node]

    Each "zenv" must be one of live, stage, test, or intn.
    Each "aem_node" must be one of author0, publish0 or publish1
' "$0"
    return 0
}

only_updated_package_paths=(
    /etc/packages/adobe/aem610/social/members/cq-social-members-pkg-1.3.17.zip

#   /etc/packages/adobe/consulting/acs-aem-commons-content-4.11.2.zip # big diff, 4.0.0 -> 4.11.2 (and assoc. pkgs)

    /etc/packages/adobe/cq/cq-contexthub-content-1.1.14.zip
    /etc/packages/adobe/cq/dtm-reactor.content-1.1.16.zip
    /etc/packages/adobe/cq/product/cq-remotedam-client-ui-components-1.0.18.zip
    /etc/packages/adobe/cq/product/cq-remotedam-client-ui-content-1.0.22.zip
    /etc/packages/adobe/cq/product/cq-remotedam-server-content-1.0.14.zip

    /etc/packages/adobe/granite/com.adobe.granite.conf.ui.content-0.0.64.zip
    /etc/packages/adobe/granite/com.adobe.granite.monitoring.dashboard-1.5.259-CQ650-B0004.zip
    /etc/packages/adobe/granite/com.adobe.granite.oauth.server.content-1.0.54.zip
    /etc/packages/adobe/granite/com.adobe.granite.offloading.content-1.1.66-CQ650-B0003.zip
    /etc/packages/adobe/granite/com.adobe.granite.platform.clientlibs-2.3.1-CQ650-B0004.zip
    /etc/packages/adobe/granite/com.adobe.granite.platform.content-1.0.40-CQ650-B0004.zip
    /etc/packages/adobe/granite/com.adobe.granite.platform.login-1.1.38-CQ650-B0003.zip
    /etc/packages/adobe/granite/com.adobe.granite.platform.welcome-1.1.26-CQ650-B0002.zip
    /etc/packages/adobe/granite/com.adobe.granite.references.content-1.1.36-CQ650-B0006.zip
    /etc/packages/adobe/granite/com.adobe.granite.replication.content-1.0.41-CQ650-B0001.zip
    /etc/packages/adobe/granite/com.adobe.granite.security.content-0.2.407-CQ650-B0006.zip
    /etc/packages/adobe/granite/com.adobe.granite.ui.content-0.8.870-CQ651-B0176.zip
    /etc/packages/adobe/granite/com.adobe.granite.ui.coralui3-1.5.42-CQ650-B0122.zip
    /etc/packages/adobe/granite/com.adobe.granite.ui.coralui3-rte-0.3.50.zip
    /etc/packages/adobe/granite/com.adobe.granite.ui.foundation.components-0.2.5-CQ650-B0004.zip
    /etc/packages/adobe/granite/com.adobe.granite.ui.legacy-1.3.1-CQ650-B0008.zip
    /etc/packages/adobe/granite/com.adobe.reef.contexthub.content-0.4.24.zip
    /etc/packages/adobe/granite/tsdk-aem-clientlib-1.1.22.zip

    /etc/packages/day/cq560/social/activitystreams/cq-social-activitystreams-pkg-1.6.21.zip
    /etc/packages/day/cq560/social/calendar/cq-social-calendar-pkg-1.6.35.zip
    /etc/packages/day/cq560/social/commons/cq-social-commons-pkg-1.10.111.zip
    /etc/packages/day/cq560/social/commons/cq-social-thirdparty-pkg-1.5.11.zip
    /etc/packages/day/cq560/social/filelibrary/cq-social-filelibrary-pkg-1.5.20.zip
    /etc/packages/day/cq560/social/forum/cq-social-forum-pkg-1.8.31.zip
    /etc/packages/day/cq560/social/group/cq-social-group-pkg-1.7.30.zip
    /etc/packages/day/cq560/social/journal/cq-social-journal-pkg-1.6.31.zip
    /etc/packages/day/cq560/social/messaging/cq-social-messaging-pkg-1.6.22.zip
    /etc/packages/day/cq560/social/moderation/cq-social-moderation-pkg-2.5.22.zip
    /etc/packages/day/cq560/social/qna/cq-social-qna-pkg-1.7.20.zip
    /etc/packages/day/cq560/social/tally/cq-social-tally-pkg-1.6.3.zip

#   /etc/packages/adobe/cq650/servicepack/aem-service-pkg-6.5.8.zip # SVCPACK minor is diff, 6.5.4 -> 6.5.8

    /etc/packages/day/cq60/fd/aemfd-expeditor-rulebuilder-pkg-5.0.76.zip
    /etc/packages/day/cq60/product/cq-cloudservices-content-1.5.28.zip
    /etc/packages/day/cq60/product/cq-commerce-content-1.7.48.zip
    /etc/packages/day/cq60/product/cq-content-insight-content-1.5.8.zip
    /etc/packages/day/cq60/product/cq-dam-cfm-content-0.11.118.zip
    /etc/packages/day/cq60/product/cq-dam-content-2.5.738.zip
    /etc/packages/day/cq60/product/cq-dam-content-2.5.772-NPR-34633-B0002.zip
    /etc/packages/day/cq60/product/cq-dam-projects-addons-content-0.1.6.zip
    /etc/packages/day/cq60/product/cq-dam-sample-content-1.4.10.zip
    /etc/packages/day/cq60/product/cq-dam-scene7-viewers-content-2.3.94.zip
    /etc/packages/day/cq60/product/cq-dam-stock-integration-content-1.1.12.zip
    /etc/packages/day/cq60/product/cq-dynamicmedia-content-1.0.314-NPR-34633-B0002.zip
    /etc/packages/day/cq60/product/cq-foundation-content-1.5.52.zip
    /etc/packages/day/cq60/product/cq-i18n-content-1.5.110.zip
    /etc/packages/day/cq60/product/cq-integration-analytics-content-1.3.28.zip
    /etc/packages/day/cq60/product/cq-integration-target-content-1.3.54.zip
    /etc/packages/day/cq60/product/cq-launches-content-1.7.18.zip
    /etc/packages/day/cq60/product/cq-mcm-content-1.4.60.zip
    /etc/packages/day/cq60/product/cq-personalization-content-1.3.104.zip
    /etc/packages/day/cq60/product/cq-platform-content-1.5.164.zip
    /etc/packages/day/cq60/product/cq-projects-content-1.5.34.zip
    /etc/packages/day/cq60/product/cq-ui-classic-content-1.5.48.zip
    /etc/packages/day/cq60/product/cq-ui-static-typekit-content-1.3.4.zip
    /etc/packages/day/cq60/product/cq-ui-touch-optimized-content-2.6.114.zip
    /etc/packages/day/cq60/product/cq-ui-wcm-admin-content-1.1.102.zip
    /etc/packages/day/cq60/product/cq-ui-wcm-commons-content-1.1.170.zip
    /etc/packages/day/cq60/product/cq-ui-wcm-editor-content-1.1.384.zip
    /etc/packages/day/cq60/product/cq-wcm-content-6.5.104.zip
    /etc/packages/day/cq60/product/cq-workflow-console-content-1.4.74.zip
    /etc/packages/day/cq610/social/console/cq-social-console-pkg-1.6.74.zip
    /etc/packages/day/cq610/social/enablement/cq-social-enablement-pkg-2.3.46.zip
    /etc/packages/day/cq63/product/cq-experience-fragments-content-1.2.124.zip
)
missing_package_paths=(
#   /etc/packages/zeppelin/zeppelin-users-only-1.0.0.zip

    /etc/packages/adobe/consulting/acs-aem-commons-ui.apps-4.11.2.zip
    /etc/packages/adobe/consulting/acs-aem-commons-ui.content-4.11.2.zip

    /etc/packages/adobe/cq60/core.wcm.components.all-2.3.2.zip
    /etc/packages/adobe/cq60/core.wcm.components.config-2.3.2.zip
    /etc/packages/adobe/cq60/core.wcm.components.content-2.3.2.zip

    /etc/packages/wcm-io/io.wcm.caconfig.editor.package-1.8.2.zip

#   /etc/packages/zeppelin/zeppelin-system-2.0.1.zip

    /etc/packages/zeppelin/zeppelin-config-package-4.10.0-SNAPSHOT.zip
    /etc/packages/zeppelin/zeppelin-elastic-package-4.10.0-SNAPSHOT.zip
    /etc/packages/zeppelin/zeppelin-overlay-package-4.10.0-SNAPSHOT.zip
    /etc/packages/zeppelin/zeppelin-package-4.10.0-SNAPSHOT.zip
    /etc/packages/zeppelin/zeppelin_complete-4.10.0-SNAPSHOT.zip
)


#####################################################################################
## FIRST ROUND TRIAL 05.08 - FAILED, ROLLED BACK TO HERE WITH CSE INSTALLING SVCPACK
# Installed 05.08.2021 10:30 / Restart Succeeded
transfer_package_paths0=(
    /etc/packages/adobe/consulting/acs-aem-commons-ui.apps-4.11.2.zip       # dependent on acs...-content-4.11.2
    /etc/packages/adobe/consulting/acs-aem-commons-ui.content-4.11.2.zip    # dependent on acs...-content-4.11.2

    /etc/packages/adobe/cq60/core.wcm.components.all-2.3.2.zip          # dependent on zeppelin_complete
    /etc/packages/adobe/cq60/core.wcm.components.config-2.3.2.zip       # dependent on zeppelin_complete
    /etc/packages/adobe/cq60/core.wcm.components.content-2.3.2.zip      # dependent on zeppelin_complete

    /etc/packages/wcm-io/io.wcm.caconfig.editor.package-1.8.2.zip
)
# Installed 05.08.2021 10:40 / Restart Succeeded
transfer_package_paths1=(
    /etc/packages/zeppelin/zeppelin-system-2.0.1.zip
)

# Installed 05.08.2021 10:50 
# Manually installed paths0's acs-aem-commons-content-4.11.2.zip, required rebuild - other dependent pkgs were installed following component restart 
#   - note: "Starting system components..." dialog hangs, reload page after a few minutes.
# Manually installed core.wcm.components.content-2.3.2.zip, all other dependent packages installed following component restart
transfer_package_paths2=(
    /etc/packages/adobe/consulting/acs-aem-commons-content-4.11.2.zip   # required for ui.apps, ui.content

    /etc/packages/zeppelin/zeppelin-config-package-4.10.0-SNAPSHOT.zip
    /etc/packages/zeppelin/zeppelin-elastic-package-4.10.0-SNAPSHOT.zip
    /etc/packages/zeppelin/zeppelin-overlay-package-4.10.0-SNAPSHOT.zip
    /etc/packages/zeppelin/zeppelin-package-4.10.0-SNAPSHOT.zip
    /etc/packages/zeppelin/zeppelin_complete-4.10.0-SNAPSHOT.zip    # INSTALL FIRST required for other pkgs
)

# Installed 05.08.2021 11:15 / Restart Succeeded (Failed again after about six-seven minutes)
transfer_package_paths3=(
    /etc/packages/adobe/cq650/servicepack/aem-service-pkg-6.5.8.zip # SVCPACK minor is diff, 6.5.4 -> 6.5.8
)


#####################################################################################
## SECOND ROUND TRIAL 06.08 - FAILED, ROLLED BACK TO HERE WITH CSE INSTALLING SVCPACK
# Installed both path groups at 06.08.2021 15:10 -- Manually uploaded
# zeppelin-system-2.0.2-SNAPSHOT from STAGE during zeppelin-package install;
# core.wcm.components.content also depended on this version. Then manually installed
# core.wcm.components.content-2.3.2.zip, and rebuilt the zeppelin-foo-packages.
# Lastly waited for load to cool on the instnace before running a restart test
# at 15:24 CEST.  .... Restarted, but now login shows 503 error (no Authentication Agent).
transfer_package_paths0=(
    /etc/packages/adobe/consulting/acs-aem-commons-content-4.11.2.zip   # required for ui.apps, ui.content

    /etc/packages/adobe/consulting/acs-aem-commons-ui.apps-4.11.2.zip       # dependent on acs...-content-4.11.2
    /etc/packages/adobe/consulting/acs-aem-commons-ui.content-4.11.2.zip    # dependent on acs...-content-4.11.2

    /etc/packages/adobe/cq60/core.wcm.components.all-2.3.2.zip          # dependent on zeppelin_complete
    /etc/packages/adobe/cq60/core.wcm.components.config-2.3.2.zip       # dependent on zeppelin_complete
    /etc/packages/adobe/cq60/core.wcm.components.content-2.3.2.zip      # dependent on zeppelin_complete

    /etc/packages/wcm-io/io.wcm.caconfig.editor.package-1.8.2.zip

    /etc/packages/zeppelin/zeppelin-system-2.0.1.zip
)
transfer_package_paths1=(
    /etc/packages/zeppelin/zeppelin_complete-4.10.0-SNAPSHOT.zip    # INSTALL FIRST required for other pkgs
    /etc/packages/zeppelin/zeppelin-config-package-4.10.0-SNAPSHOT.zip
    /etc/packages/zeppelin/zeppelin-elastic-package-4.10.0-SNAPSHOT.zip
    /etc/packages/zeppelin/zeppelin-overlay-package-4.10.0-SNAPSHOT.zip
    /etc/packages/zeppelin/zeppelin-package-4.10.0-SNAPSHOT.zip
)

#####################################################################################
## THIRD ROUND TRIAL 09.08 ...
# Installed only zeppelin-system-2.0.2-SNAPSHOT manually from a local build, which is
# currently working. Already available, but not yet installed are the aecu v3.3.0 
# bundle, and acs-aem-commons-content-4.11.2.zip. Manually installed both on 13 Aug @
# 11:00 CEST.
# 
# After identifying errors that "CONTENT-READER" was missing, generated a special pkg
# from STAGE, "zeppelin-system-users" with filter /home/users/system/zep-system/ -- 
# includes only these users, and installed this prior to the zeppelin_complete
# packages.
# 
# Skipping "cq60" on this trial run.
transfer_package_paths0=(

# Included with acs-aem-commons-content-4.11.2.zip
#   /etc/packages/adobe/consulting/acs-aem-commons-ui.apps-4.11.2.zip
#   /etc/packages/adobe/consulting/acs-aem-commons-ui.content-4.11.2.zip

# Included with aecu.bundle-3.3.0.zip
# /etc/packages/ICF Next/aem-groovy-console-14.0.0.zip
# /etc/packages/Valtech/aecu.ui.apps-3.3.0.zip (runmode conflict prevents some js's from installing)

#   /etc/packages/adobe/cq60/core.wcm.components.all-2.3.2.zip          # dependent on zeppelin_complete
#   /etc/packages/adobe/cq60/core.wcm.components.config-2.3.2.zip       # dependent on zeppelin_complete
#   /etc/packages/adobe/cq60/core.wcm.components.content-2.3.2.zip      # dependent on zeppelin_complete

#   /etc/packages/wcm-io/io.wcm.caconfig.editor.package-1.8.2.zip

#   /etc/packages/zeppelin/zeppelin-system-2.0.1.zip
)
transfer_package_paths1=(
    /etc/packages/zeppelin/zeppelin_complete-4.10.0-SNAPSHOT.zip    # INSTALL FIRST required for other pkgs
    /etc/packages/zeppelin/zeppelin-config-package-4.10.0-SNAPSHOT.zip
    /etc/packages/zeppelin/zeppelin-elastic-package-4.10.0-SNAPSHOT.zip
    /etc/packages/zeppelin/zeppelin-overlay-package-4.10.0-SNAPSHOT.zip
    /etc/packages/zeppelin/zeppelin-package-4.10.0-SNAPSHOT.zip
)


#####################################################################################
## FOURTH TRIAL 30.08 ...
# Installed only zeppelin_complete-4.12.0 to resolve dependency issue in the 4.10 pkg
transfer_package_paths0=(
    /etc/packages/zeppelin/zeppelin_complete-4.12.0-SNAPSHOT.zip    # includes subpackages
)

## Preflight Checks _____
if [[ $USER != "root" ]] 
then
    error 1 "must be run by the superuser to mount s3 fuse filesystem"
fi


## Main Run _____

cq_port='4502'
date_filter="${1:-.}"
source_zenv="${zenv}"
aws_region="${3:-eu-central-1}"
source_aem_node="${4:-author0}"

bucket='zeppelincom-aem-backup'
remote_aem_username='admin'
remote_credentials='ryder.dain:+75=dLP~&hh]ZwJp'
local_credentials="$(get_credentials)"
tempmount=$(mktemp -d) && chmod 0777 $tempmount

timestamp="$(date +"%Y%m%d%H%M")"

# Assume we follow a zenv/node/timestamp format for keys; default to use from LIVE backups
temp_source="$tempmount/$source_zenv/$source_aem_node/"

# Literal IP here used to 
ams_author_ip='10.156.8.101' # "Integration-65" env Author
destination="https://$ams_author_ip:443"

trap "fusermount -u $tempmount ; rmdir $tempmount" 1 2 3 15 # cleanup after use on any error

log "Source: ${source_zenv}"
log "Destination: ${destination} (AMS)"

s3fs $bucket $tempmount -o dbglevel=info -o curldbg -o endpoint=$aws_region -o allow_other -o iam_role=auto

for package_path in "${transfer_package_paths0[@]}"
do
    package="$(basename $package_path)"
    path="$(dirname $package_path)"

    echo "Building $aem_node $package ..."
    curl -s -w '\n' -u "$local_credentials" -X "POST" \
        "http://localhost6:${cq_port}/crx/packmgr/service/.json${path}/${package}?cmd=build"

    echo "Backing up $aem_node $package ..."
    curl -s -u "$local_credentials" "http://localhost6:${cq_port}${path}/${package}" \
        | aws s3 cp - s3://${bucket}/${zenv}/${aem_node}/${timestamp}/${package}

    aws s3api put-object-acl \
        --bucket "${bucket}" \
        --key "${zenv}/${aem_node}/${timestamp}/${package}" \
        --acl bucket-owner-full-control

    latest_backup="$( \
        find $temp_source \
            -type f \
            -name "$package" \
            -printf "%T@ %p\n" \
        | sort -n \
        | grep "${date_filter}" \
        | cut -d' ' -f 2- \
        | tail -n 1
    )"

    printf "Using backup file %s\n" "$latest_backup"
    if [[ $(stat -c %s $latest_backup) -eq 0 ]]; then
        error 2 "Package $latest_backup is empty!"
    fi

    printf "Uploading %s...\n" "$package"
    curl -s -k -w '\n- Sent %{size_upload} bytes in %{speed_upload} bytes/sec\n- Spent %{time_total}s connected\n' \
         -u "$remote_credentials" \
         -F package=@"$latest_backup" \
         -F filename=${package} \
         -F force=true "${destination}/crx/packmgr/service/exec.json?cmd=upload"

    printf "Installing %s...\n" "$package"
    curl -s -k -w '\n- Spent %{time_total}s connected\n' \
         -u "$remote_credentials" \
         -X "POST" "${destination}/crx/packmgr/service/.json${path}/${package}?cmd=install" 

    printf "Processed %s.\n" "$package"
done | log

# Clean up
fusermount -u $tempmount
rmdir $tempmount
cat "$_LOGFILE" >> "${aem_path}/crx-quickstart/logs/send2adobe.log"
rm "$_LOGFILE"

exit 0
