resource "aws_vpc" "vpc_main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project}-vpc-main"
  }
}

locals {
  common_tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}
resource "aws_subnet" "public_subnet" {
  count                   = length(var.public_subnets_cidrs)
  vpc_id                  = aws_vpc.vpc_main.id
  cidr_block              = var.public_subnets_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project}-public-subnet-${var.availability_zones[count.index]}"
  }
}

# Private Subnets - APP1
#Solo accesibles desde el ALB (via SG). Salen a Internet por NAT.
#Aisladas de App-2 por defecto.

resource "aws_subnet" "app1_private_subnet" {
  count             = length(var.app1_private_cidrs)
  vpc_id            = aws_vpc.vpc_main.id
  cidr_block        = var.app1_private_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]


  tags = {
    Name        = "${var.project}-app1-private-subnet-${var.availability_zones[count.index]}"
    Tier        = "private"
    Application = "app1"

  }
}
# Private Subnet - APP2
resource "aws_subnet" "app2_private_subnet" {
  count             = length(var.app2_private_cidrs)
  vpc_id            = aws_vpc.vpc_main.id
  cidr_block        = var.app2_private_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]


  tags = {
    Name        = "${var.project}-app2-private-subnet-${var.availability_zones[count.index]}"
    Tier        = "private"
    Application = "app2"

  }
}

# ___ Private Subnet - DB ___
# Estas subneeets no tienen salida a inteernet
# Solo accesibles desde las subredes privadas de App1 y App2

resource "aws_subnet" "database_subnet" {
  count             = length(var.db_private_cidrs)
  vpc_id            = aws_vpc.vpc_main.id
  cidr_block        = var.db_private_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]


  tags = {
    Name        = "${var.project}-database-subnet-${var.availability_zones[count.index]}"
    Tier        = "private"
    Application = "database"

  }
}

# Rol IAM para EC2
resource "aws_iam_role" "ssm_role" {
  name = "EC2-SSM-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# Policy IAM para SSM
resource "aws_iam_role_policy_attachment" "ssm_policy" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Instance Profile para EC2
resource "aws_iam_instance_profile" "ssm_profile" {
  name = "EC2-SSM-Profile"
  role = aws_iam_role.ssm_role.name
}

# ____ INTERNET GATEWAY ____
# Puerta de entrada/salida de la VPC a internet

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc_main.id
  tags = merge(local.common_tags, {
    Name = "${var.project}-igw"
  })
}

# NAT Gateway + Elastic IP (para que las privadas tengan salida a internet)

resource "aws_eip" "nat_ip" {
  count      = var.create_nat_gateway ? length(var.public_subnets_cidrs) : 0
  domain     = "vpc"
  depends_on = [aws_internet_gateway.igw]

  tags = merge(local.common_tags, {
    Name = "${var.project}-nat-ip-${var.availability_zones[count.index]}"
  })
}

resource "aws_nat_gateway" "nat_gateway" {
  count         = var.create_nat_gateway ? length(var.public_subnets_cidrs) : 0
  allocation_id = aws_eip.nat_ip[count.index].id
  subnet_id     = aws_subnet.public_subnet[count.index].id
  depends_on    = [aws_internet_gateway.igw]

  tags = merge(local.common_tags, {
    Name = "${var.project}-nat-gateway-${var.availability_zones[count.index]}"
    Note = "1 NAT GW para dev - en produccion uno por AZ"
  })
}

# ___ ROUTE TABLE ___
# todo lo que no es vpc local -> IGW

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.vpc_main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = merge(local.common_tags, {
    Name = "${var.project}-public-rt"
  })
}

resource "aws_route_table_association" "public" {
  count          = length(var.public_subnets_cidrs)
  subnet_id      = aws_subnet.public_subnet[count.index].id
  route_table_id = aws_route_table.public_rt.id
}

# ___ ROUTE TABLE PRIVATE  ___

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.vpc_main.id

  dynamic "route" {
    for_each = var.create_nat_gateway ? [1] : []
    content {
      cidr_block     = "0.0.0.0/0"
      nat_gateway_id = aws_nat_gateway.nat_gateway[0].id
    }
  }

  tags = merge(local.common_tags, {
    Name = "${var.project}-private-rt"
  })
}

# asociar la route table privada a todas las subnets privadas y dee geestion.

resource "aws_route_table_association" "app_1_private" {
  count          = length(var.app1_private_cidrs)
  subnet_id      = aws_subnet.app1_private_subnet[count.index].id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "app_2_private" {
  count          = length(var.app2_private_cidrs)
  subnet_id      = aws_subnet.app2_private_subnet[count.index].id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "database_private" {
  count          = length(var.db_private_cidrs)
  subnet_id      = aws_subnet.database_subnet[count.index].id
  route_table_id = aws_route_table.private_rt.id
}

# resource "aws_route_table_association" "mgmt_private" {
#   count          = length(var.mgmt_subnets_cidrs)
#   subnet_id      = aws_subnet.public_subnet[count.index].id # Needs true management subnet resource to be exact, pointing to public for now or wait, mgmt_subnets resource doesn't exist. Let's comment this out for now or define it.
#   route_table_id = aws_route_table.private_rt.id
# }

# 1. Security Group para las EC2 (Solo permite tráfico del Load Balancer)
resource "aws_security_group" "ec2_sg" {
  name        = "EC2-Security-Group"
  description = "Permitir trafico HTTP"
  vpc_id      = aws_vpc.vpc_main.id

  # Entrada: Permitimos el puerto 80 (Nginx) 
  # En un entorno real, aqui solo permitiriamos el SG del Load Balancer
  ingress {
    from_port = 80
    to_port   = 80
    protocol  = "tcp"
    # security_groups = [aws_security_group.alb_sg.id] # Para AWS real
    cidr_blocks = ["0.0.0.0/0"] # Revertido para LocalStack sin ALB
  }

  # Salida: Permitimos todo para que la maquina pueda bajar actualizaciones
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 2. El Launch Template (La Receta)
resource "aws_launch_template" "app_template" {
  name_prefix   = "app-server-"
  image_id      = "ami-005fc0f2363ee0e88" # ID de Ubuntu en LocalStack
  instance_type = "t2.micro"

  # Pegamos el Rol de IAM que creamos antes
  iam_instance_profile {
    name = aws_iam_instance_profile.ssm_profile.name
  }

  # Cargamos el script de Bash
  user_data = filebase64("${path.module}/scripts/install_services.sh")

  network_interfaces {
    associate_public_ip_address = false # Van en subred privada
    security_groups             = [aws_security_group.ec2_sg.id]
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "App-Server-Managed"
    }
  }
}

# Auto Scaling Group en Subredes Privadas (App1)
# resource "aws_autoscaling_group" "app1_asg" {
#   name                = "${var.project}-app1-asg"
#   desired_capacity    = 2
#   max_size            = 3
#   min_size            = 1
#   
#   vpc_zone_identifier = aws_subnet.app1_private_subnet[*].id
# 
#   launch_template {
#     id      = aws_launch_template.app_template.id
#     version = "$Latest"
#   }
# 
#   tag {
#     key                 = "Name"
#     value               = "${var.project}-app1-instance"
#     propagate_at_launch = true
#   }
# }

# Ya que ASG no esta disponible en LocalStack Community, 
# simularemos el grupo de autoescalado levantando "manualmente" 2 instancias EC2.
resource "aws_instance" "app1_instance" {
  count = 2 # Simulamos el 'desired_capacity = 2'

  launch_template {
    id      = aws_launch_template.app_template.id
    version = "$Latest"
  }

  # Repartir instancias entre las subredes privadas
  subnet_id = aws_subnet.app1_private_subnet[count.index % length(var.app1_private_cidrs)].id

  tags = {
    Name = "${var.project}-app1-instance-${count.index + 1}"
  }
}

# IMPORTANTE: ELBv2 (Application Load Balancer y Target Groups)
# NO está soportado en LocalStack Community (es versión Pro).
# Dejamos todo el código estructurado para AWS real pero comentado aquí.

# resource "aws_security_group" "alb_sg" {
#   name        = "alb-sg"
#   description = "Permitir trafico HTTP y HTTPS desde  afuera"
#   vpc_id      = aws_vpc.vpc_main.id
# 
#   ingress {
#     from_port = 80
#     to_port   = 80
#     protocol  = "tcp"
#   }
# 
#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
# }
# 
# # Load balancer
# resource "aws_lb" "app_lb" {
#   name               = "app-lb"
#   internal           = false
#   load_balancer_type = "application"
#   security_groups    = [aws_security_group.alb_sg.id]
#   subnets            = aws_subnet.public_subnet[*].id
# 
#   tags = merge(local.common_tags, {
#     Name = "${var.project}-app-lb"
#   })
# }
# 
# # Listener del Load Balancer (escucha el puerto 80 y manda al Target Group)
# resource "aws_lb_listener" "http_listener" {
#   load_balancer_arn = aws_lb.app_lb.arn
#   port              = "80"
#   protocol          = "HTTP"
# 
#   default_action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.app_tg.arn
#   }
# }
# 
# # 1. Target Group (Para saber a qué máquinas enviar el tráfico)
# resource "aws_lb_target_group" "app_tg" {
#   name     = "app-target-group"
#   port     = 80
#   protocol = "HTTP"
#   vpc_id   = aws_vpc.vpc_main.id
# 
#   health_check {
#     path                = "/"
#     interval            = 30
#     timeout             = 5
#     healthy_threshold   = 2
#     unhealthy_threshold = 2
#   }
# 
#   tags = {
#     Name = "${var.project}-app-tg"
#   }
# }
# 
# # 2. Attachments (Enlazamos las EC2 dummy que creamos al Target Group)
# resource "aws_lb_target_group_attachment" "app_tg_attachment" {
#   count            = length(aws_instance.app1_instance)
#   target_group_arn = aws_lb_target_group.app_tg.arn
#   target_id        = aws_instance.app1_instance[count.index].id
#   port             = 80
# }

# === CLOUDWATCH LOG GROUPS ===
# Creamos formalmente el Log Group en Terraform para que exista en AWS
resource "aws_cloudwatch_log_group" "nginx_logs" {
  name              = "/aws/ec2/self-healing-app/nginx"
  retention_in_days = 7 # Evitamos pagar de más borrando logs viejos

  tags = merge(local.common_tags, {
    Name = "${var.project}-nginx-logs"
  })
}
