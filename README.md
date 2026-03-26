¡Excelente decisión\! Un README en un solo idioma se ve mucho más profesional y cohesionado. He traducido todas las secciones al español manteniendo la terminología técnica estándar (como *Launch Template*, *Auto Scaling Group*, etc., que se suelen dejar en inglés en el entorno técnico).

Aquí tienes tu README completamente unificado:

-----

# 🚀 Infraestructura Cloud con Self-Healing (Autorreparación)

Arquitectura en la nube básica, de alta disponibilidad (HA) y tolerante a fallos, usando herramientas IaC como **Terraform** en **AWS**. Diseñada con un paradigma de "autorreparación" para eliminar puntos únicos de fallo (SPOF) mediante grupos de escalado automático y balanceadores de carga de aplicaciones.

Actualmente está configurado para ser probado localmente usando **LocalStack** donde se utilizó **awslocal** y **tflocal**.

## 🏗️ Resumen de la Arquitectura

La VPC (Virtual Private Cloud) se extiende por dos zonas de disponibilidad (AZ). Los recursos informáticos se mantienen privados, mientras que el balanceador de carga de aplicaciones enruta el tráfico de internet de forma segura.

```mermaid
graph TD
    %% Definición de Clases de Estilo
    classDef aws fill:#232F3E,stroke:#fff,stroke-width:2px,color:#fff;
    classDef public fill:#d4e6f1,stroke:#2980b9,stroke-width:2px;
    classDef private fill:#fadbd8,stroke:#e74c3c,stroke-width:2px;
    classDef component fill:#f9e79f,stroke:#f39c12,stroke-width:2px;

    %% Nube de AWS y VPC
    subgraph AWS_Cloud ["☁️ AWS Cloud (Región us-east-1)"]
        IGW(("Internet Gateway")):::aws

        subgraph VPC ["VPC (10.0.0.0/16)"]
            ALB{"Application Load Balancer"}:::component
            ASG[["Auto Scaling Group (Desired: 2)"]]:::component

            subgraph AZ1 ["AZ 1 (us-east-1a)"]
                PUB1["Subred Pública 1"]:::public
                NAT1(("NAT Gateway")):::aws
                PRI1["Subred Privada App1"]:::private
                EC2_1("💻 Instancia EC2 1 (NGINX)"):::component
            end

            subgraph AZ2 ["AZ 2 (us-east-1b)"]
                PUB2["Subred Pública 2"]:::public
                PRI2["Subred Privada App2"]:::private
                EC2_2("💻 Instancia EC2 2 (NGINX)"):::component
            end

            %% Conexiones dentro de la VPC
            IGW -->|Tráfico de Internet| ALB
            ALB -->|HTTP Puerto 80| EC2_1
            ALB -->|HTTP Puerto 80| EC2_2

            %% Conexiones de Relación
            PUB1 -.- NAT1
            PUB1 -.- ALB
            PUB2 -.- ALB
            PRI1 -.- EC2_1
            PRI2 -.- EC2_2

            %% Tráfico de salida
            EC2_1 -->|Tráfico de salida (Actualizaciones)| NAT1
            EC2_2 -->|Tráfico de salida (Actualizaciones)| NAT1
        end

        %% Conexiones a servicios externos de la nube
        CW[("📊 Amazon CloudWatch Logs <br> /aws/ec2/self-healing-app/nginx")]:::aws
        EC2_1 -.->|Flujo de Logs de NGINX| CW
        EC2_2 -.->|Flujo de Logs de NGINX| CW
    end

    %% Conexiones de Auto Scaling
    ASG -.->|Monitorea Salud y Reemplaza Nodos| EC2_1
    ASG -.->|Monitorea Salud y Reemplaza Nodos| EC2_2

    %% Estilos de Contenedores
    style AWS_Cloud fill:#f4f6f7,stroke:#34495e,stroke-dasharray: 5 5
    style VPC fill:#eaeded,stroke:#7f8c8d
    style AZ1 fill:#ebeeeb,stroke:#bdc3c7
    style AZ2 fill:#ebeeeb,stroke:#bdc3c7
```

## ✨ Características Principales

  * **Aislamiento de Red:** La arquitectura segmenta la red en dos capas. La **subred pública** contiene el ALB y el NAT Gateway, gestionando el tráfico entrante de Internet de forma segura. Las instancias de la aplicación residen en la **subred privada**, sin exposición directa a Internet, maximizando la seguridad.
  * **Infraestructura Inmutable:** Las instancias EC2 se inicializan automáticamente a través de una **Launch Template** configurada con NGINX y el agente de CloudWatch.
  * **Autorreparación (Self-Healing):** Un **Auto Scaling Group** monitorea la salud de las instancias y reemplaza los nodos degradados automáticamente sin intervención humana.
  * **Distribución de Tráfico:** Un **Application Load Balancer (ALB)** enruta el tráfico estrictamente hacia los nodos en estado saludable.
  * **Seguridad Granular:** Cero acceso directo a Internet para las instancias EC2. Los Security Groups permiten el tráfico entrante única y exclusivamente desde el ALB.
  * **Observabilidad:** Registros (logs) centralizados a través de **CloudWatch**, extrayendo el archivo `/var/log/nginx/access.log` en tiempo real mediante el agente unificado de CloudWatch.

> **Nota sobre LocalStack:** Las APIs de ELBv2 y AutoScaling son características de la versión Pro en LocalStack. El código dentro de `main.tf` contiene la configuración exacta lista para producción en AWS, pero utiliza instancias EC2 genéricas simuladas (mocks) para las pruebas locales.

## 🛠️ Requisitos Previos

Para ejecutar este proyecto localmente, necesitarás:

  - [Docker](https://www.docker.com/) y [enlace sospechoso eliminado] en ejecución.
  - [Terraform](https://www.terraform.io/)
  - Wrappers de línea de comandos (CLI) `tflocal` y `awslocal`.
  - Herramienta `make`.

## 🚀 Inicio Rápido (Despliegue Local)

Se incluye un archivo `Makefile` para simplificar la interacción con los comandos estándar de Terraform y LocalStack.

**1. Inicializar los Proveedores de Terraform**

```bash
make init
```

**2. Previsualizar el Plan de Infraestructura**

```bash
make plan
```

**3. Desplegar la Infraestructura**

```bash
make apply
```

**4. Comprobar el Estado de las Instancias en Ejecución**

```bash
make status
```

**5. Limpiar / Destruir el Entorno**

```bash
make destroy
```

## 📁 Estructura del Repositorio

  * `main.tf` - Recursos principales de Terraform (VPC, Subnets, EC2, SG, ASG, ALB).
  * `variables.tf` - Configuraciones dinámicas y bloques CIDR.
  * `provider.tf` - Configuración de los endpoints de AWS/LocalStack.
  * `scripts/install_services.sh` - Script `user_data` de EC2 que inyecta la configuración de CloudWatch e inicializa NGINX.
  * `Makefile` - Archivo de utilidades para simplificar los comandos de desarrollo local.
