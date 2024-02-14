#!/bin/bash
# Auther: Christo Deale
# Date:   2024-02-14
# tomcat_nginx_reverseproxy: Utility to setup Apache & Nginx as reverse proxy

# Install Java 17
sudo dnf install java-17-openjdk java-17-openjdk-devel -y

# Create Tomcat user and group
sudo groupadd tomcat
sudo adduser -r -s /usr/sbin/nologin -g tomcat -b /opt/tomcat tomcat

# Download and extract Apache Tomcat
export VERSION=10.1.18
wget https://dlcdn.apache.org/tomcat/tomcat-10/v${VERSION}/bin/apache-tomcat-${VERSION}.tar.gz
mkdir -p /opt/tomcat
sudo tar -xf apache-tomcat-${VERSION}.tar.gz -C /opt/tomcat
sudo ln -s /opt/tomcat/apache-tomcat-${VERSION} /opt/tomcat/latest
sudo chown -R tomcat:tomcat /opt/tomcat

# Create Tomcat systemd service file
sudo tee /etc/systemd/system/tomcat10.service <<EOL
[Unit]
Description=Tomcat 10 servlet container
After=network.target

[Service]
Type=forking
User=tomcat
Group=tomcat

Environment="JAVA_HOME=/usr/lib/jvm/java"
Environment="JAVA_OPTS=-Djava.security.egd=file:///dev/urandom -Djava.awt.headless=true"

Environment="CATALINA_BASE=/opt/tomcat/latest"
Environment="CATALINA_HOME=/opt/tomcat/latest"
Environment="CATALINA_PID=/opt/tomcat/latest/temp/tomcat.pid"
Environment="CATALINA_OPTS=-Xms512M -Xmx2048M -server -XX:+UseParallelGC"

ExecStart=/opt/tomcat/latest/bin/startup.sh
ExecStop=/opt/tomcat/latest/bin/shutdown.sh

[Install]
WantedBy=multi-user.target
EOL

# Reload systemd and start Tomcat
sudo systemctl daemon-reload
sudo systemctl enable tomcat10
sudo systemctl start tomcat10
sudo systemctl status tomcat10

# Open firewall port for Tomcat
sudo firewall-cmd --add-port=8080/tcp --permanent
sudo firewall-cmd --reload

# Prompt user for Tomcat admin password
read -p "Enter Tomcat admin password: " tomcat_password

# Configure Tomcat user authentication
sudo tee /opt/tomcat/latest/conf/tomcat-users.xml <<EOL
<tomcat-users>
    <!--
    user: admin pass: promptedpassword
    -->
    <role rolename="manager-gui"/>
    <role rolename="manager-script"/>
    <role rolename="manager-jmx"/>
    <role rolename="manager-status"/>
    <role rolename="admin-gui"/>
    <role rolename="admin-script"/>
    <user username="admin" password="${tomcat_password}" roles="manager-gui, manager-script, manager-jmx, manager-status, admin-gui, admin-script"/>
</tomcat-users>
EOL

# Restart Tomcat to apply changes
sudo systemctl restart tomcat10

# Install Nginx
sudo dnf install nginx -y

# Prompt user for server name
read -p "Enter server name (e.g., test.com): " server_name

# Configure Nginx as reverse proxy for Tomcat
sudo tee /etc/nginx/conf.d/tomcat.conf <<EOL
server {
    listen 80;
    server_name ${server_name};

    access_log /var/log/nginx/tomcat-access.log;
    error_log /var/log/nginx/tomcat-error.log;

    location / {
        proxy_set_header X-Forwarded-Host $host;
        proxy_set_header X-Forwarded-Server $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_pass http://127.0.0.1:8080/;
    }
}
EOL

# Test Nginx configuration and start Nginx
sudo nginx -t
sudo systemctl start nginx
sudo systemctl enable nginx
sudo systemctl status nginx

# Open firewall port for Nginx
sudo firewall-cmd --add-service=http --permanent
sudo firewall-cmd --reload

# Display firewall configuration
sudo firewall-cmd --list-all
