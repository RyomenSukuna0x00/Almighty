# Subdomain Enumeration and Vulnerability Scanning Script

This script automates the process of subdomain enumeration and vulnerability scanning for a specified target domain. It integrates several tools to enhance your reconnaissance efforts.

## Tools Needed

### Prerequisites

Before running the script, ensure you have the following tools installed on your system:

1. **[Git](https://git-scm.com/downloads)**
   - Version Control System for managing source code.
   - **Installation:** Follow the installation instructions on the Git website.

2. **[Subfinder](https://github.com/projectdiscovery/subfinder)**
   - A subdomain discovery tool.
   - **Installation:** 
     ```bash
     go install github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
     ```

3. **[Anew](https://github.com/tomnomnom/anew)**
   - A tool for managing and appending unique lines to files.
   - **Installation:**
     ```bash
     go install github.com/tomnomnom/anew@latest
     ```

4. **[Httpx](https://github.com/projectdiscovery/httpx)**
   - A fast and multi-purpose HTTP toolkit for endpoints.
   - **Installation:**
     ```bash
     go install github.com/projectdiscovery/httpx/cmd/httpx@latest
     ```

5. **[Naabu](https://github.com/projectdiscovery/naabu)**
   - A tool for fast port scanning.
   - **Installation:**
     ```bash
     go install github.com/projectdiscovery/naabu/v2/cmd/naabu@latest
     ```

6. **[Nuclei](https://github.com/projectdiscovery/nuclei)**
   - A fast tool for configurable targeted scanning based on templates.
   - **Installation:**
     ```bash
     go install github.com/projectdiscovery/nuclei/v2/cmd/nuclei@latest
     ```

7. **[Subzy](https://github.com/lc/subzy)**
   - A tool for identifying subdomain takeovers.
   - **Installation:**
     ```bash
     go install github.com/lc/subzy@latest
     ```

8. **[Katana](https://github.com/projectdiscovery/katana)**
   - A fast web crawling and scraping tool.
   - **Installation:**
     ```bash
     go install github.com/projectdiscovery/katana/cmd/katana@latest
     ```

9. **[GAU](https://github.com/lc/gau)**
   - A tool for fetching all URLs from wayback archives.
   - **Installation:**
     ```bash
     go install github.com/lc/gau@latest
     ```

10. **[Waybackurls](https://github.com/tomnomnom/waybackurls)**
    - A tool for fetching all the URLs from the Wayback Machine.
    - **Installation:**
      ```bash
      go install github.com/tomnomnom/waybackurls@latest
      ```

11. **[LinkFinder](https://github.com/GerbenJavado/LinkFinder)**
    - A tool for finding endpoints in JavaScript files.
    - **Installation:**
      ```bash
      git clone https://github.com/GerbenJavado/LinkFinder.git
      cd LinkFinder
      pip install -r requirements.txt
      ```

12. **[GF](https://github.com/tomnomnom/gf)**
    - A tool for searching for specific patterns in URLs.
    - **Installation:**
      ```bash
      go install github.com/tomnomnom/gf@latest
      ```

## Usage

Run the script using the following command:

```bash
./script.sh -d <target_domain>
