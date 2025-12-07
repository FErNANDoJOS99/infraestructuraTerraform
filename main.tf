resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  tags = {
    Name = "${var.app_name}-vpc"
  }
}


#----------------------------------
#       Tres subredes publicas 
# Nota: Tendran el mismo nombre solo que en zonas diferentes 
# ---------------------------------
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.subnet_public_cidr_1
  map_public_ip_on_launch = false
  availability_zone       = var.public_subnet_az_1

  tags = {
    Name = "${var.app_name}-subnet-1"
  }
}




resource "aws_subnet" "public2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.subnet_public_cidr_2
  map_public_ip_on_launch = false
  availability_zone       = var.public_subnet_az_2

  tags = {
    Name = "${var.app_name}-subnet-2"
  }
}


resource "aws_subnet" "public3" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.subnet_public_cidr_3
  map_public_ip_on_launch = true
  availability_zone       = var.public_subnet_az_3

  tags = {
    Name = "${var.app_name}-subnet-3"
  }
}



# ==========================================
# Elastic IP y asociación
# ==========================================
resource "aws_eip" "eip_terraform" {
  domain = "vpc"
}

resource "aws_eip_association" "eip_terraform_assoc" {
  instance_id   = aws_instance.front.id
  allocation_id = aws_eip.eip_terraform.id

}


# Elastic IP y asociación2


resource "aws_eip" "eip_terraform_2" {
  domain = "vpc"
}

resource "aws_eip_association" "eip_terraform_assoc_2" {
  instance_id   = aws_instance.back.id
  allocation_id = aws_eip.eip_terraform_2.id
}




#----------------------------------
#        Subred privada 
# ---------------------------------

resource "aws_subnet" "private" {
  vpc_id     = aws_vpc.main.id
  cidr_block = var.subnet_private_cidr
  availability_zone = var.private_subnet_az_4

  tags = {
    Name = "${var.app_name}-subnet-db"
  }
}


# Se ocupa otra porque "aws_db_subnet_group" lo pide
resource "aws_subnet" "private_db" {
  vpc_id     = aws_vpc.main.id
  cidr_block = var.subnet_private_cidr2
  availability_zone = var.private_subnet_az_1

  tags = {
    Name = "${var.app_name}-subnet-db-2"
  }
}


#-------------------------------------------------
#        Internet Gateway y tabla de enrutamiento
# -------------------------------------------------


resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.app_name}-igw"
  }
}

resource "aws_route_table" "route_table_terraform" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.app_name}-rt"
  }
}

# por donde saldra la tabla de rutas 
resource "aws_route" "default_route" {
  route_table_id         = aws_route_table.route_table_terraform.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

# Tengo que asociar todas las subredes a la tabla de rutas

resource "aws_route_table_association" "subnet_assoc1" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.route_table_terraform.id
}

resource "aws_route_table_association" "subnet_assoc2" {
  subnet_id      = aws_subnet.public2.id
  route_table_id = aws_route_table.route_table_terraform.id
}

resource "aws_route_table_association" "subnet_assoc3" {
  subnet_id      = aws_subnet.public3.id
  route_table_id = aws_route_table.route_table_terraform.id
}




# ==========================================
# Security Group 
# ==========================================
resource "aws_security_group" "alb" {
  name        = "abl"
  description = "Permitir acceso por HTTP y HTTPS"
  vpc_id      = aws_vpc.main.id

    # Inbound HTTP
  ingress {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

    # Inbound HTTPS
  ingress {
    description = "Allow HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  
  # Allow all outbound
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"    # -1 = all protocols
    cidr_blocks = ["0.0.0.0/0"]
  }


    tags = {
    Name = "web-sg"
  }
}



resource "aws_security_group" "ec2" {
  name        = "ec2"
  description = "Permitir acceso por ssh"
  vpc_id      = aws_vpc.main.id

  #   #Inbound HTTP
  # Tengo que habilitar que venga del 80 porque el loadbalancer lo 
  # manda desde el 80
  ingress {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    security_groups = [aws_security_group.alb.id]
  }

  #    
  # ingress {
  #   description = "Allow HTTP"
  #   from_port   = 3000
  #   to_port     = 3000
  #   protocol    = "tcp"
  #   cidr_blocks = ["0.0.0.0/0"]
  # }


  #   # Inbound HTTPS ,no tengo el TLS asi lo dejo desactivado
  # ingress {
  #   description = "Allow HTTPS"
  #   from_port   = 443
  #   to_port     = 443
  #   protocol    = "tcp"
  #   cidr_blocks = ["0.0.0.0/0"]
  # }

  #Para permitir ssh
  ingress {
    description = "SSH desde tu IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    #cidr_blocks = ["${chomp(data.http.my_ip.body)}/32"]
    #cidr_blocks = ["<IP-publica>/32"]
    cidr_blocks = ["0.0.0.0/0"] # solo pruebas
  }

  ingress {
    description = "Allow ICMP ping"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  
  # Allow all outbound
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"    # -1 = all protocols
    cidr_blocks = ["0.0.0.0/0"]
  }


    tags = {
    Name = "ec2-sg"
  }
}



# Segurity group del backend

resource "aws_security_group" "ec2-backend" {
  name        = "ec2-backend"
  description = "Permitir acceso por ssh"
  vpc_id      = aws_vpc.main.id

    # Inbound HTTP
  # ingress {
  #   description = "Allow HTTP"
  #   from_port   = 80
  #   to_port     = 80
  #   protocol    = "tcp"
  #   cidr_blocks = ["0.0.0.0/0"]
  #   security_groups = [aws_security_group.alb.id]
  # }


    ingress {
    description = "Allow HTTP"
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  #   # Inbound HTTPS
  # ingress {
  #   description = "Allow HTTPS"
  #   from_port   = 443
  #   to_port     = 443
  #   protocol    = "tcp"
  #   cidr_blocks = ["0.0.0.0/0"]
  # }

  #Para permitir ssh
  ingress {
    description = "SSH desde tu IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    #cidr_blocks = ["${chomp(data.http.my_ip.body)}/32"]
    #cidr_blocks = ["<IP-publica>/32"]
    cidr_blocks = ["0.0.0.0/0"] # solo pruebas
  }

  ingress {
    description = "Allow ICMP ping"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  
  # Allow all outbound
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"    # -1 = all protocols
    cidr_blocks = ["0.0.0.0/0"]
  }


    tags = {
    Name = "ec2-sg-backend"
  }
}




# SG  de la base de datos RDS

resource "aws_security_group" "rds" {
  name        = "rds"
  description = "Permitir acceso a BD"
  vpc_id      = aws_vpc.main.id

    # Inbound HTTP
  ingress {
    description = "Allow BD"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # No recomendado
  }


  # Allow all outbound
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"    # -1 = all protocols
    cidr_blocks = ["0.0.0.0/0"]
  }


    tags = {
    Name = "RDS-sg"
  }
}






# ==========================================
#    aws_db_subnet_group
# Nota: Sin un DB Subnet Group, no puedes crear un RDS en una VPC
# ==========================================

resource "aws_db_subnet_group" "aws_db" {
  name       = "my-db-subnet-group"
  subnet_ids = [
    aws_subnet.private.id,
    aws_subnet.private_db.id
  ]

  tags = {
    Name = "my-db-subnet-group"
  }
}

# ==========================================
#     Generar llaves SSH 
# ==========================================
# Nota: Cuando se hace destroy si borra la llave de donde la creo 
resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Recurso que EC2 necesita para aceptar la clave pública
resource "aws_key_pair" "generated_key" {
  key_name   = "my-terraform-key" # nombre que EC2 verá
  public_key = tls_private_key.ssh_key.public_key_openssh
}

# Guardar la llave en local 
resource "local_file" "private_key" {
  content  = tls_private_key.ssh_key.private_key_pem
  filename = "${path.module}/my-terraform-key.pem"
}

# Para usarla en una instancia 
# resource "aws_instance" "example" {
#   ami           = "ami-1234567890abcdef"
#   instance_type = "t3.micro"

#   key_name = aws_key_pair.generated_key.key_name

#   # ...
# }


# ==========================================
#    crea un repositorio de imágenes Docker en Amazon ECR
# ===========================================
# Uno para el frontend y otro para el backend

resource "aws_ecr_repository" "main" {
  name = var.ecr_repo_name
  image_scanning_configuration {
    scan_on_push = true
  }
}


resource "aws_ecr_repository" "main2" {
  name = var.ecr_repo_name2
  image_scanning_configuration {
    scan_on_push = true
  }
}




# =========================================
#    Instancias RDS
# =========================================



resource "aws_db_instance" "main" {
  identifier             = "${var.app_name}-db"
  db_name                = var.db_name
  engine                 = "postgres"
  instance_class         = var.db_instance_class
  allocated_storage      = 20
  storage_type           = "gp2"
  username               = var.db_user
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.aws_db.id
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false
  skip_final_snapshot    = true
}




# ==========================================
# Creacion del ROL
# ==========================================

# Se crea un rol para poder descargar imagenes
resource "aws_iam_role" "ec2_role" {
  name = "ec2-ecr-access-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecr_read_only" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2-ecr-access-profile"
  role = aws_iam_role.ec2_role.name
}








# =========================================
#    Instancias EC2
# =========================================


# Esto es necesario para obtener el id correcto de la 
data "aws_ssm_parameter" "amazon_linux_2_ami" {
  name = "/aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2"
}


# Frontend 

resource "aws_instance" "front" {
  ami                    = data.aws_ssm_parameter.amazon_linux_2_ami.value
  instance_type          = var.ec2_instance_type
  key_name               = aws_key_pair.generated_key.key_name
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.ec2.id]
  iam_instance_profile        = aws_iam_instance_profile.ec2_profile.name 

  tags = {
    Name = "${var.app_name}-frontend"
  }
      user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y docker
    systemctl start docker
    systemctl enable docker



    # Agregar ec2-user al grupo docker
    usermod -aG docker ec2-user

    # Permitir que el usuario use docker sin reiniciar (solo aplicable en cloud-init)
    # newgrp docker # opcional

    EOF


}



# Backend 

resource "aws_instance" "back" {
  ami                    = data.aws_ssm_parameter.amazon_linux_2_ami.value
  instance_type          = var.ec2_instance_type
  key_name               = aws_key_pair.generated_key.key_name
  subnet_id              = aws_subnet.public2.id
  vpc_security_group_ids = [aws_security_group.ec2-backend.id]
  iam_instance_profile        = aws_iam_instance_profile.ec2_profile.name 

  tags = {
    Name = "${var.app_name}-backend"
  }

      user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y docker
    systemctl start docker
    systemctl enable docker


    # Agregar ec2-user al grupo docker
    usermod -aG docker ec2-user

    # Permitir que el usuario use docker sin reiniciar (solo aplicable en cloud-init)
    # newgrp docker # opcional


    EOF



  
}




# ===========================================================
# El ALB
# ============================================================


resource "aws_lb" "main" {
  name               = "${var.app_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [aws_subnet.public2.id,aws_subnet.public.id]

  tags = {
    Name = "${var.app_name}-alb"
  }
}

resource "aws_lb_target_group" "main" {
  name        = "${var.app_name}-tg"
  #port        = 80
  port     = 3000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "instance"

  health_check {
    path = "/"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}

# Adjuntar cada instancia al target group
# Nota solo son las intancias de un tipo , por ejemplo las del frontend
resource "aws_lb_target_group_attachment" "att" {
  # El count es necesario cuando se usan muchas instancias (yo solo tengo una ahorita)
  #count            = var.instance_count
  target_group_arn = aws_lb_target_group.main.arn
  #target_id        = aws_instance.web[count.index].id
  target_id        = aws_instance.front.id
  # El puerto no es tan necesario aqui
  #port             = 80
}


#====================================================
#      Servicio de route 53 
# ===================================================



resource "aws_route53_zone" "primary" {
  name = "ingsoftware2.publicvm.com"
}

# Para imprimir los 4 nameservers
output "route53_nameservers" {
  value = aws_route53_zone.primary.name_servers
}

# Crear el registro DNS
resource "aws_route53_record" "alb_record" {
  zone_id = aws_route53_zone.primary.zone_id
  name    = "ingsoftware2.publicvm.com"
  type    = "A"

  alias {
    name                   = aws_lb.main.dns_name
    # Para saber en que zona vive el servicio al que apunta
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true
  }
}

