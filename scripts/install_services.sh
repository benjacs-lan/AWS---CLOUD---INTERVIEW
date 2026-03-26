#!/bin/bash

# Actualizar sistema
apt-get update -y
apt-get upgrade -y

# Instalar NGINX (Webserver)
apt-get install nginx -y
systemctl start nginx
systemctl enable nginx

# Instalar Docker
apt-get install docker.io -y
systemctl start docker
systemctl enable docker
usermod -aG docker ubuntu

# Instalar y configurar el agentee CloudWatch
wget https://s3.us-east-1.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
dpkg -i -E ./amazon-cloudwatch-agent.deb

# --- CONFIGURACION DE CLOUDWATCH AGENT ---
# Creamos el archivo JSON de configuración directamente dentro de la máquina EC2
cat << 'EOF' > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
{
  "agent": {
    "run_as_user": "root"
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/nginx/access.log",
            "log_group_name": "/aws/ec2/self-healing-app/nginx",
            "log_stream_name": "{instance_id}-access"
          },
          {
            "file_path": "/var/log/nginx/error.log",
            "log_group_name": "/aws/ec2/self-healing-app/nginx",
            "log_stream_name": "{instance_id}-error"
          }
        ]
      }
    }
  }
}
EOF

# Iniciamos el agente cargándole este archivo de configuración
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
# -----------------------------------------

# Weeb basica para probar el funcionamiento
echo "<h1>Self-Headling Cloud</h1>" > /var/www/html/index.html