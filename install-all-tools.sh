#!/bin/bash
# ════════════════════════════════════════════════════════════════
#  install-all-tools.sh
#  Run this script ONCE on a fresh Ubuntu 22.04 EC2 instance.
#
#  Usage:
#    chmod +x install-all-tools.sh
#    sudo ./install-all-tools.sh
#
#  What it installs:
#    Java 17, Maven, Jenkins, SonarQube, Apache Tomcat, JFrog
# ════════════════════════════════════════════════════════════════

set -e   # stop on first error
echo ""
echo "╔══════════════════════════════════════════╗"
echo "║   Calculator_web_app/CD Tool Installer         ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# ── 0. Update system ────────────────────────────────────────────
echo "▶  Step 0: Updating system packages..."
apt-get update -y && apt-get upgrade -y
apt-get install -y wget curl unzip git nano

# ── 1. Java 17 ──────────────────────────────────────────────────
echo ""
echo "▶  Step 1: Installing Java 17..."
apt-get install -y openjdk-17-jdk
java -version
export JAVA_HOME=$(dirname $(dirname $(readlink -f $(which java))))
echo "JAVA_HOME=$JAVA_HOME"
echo "export JAVA_HOME=$JAVA_HOME" >> /etc/environment
echo "export PATH=\$PATH:\$JAVA_HOME/bin" >> /etc/environment

# ── 2. Maven ────────────────────────────────────────────────────
echo ""
echo "▶  Step 2: Installing Maven..."
apt-get install -y maven
mvn -version

# ── 3. Jenkins ──────────────────────────────────────────────────
echo ""
echo "▶  Step 3: Installing Jenkins..."
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key \
  | tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null

echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
  https://pkg.jenkins.io/debian-stable binary/" \
  | tee /etc/apt/sources.list.d/jenkins.list > /dev/null

apt-get update -y
apt-get install -y jenkins

systemctl start jenkins
systemctl enable jenkins

echo ""
echo "  ✅  Jenkins installed!"
echo "  📋  Initial admin password:"
cat /var/lib/jenkins/secrets/initialAdminPassword
echo ""
echo "  🌐  Open: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8080"

# ── 4. SonarQube ────────────────────────────────────────────────
echo ""
echo "▶  Step 4: Installing SonarQube 10.x..."

# Required kernel settings
sysctl -w vm.max_map_count=262144
sysctl -w fs.file-max=65536
echo "vm.max_map_count=262144" >> /etc/sysctl.conf
echo "fs.file-max=65536"       >> /etc/sysctl.conf

# Create sonar system user (can't run as root)
useradd --system --no-create-home --shell /bin/false sonar || true

cd /opt
SONAR_VERSION="10.3.0.82913"
wget -q "https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-${SONAR_VERSION}.zip"
unzip -q "sonarqube-${SONAR_VERSION}.zip"
mv "sonarqube-${SONAR_VERSION}" sonarqube
chown -R sonar:sonar /opt/sonarqube
rm "sonarqube-${SONAR_VERSION}.zip"

# Create systemd service
cat > /etc/systemd/system/sonarqube.service << 'EOF'
[Unit]
Description=SonarQube service
After=network.target

[Service]
Type=forking
ExecStart=/opt/sonarqube/bin/linux-x86-64/sonar.sh start
ExecStop=/opt/sonarqube/bin/linux-x86-64/sonar.sh stop
User=sonar
Group=sonar
Restart=always
LimitNOFILE=65536
LimitNPROC=4096

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable sonarqube
systemctl start sonarqube

echo "  ✅  SonarQube starting (takes ~2 min)..."
echo "  🌐  Open: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):9000"
echo "  🔑  Default login: admin / admin  (change on first login)"

# ── 5. Apache Tomcat ────────────────────────────────────────────
echo ""
echo "▶  Step 5: Installing Apache Tomcat 10..."

cd /opt
TOMCAT_VERSION="10.1.17"
wget -q "https://dlcdn.apache.org/tomcat/tomcat-10/v${TOMCAT_VERSION}/bin/apache-tomcat-${TOMCAT_VERSION}.tar.gz"
tar -xzf "apache-tomcat-${TOMCAT_VERSION}.tar.gz"
mv "apache-tomcat-${TOMCAT_VERSION}" tomcat
chmod +x /opt/tomcat/bin/*.sh
rm "apache-tomcat-${TOMCAT_VERSION}.tar.gz"

# ---- Change port 8080 → 8090 (Jenkins uses 8080) ----
sed -i 's/port="8080"/port="8090"/' /opt/tomcat/conf/server.xml

# ---- Add deploy user ----
# Insert before the closing tag
sed -i 's|</tomcat-users>|<role rolename="manager-gui"/>\n<role rolename="manager-script"/>\n<user username="deployer" password="deployer123" roles="manager-gui,manager-script"/>\n</tomcat-users>|' \
  /opt/tomcat/conf/tomcat-users.xml

# ---- Allow remote connections to manager app ----
# Comment out the IP restriction valve
sed -i 's|<Valve className="org.apache.catalina.valves.RemoteAddrValve"|<!-- <Valve className="org.apache.catalina.valves.RemoteAddrValve"|g' \
  /opt/tomcat/webapps/manager/META-INF/context.xml
sed -i 's|allow="127\\\.\\d+\\\.\\d+\\\.\\d+\|::1\|0:0:0:0:0:0:0:1" />|allow="127\\.\\d+\\.\\d+\\.\\d+\|::1\|0:0:0:0:0:0:0:1" /> -->|g' \
  /opt/tomcat/webapps/manager/META-INF/context.xml

# ---- Create systemd service ----
cat > /etc/systemd/system/tomcat.service << 'EOF'
[Unit]
Description=Apache Tomcat
After=network.target

[Service]
Type=forking
Environment=JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
Environment=CATALINA_HOME=/opt/tomcat
ExecStart=/opt/tomcat/bin/startup.sh
ExecStop=/opt/tomcat/bin/shutdown.sh
User=root
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable tomcat
systemctl start tomcat

echo "  ✅  Tomcat installed on port 8090!"
echo "  🌐  Open: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8090"

# ── 6. JFrog Artifactory OSS ────────────────────────────────────
echo ""
echo "▶  Step 6: Installing JFrog Artifactory OSS..."

# Add JFrog GPG key and repo
wget -qO - https://releases.jfrog.io/artifactory/api/gpg/key/public \
  | apt-key add - 2>/dev/null

echo "deb https://releases.jfrog.io/artifactory/artifactory-debs xenial contrib" \
  | tee /etc/apt/sources.list.d/artifactory.list

apt-get update -y
apt-get install -y jfrog-artifactory-oss

systemctl enable artifactory
systemctl start artifactory

echo "  ✅  Artifactory starting (takes ~2 min)..."
echo "  🌐  Open: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8082"
echo "  🔑  Default login: admin / password"

# ── Summary ─────────────────────────────────────────────────────
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║                   INSTALLATION COMPLETE                  ║"
echo "╠══════════════════════════════════════════════════════════╣"
echo "║  Tool             URL                                    ║"
echo "╠══════════════════════════════════════════════════════════╣"
printf "║  Jenkins          http://%-34s ║\n"  "$PUBLIC_IP:8080"
printf "║  SonarQube        http://%-34s ║\n"  "$PUBLIC_IP:9000"
printf "║  Tomcat           http://%-34s ║\n"  "$PUBLIC_IP:8090"
printf "║  JFrog Artifactory http://%-33s ║\n" "$PUBLIC_IP:8082"
echo "╠══════════════════════════════════════════════════════════╣"
echo "║  IMPORTANT: Open these ports in AWS Security Group!      ║"
echo "║  8080 (Jenkins), 9000 (Sonar), 8090 (Tomcat),           ║"
echo "║  8082 (Artifactory)                                      ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
echo "Jenkins initial admin password:"
cat /var/lib/jenkins/secrets/initialAdminPassword
echo ""
