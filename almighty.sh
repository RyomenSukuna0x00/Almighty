#!/bin/bash

CYAN='\033[1;36m'
RESET='\033[0m'
GREEN='\033[0;32m'
NUCLEI_COLOR='\033[0;34m'

echo -e """${CYAN}
░█▀▀█ █░░ █▀▄▀█ ░▀░ █▀▀▀ █░░█ ▀▀█▀▀ █░░█ 
▒█▄▄█ █░░ █░▀░█ ▀█▀ █░▀█ █▀▀█ ░░█░░ █▄▄█ 
▒█░▒█ ▀▀▀ ▀░░░▀ ▀▀▀ ▀▀▀▀ ▀░░▀ ░░▀░░ ▄▄▄█${RESET}"""

echo -e "${GREEN}By Dhane Ashley Diabajo${RESET}"
echo ""

usage() {
    echo "Usage: $0 -d <target_domain> [-S] [-U] [-update]"
    exit 1
}

RUN_NUCLEI_FIRST_PART=false
RUN_NUCLEI_SECOND_PART=false
UPDATE_SCRIPT=false
TARGET_DOMAIN=""

# Loop to handle multi-character option -update
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -d) TARGET_DOMAIN="$2"; shift; shift ;;
        -S) RUN_NUCLEI_FIRST_PART=true; shift ;;
        -U) RUN_NUCLEI_SECOND_PART=true; shift ;;
        -update) UPDATE_SCRIPT=true; shift ;;
        *) usage ;;
    esac
done

# Check if target domain is provided
if [ -z "${TARGET_DOMAIN}" ] && [ "$UPDATE_SCRIPT" = false ]; then
    usage
fi

# Check for update if -update option is provided
if [ "$UPDATE_SCRIPT" = true ]; then
    if [ -d ".git" ]; then
        echo -e "${CYAN}Checking for updates...${RESET}"
        git fetch origin main
        LOCAL=$(git rev-parse HEAD)
        REMOTE=$(git rev-parse origin/main)
        
        if [ "$LOCAL" != "$REMOTE" ]; then
            echo -e "${GREEN}Update available. Pulling latest version...${RESET}"
            git pull origin main
            echo -e "${CYAN}Script updated successfully! Please re-run the script.${RESET}"
            exit 0
        else
            echo -e "${CYAN}Script is already up-to-date.${RESET}"
            exit 0
        fi
    else
        echo -e "${CYAN}This script is not in a Git repository, so it cannot be updated automatically.${RESET}"
        exit 1
    fi
fi

# Run Nuclei first part if -S option is provided
if [ "$RUN_NUCLEI_FIRST_PART" = true ]; then
    echo -e "${NUCLEI_COLOR}Running first part of Nuclei tests on $TARGET_DOMAIN...${RESET}"
    # Add actual nuclei commands or logic here
fi

# Run Nuclei second part if -U option is provided
if [ "$RUN_NUCLEI_SECOND_PART" = true ]; then
    echo -e "${NUCLEI_COLOR}Running second part of Nuclei tests on $TARGET_DOMAIN...${RESET}"
    # Add actual nuclei commands or logic here
fi
echo "test"
