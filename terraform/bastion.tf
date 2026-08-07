resource "aws_security_group" "bastion" {
  name   = "${var.project_name}-bastion-sg"
  vpc_id = module.vpc.vpc_id

  # SSM은 인스턴스가 AWS로 아웃바운드 접속만 하면 되어서, 인바운드 규칙(22번 포트 등) 자체가 필요 없음

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Project = var.project_name
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
}

# SSM이 이 인스턴스를 관리(세션 연결)할 수 있도록 부여하는 역할
resource "aws_iam_role" "bastion_ssm" {
  name = "${var.project_name}-bastion-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = {
    Project = var.project_name
  }
}

resource "aws_iam_role_policy_attachment" "bastion_ssm" {
  role       = aws_iam_role.bastion_ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "bastion_ssm" {
  name = "${var.project_name}-bastion-ssm-profile"
  role = aws_iam_role.bastion_ssm.name
}

resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  subnet_id              = module.vpc.private_subnets[0] # 프라이빗 서브넷으로 이동 (공인 IP 불필요)
  vpc_security_group_ids = [aws_security_group.bastion.id]
  iam_instance_profile   = aws_iam_instance_profile.bastion_ssm.name

  tags = {
    Name    = "${var.project_name}-bastion"
    Project = var.project_name
  }
}
