# key-pair for slave agent

resource "aws_key_pair" "jenkins-slave" {
  key_name   = "jenkins-slave"
  public_key = file("/var/lib/jenkins/.ssh/id_rsa.pub")
}

# security group for remote access into agent

resource "aws_security_group" "allow_ssh" {
  name        = "allow-ssh"
  description = "Allow SSH inbound traffic"

  ingress {
    description      = "ssh to remote instances"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
  ingress {
    description = "8080 port for remote"
    from_port = 8080
    protocol  = "tcp"
    to_port   = 8080
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }
}