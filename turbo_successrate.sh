#!/usr/bin/env bash
#A StorJ node monitor script: Contains code contributed by: peem, BrightSilence, turbostorjdsk / KernelPanick, Alexey

#Don't forget - make the script executable: chmod +x turbo_successrate.sh

LOG_SOURCE="$*"

if [ -e "${1}" ]
then
	# the first argument is passed and it's an existing log file
	LOG_COMMAND="cat ${LOG_SOURCE}"
else
	# assumes your docker container is named 'storagenode'. If not, pass it as the first argument, e.g.:
	# bash turbo_successrate.sh mynodename
	DOCKER_NODE_NAME="${1:-storagenode}"
	LOG_COMMAND="docker logs $DOCKER_NODE_NAME"
fi

echo -e "\e[93mCalculating, please wait...\e[0m"
START_TIME=$(date +%s) # Get start time in seconds

# Use a single AWK call to process everything
$LOG_COMMAND 2>&1 | awk '
BEGIN {
    # Initialize variables
    audit_success = 0; audit_failed_warn = 0; audit_failed_crit = 0;
    dl_success = 0; dl_canceled = 0; dl_failed = 0;
    put_success = 0; put_rejected = 0; put_canceled = 0; put_failed = 0;
    get_repair_success = 0; get_repair_failed = 0; get_repair_canceled = 0;
    put_repair_success = 0; put_repair_canceled = 0; put_repair_failed = 0;
    delete_success = 0; delete_failed = 0;
}

# Main line processing logic
{
    if ($0 ~ /GET_AUDIT/) {
        if ($0 ~ /downloaded/) { audit_success++; }
        else if ($0 ~ /failed/) {
            if ($0 ~ /exist/) { audit_failed_crit++; }
            else { audit_failed_warn++; }
        }
    } else if ($0 ~ /"GET"/) {
        if ($0 ~ /downloaded/) { dl_success++; }
        else if ($0 ~ /download canceled/) { dl_canceled++; }
        else if ($0 ~ /download failed/) { dl_failed++; }
    } else if ($0 ~ /"PUT"/) {
        if ($0 ~ /uploaded/) { put_success++; }
        else if ($0 ~ /upload canceled/) { put_canceled++; }
        else if ($0 ~ /upload failed/) { put_failed++; }
    } else if ($0 ~ /upload rejected/) {
        put_rejected++;
    } else if ($0 ~ /GET_REPAIR/) {
        if ($0 ~ /downloaded/) { get_repair_success++; }
        else if ($0 ~ /download failed/) { get_repair_failed++; }
        else if ($0 ~ /download canceled/) { get_repair_canceled++; }
    } else if ($0 ~ /PUT_REPAIR/) {
        if ($0 ~ /uploaded/) { put_repair_success++; }
        else if ($0 ~ /upload canceled/) { put_repair_canceled++; }
        else if ($0 ~ /upload failed/) { put_repair_failed++; }
    } else if ($0 ~ /deleted|delete piece/) {
        delete_success++;
    } else if ($0 ~ /delete failed/) {
        delete_failed++;
    }
}

# END block - executed after all lines are processed
END {
    LABEL_WIDTH=23

    # --- AUDIT ---
    print "\n\033[96m========== AUDIT ============== \033[0m";
    total_audits = audit_success + audit_failed_crit + audit_failed_warn;
    printf "\033[91m%-*s%d \033[0m\n", LABEL_WIDTH, "Critically failed:", audit_failed_crit;
    printf "%-*s%.3f%%\n", LABEL_WIDTH, "Critical Fail Rate:", (total_audits >= 1 ? (audit_failed_crit / total_audits) * 100 : 0.000);
    printf "\033[33m%-*s%d \033[0m\n", LABEL_WIDTH, "Recoverable failed:", audit_failed_warn;
    printf "%-*s%.3f%%\n", LABEL_WIDTH, "Recoverable Fail Rate:", (total_audits >= 1 ? (audit_failed_warn / total_audits) * 100 : 0.000);
    printf "\033[92m%-*s%d \033[0m\n", LABEL_WIDTH, "Successful:", audit_success;
    printf "%-*s%.3f%%\n", LABEL_WIDTH, "Success Rate:", (total_audits >= 1 ? (audit_success / total_audits) * 100 : 0.000);

    # --- DOWNLOAD ---
    print "\n\033[96m========== DOWNLOAD =========== \033[0m";
    total_downloads = dl_success + dl_failed + dl_canceled;
    printf "\033[91m%-*s%d \033[0m\n", LABEL_WIDTH, "Failed:", dl_failed;
    printf "%-*s%.3f%%\n", LABEL_WIDTH, "Fail Rate:", (total_downloads >= 1 ? (dl_failed / total_downloads) * 100 : 0.000);
    printf "\033[33m%-*s%d \033[0m\n", LABEL_WIDTH, "Canceled:", dl_canceled;
    printf "%-*s%.3f%%\n", LABEL_WIDTH, "Cancel Rate:", (total_downloads >= 1 ? (dl_canceled / total_downloads) * 100 : 0.000);
    printf "\033[92m%-*s%d \033[0m\n", LABEL_WIDTH, "Successful:", dl_success;
    printf "%-*s%.3f%%\n", LABEL_WIDTH, "Success Rate:", (total_downloads >= 1 ? (dl_success / total_downloads) * 100 : 0.000);

    # --- UPLOAD ---
    print "\n\033[96m========== UPLOAD ============= \033[0m";
    total_uploads = put_success + put_rejected + put_canceled + put_failed;
    total_accepted_uploads = put_success + put_canceled + put_failed;
    printf "\033[33m%-*s%d \033[0m\n", LABEL_WIDTH, "Rejected:", put_rejected;
    printf "%-*s%.3f%%\n", LABEL_WIDTH, "Acceptance Rate:", (total_uploads >= 1 ? (total_accepted_uploads / total_uploads) * 100 : 0.000);
    print "\033[96m---------- accepted ----------- \033[0m";
    printf "\033[91m%-*s%d \033[0m\n", LABEL_WIDTH, "Failed:", put_failed;
    printf "%-*s%.3f%%\n", LABEL_WIDTH, "Fail Rate:", (total_accepted_uploads >= 1 ? (put_failed / total_accepted_uploads) * 100 : 0.000);
    printf "\033[33m%-*s%d \033[0m\n", LABEL_WIDTH, "Canceled:", put_canceled;
    printf "%-*s%.3f%%\n", LABEL_WIDTH, "Cancel Rate:", (total_accepted_uploads >= 1 ? (put_canceled / total_accepted_uploads) * 100 : 0.000);
    printf "\033[92m%-*s%d \033[0m\n", LABEL_WIDTH, "Successful:", put_success;
    printf "%-*s%.3f%%\n", LABEL_WIDTH, "Success Rate:", (total_accepted_uploads >= 1 ? (put_success / total_accepted_uploads) * 100 : 0.000);

    # --- REPAIR DOWNLOAD ---
    print "\n\033[96m========== REPAIR DOWNLOAD ==== \033[0m";
    total_get_repairs = get_repair_success + get_repair_failed + get_repair_canceled;
    printf "\033[91m%-*s%d \033[0m\n", LABEL_WIDTH, "Failed:", get_repair_failed;
    printf "%-*s%.3f%%\n", LABEL_WIDTH, "Fail Rate:", (total_get_repairs >= 1 ? (get_repair_failed / total_get_repairs) * 100 : 0.000);
    printf "\033[33m%-*s%d \033[0m\n", LABEL_WIDTH, "Canceled:", get_repair_canceled;
    printf "%-*s%.3f%%\n", LABEL_WIDTH, "Cancel Rate:", (total_get_repairs >= 1 ? (get_repair_canceled / total_get_repairs) * 100 : 0.000);
    printf "\033[92m%-*s%d \033[0m\n", LABEL_WIDTH, "Successful:", get_repair_success;
    printf "%-*s%.3f%%\n", LABEL_WIDTH, "Success Rate:", (total_get_repairs >= 1 ? (get_repair_success / total_get_repairs) * 100 : 0.000);

    # --- REPAIR UPLOAD ---
    print "\n\033[96m========== REPAIR UPLOAD ====== \033[0m";
    total_put_repairs = put_repair_success + put_repair_failed + put_repair_canceled;
    printf "\033[91m%-*s%d \033[0m\n", LABEL_WIDTH, "Failed:", put_repair_failed;
    printf "%-*s%.3f%%\n", LABEL_WIDTH, "Fail Rate:", (total_put_repairs >= 1 ? (put_repair_failed / total_put_repairs) * 100 : 0.000);
    printf "\033[33m%-*s%d \033[0m\n", LABEL_WIDTH, "Canceled:", put_repair_canceled;
    printf "%-*s%.3f%%\n", LABEL_WIDTH, "Cancel Rate:", (total_put_repairs >= 1 ? (put_repair_canceled / total_put_repairs) * 100 : 0.000);
    printf "\033[92m%-*s%d \033[0m\n", LABEL_WIDTH, "Successful:", put_repair_success;
    printf "%-*s%.3f%%\n", LABEL_WIDTH, "Success Rate:", (total_put_repairs >= 1 ? (put_repair_success / total_put_repairs) * 100 : 0.000);

    # --- DELETE ---
    print "\n\033[96m========== DELETE ============= \033[0m";
    total_deletes = delete_success + delete_failed;
    printf "\033[33m%-*s%d \033[0m\n", LABEL_WIDTH, "Failed:", delete_failed;
    printf "%-*s%.3f%%\n", LABEL_WIDTH, "Fail Rate:", (total_deletes >= 1 ? (delete_failed / total_deletes) * 100 : 0.000);
    printf "\033[92m%-*s%d \033[0m\n", LABEL_WIDTH, "Successful:", delete_success;
    printf "%-*s%.3f%%\n", LABEL_WIDTH, "Success Rate:", (total_deletes >= 1 ? (delete_success / total_deletes) * 100 : 0.000);
}'

END_TIME=$(date +%s) # Get end time in seconds
ELAPSED_TIME=$((END_TIME - START_TIME)) # Calculate elapsed time

echo -e "\n\e[93mScript execution time: ${ELAPSED_TIME} seconds.\e[0m"
