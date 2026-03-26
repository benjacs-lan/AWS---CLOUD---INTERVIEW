# 🚀 Self-Healing Cloud Infrastructure

A comprehensive, highly-available (HA), and fault-tolerant cloud architecture built using **Terraform** on **AWS**. Designed with a "Self-Healing" paradigm to eliminate Single Points of Failure (SPOF) using Auto Scaling Groups and Application Load Balancers.

Presently configured to be tested locally using **LocalStack**.

## 🏗️ Architecture Overview

The infrastructure spans across two Availability Zones (AZs) for redundancy. Compute resources are kept private, while the Application Load Balancer safely routes internet traffic.

```mermaid
graph TD
    classDef aws fill:#232F3E,stroke:#fff,stroke-width:2px,color:#fff;
    classDef public fill:#d4e6f1,stroke:#2980b9,stroke-width:2px;
    classDef private fill:#fadbd8,stroke:#e74c3c,stroke-width:2px;
    classDef component fill:#f9e79f,stroke:#f39c12,stroke-width:2px;

    subgraph AWS_Cloud ["☁️ AWS Cloud (Region us-east-1)"]
        IGW(("Internet Gateway")):::aws

        subgraph VPC ["VPC (10.0.0.0/16)"]
            ALB{"Application Load Balancer"}:::component
            ASG[["Auto Scaling Group (Desired: 2)"]]:::component

            subgraph AZ1 ["AZ 1 (us-east-1a)"]
                PUB1["Public Subnet 1"]:::public
                NAT1(("NAT Gateway")):::aws
                PRI1["Private Subnet App1"]:::private
                
                EC2_1("💻 EC2 Instance 1 (NGINX)"):::component
            end
            
            subgraph AZ2 ["AZ 2 (us-east-1b)"]
                PUB2["Public Subnet 2"]:::public
                PRI2["Private Subnet App2"]:::private
                
                EC2_2("💻 EC2 Instance 2 (NGINX)"):::component
            end
            
            IGW -->|Internet Traffic| ALB
            ALB -->|HTTP Port 80| EC2_1
            ALB -->|HTTP Port 80| EC2_2
            
            PUB1 -.- NAT1
            PUB1 -.- ALB
            PUB2 -.- ALB
            
            PRI1 -.- EC2_1
            PRI2 -.- EC2_2
            
            EC2_1 -->|Outbound traffic (Updates)| NAT1
            EC2_2 -->|Outbound traffic (Updates)| NAT1
        end
        
        CW[("📊 Amazon CloudWatch Logs <br> /aws/ec2/self-healing-app/nginx")]:::aws
        EC2_1 -.->|Nginx Logs Stream| CW
        EC2_2 -.->|Nginx Logs Stream| CW
    end
    
    ASG -.->|Monitors Health & Replaces Nodes| EC2_1
    ASG -.->|Monitors Health & Replaces Nodes| EC2_2
    
    style AWS_Cloud fill:#f4f6f7,stroke:#34495e,stroke-dasharray: 5 5
    style VPC fill:#eaeded,stroke:#7f8c8d
    style AZ1 fill:#ebeeeb,stroke:#bdc3c7
    style AZ2 fill:#ebeeeb,stroke:#bdc3c7
```

## ✨ Key Features

* **Network Isolation:** Public & Private Subnets leveraging NAT Gateways for secure outbound traffic.
* **Immutable Infrastructure:** EC2 instances are bootstrapped automatically via a **Launch Template** equipped with Nginx and the CloudWatch Agent.
* **Self-Healing:** An **Auto Scaling Group** monitors instance health and replaces degraded nodes automatically without human intervention.
* **Traffic Distribution:** An **Application Load Balancer (ALB)** routes traffic strictly to healthy nodes.
* **Granular Security:** Zero direct internet access to EC2 instances. Security Groups strictly allow traffic exclusively from the ALB.
* **Observability:** Centralized logs via **CloudWatch** extracting `/var/log/nginx/access.log` using the unified CloudWatch Agent in real-time.

> **Note on LocalStack:** ELBv2 and AutoScaling APIs are Pro features in LocalStack. The code within `main.tf` contains the exact production-ready setup for AWS but falls back to mock generic EC2 instances for local testing.

## 🛠️ Prerequisites

To run this locally, you will need:
- [Docker](https://www.docker.com/) & [LocalStack](https://localstack.cloud/) running.
- [Terraform](https://www.terraform.io/)
- `tflocal` and `awslocal` CLI wrappers.
- `make` utility.

## 🚀 Quick Start (Local Deployment)

A `Makefile` is included to simplify the interaction with standard Terraform commands and LocalStack.

**1. Initialize Terraform Providers**
```bash
make init
```

**2. Preview Infrastructure Plan**
```bash
make plan
```

**3. Deploy the Infrastructure**
```bash
make apply
```

**4. Check Running Instances Status**
```bash
make status
```

**5. Clean up / Destroy Environment**
```bash
make destroy
```

## 📁 Repository Structure
* `main.tf` - Primary Terraform resources (VPC, Subnets, EC2, SG, ASG, ALB).
* `variables.tf` - Dynamic configurations and CIDR blocks.
* `provider.tf` - Setup for AWS/LocalStack endpoints.
* `scripts/install_services.sh` - EC2 `user_data` script injecting CloudWatch config and bootstrapping NGINX.
* `Makefile` - Convenience wrapper for local development commands.
