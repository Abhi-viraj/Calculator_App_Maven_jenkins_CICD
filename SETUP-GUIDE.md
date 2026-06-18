# 🚀 Calculator_web_app Pipeline — Complete Setup Guide

**Source repo:** `https://github.com/maping/java-maven-calculator-web-app`
**Your fork:** `https://github.com/YOUR_GITHUB_USERNAME/FancyStore`

---

## 📁 Files in This Package

| File | Purpose |
|------|---------|
| `pom.xml` | Updated Maven build file — adds JaCoCo, SonarQube config, renames WAR to `FancyStore.war` |
| `sonar-project.properties` | SonarQube scanner config (place in project root) |
| `jenkins-job-config.xml` | Jenkins job XML — import to create `CI_FancyStore` job |
| `install-all-tools.sh` | One-shot installer for all tools on Ubuntu EC2 |
| `jenkins-plugins.txt` | All required Jenkins plugins |
| `SETUP-GUIDE.md` | This file |

---

## 🗺️ Pipeline Flow

```
Developer pushes code to GitHub
           │
           ▼  (Webhook POST)
     Jenkins CI_FancyStore Job
           │
           ▼
    Maven: clean compile test
           │
           ▼
    Maven: verify  ──────────► JaCoCo XML/HTML Report
           │                   target/site/jacoco/
           ▼
    Maven: package ──────────► FancyStore.war
           │                   target/FancyStore.war
           ▼
    Maven: sonar:sonar ──────► SonarQube Dashboard
           │                   (code quality + coverage)
           ▼
   [POST BUILD ACTIONS]
           │
           ├──────────────────► JFrog Artifactory
           │                   libs-release-local/
           │
           └──────────────────► Apache Tomcat :8090
                               http://EC2:8090/FancyStore
```

---

## PHASE 0 — AWS Setup

### 1. Launch EC2 Instance
- AMI: **Ubuntu 22.04 LTS**
- Instance type: **t2.large** (2 vCPU, 8 GB RAM — needed for all tools)
- Storage: **30 GB**
- Key pair: create or use existing `.pem`

### 2. Open Ports (Security Group → Inbound Rules)

| Port | Protocol | Source | Purpose |
|------|----------|--------|---------|
| 22 | TCP | Your IP | SSH |
| 8080 | TCP | 0.0.0.0/0 | Jenkins |
| 9000 | TCP | 0.0.0.0/0 | SonarQube |
| 8082 | TCP | 0.0.0.0/0 | JFrog Artifactory |
| 8090 | TCP | 0.0.0.0/0 | Apache Tomcat |

---

## PHASE 1 — Install All Tools

### SSH into EC2
```bash
ssh -i your-key.pem ubuntu@<EC2-PUBLIC-IP>
```

### Run the installer script
```bash
# Upload the script to EC2 first
scp -i your-key.pem install-all-tools.sh ubuntu@<EC2-IP>:~

# SSH in and run it
ssh -i your-key.pem ubuntu@<EC2-IP>
chmod +x install-all-tools.sh
sudo ./install-all-tools.sh
```

The script installs and starts:
- ✅ Java 17
- ✅ Maven 3
- ✅ Jenkins (port 8080)
- ✅ SonarQube (port 9000)
- ✅ Apache Tomcat (port 8090)
- ✅ JFrog Artifactory (port 8082)

---

## PHASE 2 — Fork & Prepare the Repository

### 1. Fork the repo on GitHub
1. Go to `https://github.com/maping/java-maven-calculator-web-app`
2. Click **Fork** → fork to your account
3. Rename the fork to `FancyStore` (Settings → Repository name)

### 2. Replace files with the ones from this package
```bash
# Clone your fork locally
git clone https://github.com/YOUR_USERNAME/FancyStore.git
cd FancyStore

# Copy updated files into the project
cp /path/to/package/pom.xml .
cp /path/to/package/sonar-project.properties .

# Edit pom.xml — replace YOUR_GITHUB_USERNAME with your actual username
nano pom.xml
# Find and replace:  YOUR_GITHUB_USERNAME  → your real GitHub username

# Commit and push
git add pom.xml sonar-project.properties
git commit -m "Add JaCoCo, SonarQube config; rename artifact to FancyStore"
git push origin main
```

---

## PHASE 3 — Initial Tool Configuration

### A. Jenkins First-Time Setup
1. Open `http://<EC2-IP>:8080`
2. Paste the initial admin password (shown at end of install script)
3. Click **Install suggested plugins**
4. Create an admin user
5. Click **Save and Finish**

### B. Install Required Jenkins Plugins
1. **Manage Jenkins** → **Plugins** → **Available plugins**
2. Search and install each plugin from `jenkins-plugins.txt`:
   - Git Plugin
   - GitHub Integration Plugin
   - Maven Integration Plugin
   - SonarQube Scanner Plugin
   - JaCoCo Plugin
   - Artifactory Plugin
   - Deploy to container Plugin
3. Click **Install** → tick **Restart after install**

### C. Configure Maven in Jenkins
1. **Manage Jenkins** → **Tools** → Scroll to **Maven**
2. Click **Add Maven**
   - Name: `Maven3`  ← must be exactly this
   - ✅ Install automatically → pick latest 3.9.x
3. **Save**

### D. Add GitHub Credentials in Jenkins
1. **Manage Jenkins** → **Credentials** → **(global)** → **Add Credentials**
   - Kind: **Username with password**
   - Username: `your-github-username`
   - Password: `your-github-personal-access-token`
     > Create token: GitHub → Settings → Developer Settings →
     > Personal Access Tokens → Tokens (classic) → Generate →
     > tick **repo** scope → copy it
   - ID: `github-creds`  ← must be exactly this
2. **Create**

### E. Add Tomcat Credentials in Jenkins
1. **Manage Jenkins** → **Credentials** → **(global)** → **Add Credentials**
   - Kind: **Username with password**
   - Username: `deployer`
   - Password: `deployer123`
   - ID: `tomcat-creds`  ← must be exactly this
2. **Create**

### F. Configure SonarQube Server in Jenkins
1. **Manage Jenkins** → **System** → find **SonarQube servers**
2. ✅ Check **Enable injection of SonarQube server config as build env vars**
3. Click **Add SonarQube**:
   - Name: `SonarQube`  ← must be exactly this
   - Server URL: `http://localhost:9000`
   - Server authentication token:
     - First, get a token from SonarQube:
       - Open `http://<EC2-IP>:9000` → login (admin/admin, change password)
       - Top right → **My Account** → **Security**
       - Generate token: Name=`jenkins-token`, Type=`Global Analysis Token`
       - **Copy the token!**
     - Back in Jenkins: Click **Add** → **Jenkins**
       - Kind: **Secret text**
       - Secret: paste the token
       - ID: `sonar-token`
     - Select `sonar-token` from the dropdown
4. **Save**

### G. Configure JFrog Artifactory in Jenkins
1. **Manage Jenkins** → **System** → find **JFrog**
2. Click **Add JFrog Platform Instance**:
   - Instance ID: `artifactory-server`  ← must be exactly this
   - JFrog Platform URL: `http://localhost:8082`
   - Default Deployer Credentials:
     - Username: `admin`
     - Password: `password` (or your new Artifactory password)
3. Click **Test Connection** → should show green ✅
4. **Save**

### H. Create Artifactory Repository
1. Open `http://<EC2-IP>:8082` → login (admin/password)
2. Complete setup wizard → skip proxy
3. **Administration** → **Repositories** → **Add Repositories** → **Local**
4. Package Type: **Maven**
5. Repository Key: `libs-release-local`
6. Click **Save & Finish**
7. Repeat for `libs-snapshot-local` (same steps, different name)

---

## PHASE 4 — Create the Jenkins Job

### Method A: Import via XML (Fastest)
```bash
# On EC2, create job directory
sudo mkdir -p /var/lib/jenkins/jobs/CI_FancyStore

# Copy the config file
sudo cp jenkins-job-config.xml \
  /var/lib/jenkins/jobs/CI_FancyStore/config.xml

# Fix ownership
sudo chown -R jenkins:jenkins \
  /var/lib/jenkins/jobs/CI_FancyStore

# Reload Jenkins
sudo systemctl restart jenkins
```

**Then edit the XML to put your GitHub username:**
```bash
sudo nano /var/lib/jenkins/jobs/CI_FancyStore/config.xml
# Replace all 3 occurrences of YOUR_GITHUB_USERNAME
```

### Method B: Create via UI (Manual)
1. Jenkins → **New Item**
2. Name: `CI_FancyStore`  ← exact name required
3. Type: **Maven project**
4. Click **OK**

Then configure each section:

**Source Code Management:**
- Select **Git**
- URL: `https://github.com/YOUR_USERNAME/FancyStore.git`
- Credentials: select `github-creds`
- Branch: `*/main`

**Build Triggers:**
- ✅ **GitHub hook trigger for GITScm polling**

**Build Environment:**
- ✅ **Prepare SonarQube Scanner environment**

**Build (Maven Goals):**
- Root POM: `pom.xml`
- Goals:
  ```
  clean compile test verify package sonar:sonar
  ```

**Post-build Actions — add three:**

1. **Record JaCoCo coverage report** → leave all defaults

2. **Deploy Artifacts to Artifactory**
   - Server: `artifactory-server`
   - Release repo: `libs-release-local`
   - Snapshot repo: `libs-snapshot-local`
   - Include: `**/FancyStore.war`

3. **Deploy war/ear to a container**
   - WAR files: `target/FancyStore.war`
   - Context path: `FancyStore`
   - Container: **Tomcat 9.x Remote**
     - Manager URL: `http://localhost:8090/manager/text`
     - Credentials: `tomcat-creds`

Click **Save** ✅

---

## PHASE 5 — Set Up GitHub Webhook

### 1. Get your Jenkins webhook URL
```
http://<YOUR-EC2-PUBLIC-IP>:8080/github-webhook/
```

### 2. Add webhook in GitHub
1. Go to your `FancyStore` GitHub repo
2. **Settings** → **Webhooks** → **Add webhook**
3. Fill in:
   - **Payload URL**: `http://<EC2-IP>:8080/github-webhook/`
   - **Content type**: `application/json`
   - **Which events**: Just the **push** event
   - ✅ **Active**
4. Click **Add webhook**
5. GitHub will show a ✅ green tick if Jenkins responded

> ⚠️ If you see a red ✗ (failed delivery), check:
> - Port 8080 is open in AWS Security Group
> - Jenkins is running: `sudo systemctl status jenkins`

---

## PHASE 6 — Test the Pipeline

### Trigger manually first
1. Jenkins → `CI_FancyStore` → **Build Now**
2. Click build number → **Console Output**
3. Watch the full output — it should end with:
```
[INFO] BUILD SUCCESS
...
INFO: ANALYSIS SUCCESSFUL
...
Deploying artifact: FancyStore.war to Artifactory
...
Deploying to Tomcat: http://localhost:8090/FancyStore
```

### Trigger via GitHub push (webhook test)
```bash
# On your local machine
cd FancyStore
echo "# pipeline test" >> README.md
git add README.md
git commit -m "Test webhook trigger"
git push origin main

# Watch Jenkins — build should start within seconds!
```

---

## PHASE 7 — Verify Everything

| What | Where | Expected |
|------|-------|----------|
| Build result | Jenkins → CI_FancyStore → Last build | ✅ Blue ball (success) |
| Unit tests | Jenkins → Build → Test Result | All tests passed |
| Coverage report | Jenkins → Build → Coverage Report | Shows % coverage |
| Code quality | `http://<EC2-IP>:9000` → Projects | FancyStore project visible |
| Coverage in Sonar | SonarQube → FancyStore → Coverage | Shows % |
| WAR in Artifactory | `http://<EC2-IP>:8082` → libs-release-local | FancyStore.war present |
| App on Tomcat | `http://<EC2-IP>:8090/FancyStore` | Calculator app loads |

---

## 🆘 Troubleshooting

| Problem | Fix |
|---------|-----|
| Jenkins initial page not loading | Wait 2 min; check `sudo systemctl status jenkins` |
| SonarQube not loading | Takes ~3 min to start; check `sudo systemctl status sonarqube` |
| `BUILD FAILURE: sonar:sonar` | Check SonarQube token in Jenkins credentials |
| Tomcat deploy fails | Check `tomcat-users.xml` has deployer user; restart Tomcat |
| `FancyStore.war not found` | Check `<finalName>FancyStore</finalName>` in pom.xml |
| Webhook not triggering build | Port 8080 open? Check GitHub webhook delivery log |
| Artifactory upload fails | Check Instance ID = `artifactory-server`; test connection |
| `t2.micro` out of memory | Upgrade to `t2.large`; SonarQube + Artifactory need RAM |

---

## 📌 Quick Reference — All URLs

```
Jenkins      →  http://<EC2-IP>:8080   (admin / your-password)
SonarQube    →  http://<EC2-IP>:9000   (admin / your-password)
Tomcat       →  http://<EC2-IP>:8090   (deployer / deployer123)
Artifactory  →  http://<EC2-IP>:8082   (admin / password)
Your App     →  http://<EC2-IP>:8090/FancyStore
```
