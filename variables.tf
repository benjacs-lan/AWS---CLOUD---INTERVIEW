variable "aws_region" {
  type        = string
  description = "Region AWS"
  default     = "us-east-1"
}

variable "project" {
  type        = string
  description = "self-heandling-cloud"
  default     = "self-cloud"
}

variable "environment" {
  type        = string
  description = "Environment"
  default     = "dev"

  validation {
    condition     = contains(["dev", "stage", "prod"], var.environment)
    error_message = "Environment must be dev, stage or prod"
  }

}

# ______ RED ______
variable "vpc_cidr" {
  type        = string
  description = "CIDR DE LA VPC - /16 da 65.536 IPs"
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  type        = list(string)
  description = "Dos zonas de disponibilidad (AZs)"
  default     = ["us-east-1a", "us-east-1b"]
}

# ______ SUBNETS ______
variable "public_subnets_cidrs" {
  type        = list(string)
  description = "CIDR de las subredes públicas"
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "app1_private_cidrs" {
  type        = list(string)
  description = "CIDR de las subredes privadas de la app1"
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "app2_private_cidrs" {
  type        = list(string)
  description = "CIDR de las subredes privadas de la app2"
  default     = ["10.0.21.0/24", "10.0.22.0/24"]
}

variable "db_private_cidrs" {
  type        = list(string)
  description = "CIDR de las subredes privadas de la base de datos"
  default     = ["10.0.31.0/24", "10.0.32.0/24"]
}

variable "mgmt_subnets_cidrs" {
  type        = list(string)
  description = "CIDRs de las subnets de gestion (Bastion, SSM, VPN)."
  default     = ["10.0.40.0/24", "10.0.41.0/24"]
}

#____ FEATURE FLAGS ____
variable "create_nat_gateway" {
  type        = bool
  description = "Crear NAT Gateway para que subredes privadas salgan a internet"
  default     = true
}

variable "enable_flow_logs" {
  type        = bool
  description = "Habilitar Flow Logs para capturar el trafico de la VPC"
  default     = false
  # En dev poner false para no generar costos/datos. truee en stading y produccion
}

variable "allow_app1_to_app2" {
  type        = bool
  description = "Permitir trafico entre app1 y app2"
  default     = false
  # Por deefecto las apps estan aisladas. See activa solo cuando es necesario
}

