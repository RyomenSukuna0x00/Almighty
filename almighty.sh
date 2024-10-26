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

while getopts ":d:SUupdate" opt; do
    case "${opt}" in
        d) TARGET_DOMAIN=${OPTARG} ;;
        S) RUN_NUCLEI_FIRST_PART=true ;;
        U) RUN_NUCLEI_SECOND_PART=true ;;
        update) UPDATE_SCRIPT=true ;;
        *) usage ;;
    esac
done

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

if [ -z "${TARGET_DOMAIN}" ]; then
    usage
fi

echo -e "${GREEN}Creating Subdomain Directory${RESET}"
mkdir -p Subdomains
echo -e "${CYAN}Complete${RESET}"

echo -e "${GREEN}Running Subfinder, Anew, and Httpx...${RESET}"
echo ${TARGET_DOMAIN} | subfinder -recursive -active -silent | anew | httpx -silent >> Subdomains/subdomains.txt
echo -e "${CYAN}Complete${RESET}"

echo -e "${GREEN}Running Httpx Scanning for sensitive files...${RESET}"
cat Subdomains/subdomains.txt | httpx -silent -path "/server-status" -mc 200 -title > Subdomains/httpx-Server-status.txt
cat Subdomains/subdomains.txt | httpx -silent -path "/phpinfo.php" -mc 200 -title > Subdomains/httpx-phpinfo.txt
cat Subdomains/subdomains.txt | httpx -silent -path "/.DS_Store" -mc 200 -title > Subdomains/httpx-DS_store.txt
cat Subdomains/subdomains.txt | httpx -silent -path "/.git" -mc 200 -title > Subdomains/httpx-git.txt
echo -e "${CYAN}Task Completed!${RESET}"

if [ "$RUN_NUCLEI_FIRST_PART" = true ] || ([ "$RUN_NUCLEI_FIRST_PART" = true ] && [ "$RUN_NUCLEI_SECOND_PART" = true ]); then
    echo -e "${GREEN}Running Nuclei for possible subdomain takeovers...${RESET}"
    cat Subdomains/subdomains.txt | nuclei -silent -t /$HOME/nuclei-templates/http/takeovers/*.yaml > Subdomains/nuclei/nuclei-subover.txt
    echo -e "${CYAN}Nuclei Subdomain Takeover Scan Completed!${RESET}"
fi

echo -e "${GREEN}Running Naabu...${RESET}"
cat Subdomains/subdomains.txt | naabu -v --passive -silent > Subdomains/ports.txt
echo -e "${CYAN}Task Completed!${RESET}"

source /$HOME/venv/bin/activate

mkdir -p urls

echo -e "${GREEN}Running Katana${RESET}"
echo "${TARGET_DOMAIN}" | katana -silent -d 5 -ps -pss waybackarchive,commoncrawl,alienvault > urls/katana.txt
echo -e "${GREEN}Task finished${RESET}"

echo -e "${GREEN}Running GAU${RESET}"
echo "${TARGET_DOMAIN}" | gau --subs > urls/gau.txt
echo -e "${GREEN}Task finished${RESET}"

echo -e "${GREEN}Running Waybackurls...${RESET}"
waybackurls "${TARGET_DOMAIN}" > urls/waybackurls.txt
echo -e "${GREEN}Task finished${RESET}"

echo -e "${GREEN}Combining all URLs${RESET}"
cat urls/katana.txt urls/gau.txt urls/waybackurls.txt > urls/final-clean.txt
echo -e "${GREEN}Task Completed${RESET}"

if [ "$RUN_NUCLEI_SECOND_PART" = true ] || ([ "$RUN_NUCLEI_FIRST_PART" = true ] && [ "$RUN_NUCLEI_SECOND_PART" = true ]); then
    mkdir -p urls/nuclei
    for year in {2000..2024}; do
        echo -e "${NUCLEI_COLOR}Running Nuclei template for year $year on URLs${RESET}"
        cat urls/final-clean.txt | nuclei -silent -rate-limit 200 -t /$HOME/nuclei-templates/http/cves/$year/*.yaml > urls/nuclei/nuclei-$year.txt
    done
    echo -e "${GREEN}Nuclei URL Scan Completed!${RESET}"
fi

echo -e "${GREEN}Process complete!${RESET}"
