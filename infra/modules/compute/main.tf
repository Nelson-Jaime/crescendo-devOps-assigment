data "aws_ami" "al2023" {
  count = var.ami_id == null ? 1 : 0

  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

locals {
  ami_id = coalesce(var.ami_id, one(data.aws_ami.al2023[*].id))

  # Static config files live in files/ so they can be linted and reused by the Docker smoke test.
  user_data = templatefile("${path.module}/templates/provision.sh.tpl", {
    tomcat_version      = var.tomcat_version
    java_package        = var.java_package
    magnolia_war_url    = var.magnolia_war_url
    heap_mb             = var.jvm_heap_mb
    author_instance     = var.magnolia_instance_type == "author"
    nginx_conf          = file("${path.module}/files/nginx.conf")
    nginx_admin_conf    = file("${path.module}/files/${var.expose_admin ? "nginx-admin-open.conf" : "nginx-admin-blocked.conf"}")
    server_xml          = file("${path.module}/files/server.xml")
    tomcat_unit         = file("${path.module}/files/tomcat.service")
    magnolia_properties = file("${path.module}/files/magnolia-overrides.properties")
  })
}

# --- IAM: Session Manager access, nothing else -------------------------------------------------

resource "aws_iam_role" "instance" {
  name_prefix = "${var.name_prefix}-app-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "instance" {
  name_prefix = "${var.name_prefix}-app-"
  role        = aws_iam_role.instance.name
}

# --- Network access: only the ALB can reach the instance ---------------------------------------

resource "aws_security_group" "instance" {
  name_prefix = "${var.name_prefix}-app-"
  description = "Magnolia instance: HTTP from the ALB only"
  vpc_id      = var.vpc_id

  tags = { Name = "${var.name_prefix}-app" }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "from_alb" {
  security_group_id            = aws_security_group.instance.id
  description                  = "HTTP from the ALB"
  referenced_security_group_id = var.alb_security_group_id
  ip_protocol                  = "tcp"
  from_port                    = 80
  to_port                      = 80
}

# Outbound HTTPS/HTTP only (package mirrors, Apache and Magnolia downloads, SSM) through the NAT gateway.
resource "aws_vpc_security_group_egress_rule" "https" {
  security_group_id = aws_security_group.instance.id
  description       = "HTTPS out (SSM, dnf, downloads)"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}

resource "aws_vpc_security_group_egress_rule" "http" {
  security_group_id = aws_security_group.instance.id
  description       = "HTTP out (dnf repositories)"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
}

# --- The instance ------------------------------------------------------------------------------

resource "aws_instance" "app" {
  ami                         = local.ami_id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [aws_security_group.instance.id]
  iam_instance_profile        = aws_iam_instance_profile.instance.name
  associate_public_ip_address = false

  user_data                   = local.user_data
  user_data_replace_on_change = true

  # IMDSv2 only.
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_volume_size_gb
    encrypted             = true
    delete_on_termination = true
  }

  tags = { Name = "${var.name_prefix}-app" }

  lifecycle {
    # A newer "latest" AMI must not silently replace a running instance.
    ignore_changes = [ami]

    precondition {
      condition     = length(local.user_data) <= 16384
      error_message = "Rendered user_data exceeds the 16 KiB EC2 limit; bake an AMI or fetch the configuration from S3."
    }
  }
}
