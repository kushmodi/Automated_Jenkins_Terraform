resource "aws_key_pair" "jenkins-slave" {
  key_name   = "jenkins-slave"
  public_key = file("/var/lib/jenkins/.ssh/id_rsa.pub")
}

resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh"
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
#resource "local_file" "cred-file" {
#  depends_on = [aws_instance.ec2]
#  filename = "cred.xml"
#  content = <<-EOT
#  <com.cloudbees.jenkins.plugins.sshcredentials.impl.BasicSSHUserPrivateKey plugin="ssh-credentials@295.vced876c18eb_4">
#  <scope>GLOBAL</scope>
#  <id>Jenkins-master-key</id>
#  <description>Generated via Terraform for ${aws_instance.ec2.public_ip}</description>
#  <username>jenkins</username>
#  <privateKeySource class="com.cloudbees.jenkins.plugins.sshcredentials.impl.BasicSSHUserPrivateKey\$DirectEntryPrivateKeySource">
#    <privateKey>${file("/var/lib/jenkins/.ssh/id_rsa")}</privateKey>
#  </privateKeySource>
#</com.cloudbees.jenkins.plugins.sshcredentials.impl.BasicSSHUserPrivateKey>
#  EOT
#}

resource "local_file" "node-file" {
  depends_on = [aws_instance.ec2]
  filename = "/var/lib/jenkins/node.xml"
  content = <<-EOT
<slave>
  <name>${aws_instance.ec2.tags.Name}</name>
  <description>Linux Slave</description>
  <remoteFS>/home/jenkins</remoteFS>
  <numExecutors>1</numExecutors>
  <mode>EXCLUSIVE</mode>
  <retentionStrategy class="hudson.slaves.RetentionStrategy\$Always"/>
  <launcher class="hudson.plugins.sshslaves.SSHLauncher" plugin="ssh-slaves@1.5">
    <host>${aws_instance.ec2.public_ip}</host>
    <port>22</port>
    <credentialsId>Jenkins-master-key</credentialsId>
    <sshHostKeyVerificationStrategy class="hudson.plugins.sshslaves.verifiers.ManuallyTrustedKeyVerificationStrategy">
          <requireInitialManualTrust>false</requireInitialManualTrust>
        </sshHostKeyVerificationStrategy>
  </launcher>
  <label>ec2-instance</label>
  <nodeProperties/>
  <userId>jenkins</userId>
</slave>
EOT
}
resource "aws_instance" "ec2" {

  ami                         = "ami-0b68ffacaa25f6879"
  instance_type               = "t2.micro"
  associate_public_ip_address = true
  key_name                    = aws_key_pair.jenkins-slave.key_name
  security_groups             = [aws_security_group.allow_ssh.name]

  tags = {
    Name = var.name
  }

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file("/var/lib/jenkins/.ssh/id_rsa")
    host        = self.public_ip
  }
    provisioner "remote-exec" {
      inline = [
        "sudo useradd -m jenkins",
        "sudo mkdir /home/jenkins/.ssh",
        "sudo chown -R jenkins:jenkins /home/jenkins",
        "sudo touch /home/jenkins/.ssh/authorized_keys",
        "sudo chown -R jenkins:jenkins /home/jenkins/.ssh/authorized_keys",
        "sudo chmod -R 777 /home/jenkins/.ssh"
      ]
    }
  provisioner "file" {
    source = "/var/lib/jenkins/.ssh/id_rsa.pub"
    destination = "/home/jenkins/.ssh/authorized_keys"
  }
  }
resource "null_resource" "change-permission" {
  provisioner "remote-exec" {
    inline = [
      "sudo chmod -R 700 /home/jenkins/.ssh",
    ]
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("/var/lib/jenkins/.ssh/id_rsa")
      host        = aws_instance.ec2.public_ip
    }
  }
}

resource "null_resource" "slave-config" {
  depends_on = [local_file.node-file,null_resource.change-permission]
  provisioner "local-exec" {
    command = <<EOT
     sudo chown jenkins:jenkins /var/lib/jenkins/node.xml
     sudo wget -O /var/lib/jenkins/jenkins-cli.jar http://localhost:8080/jnlpJars/jenkins-cli.jar
     sudo chown jenkins:jenkins /var/lib/jenkins/jenkins-cli.jar
     java -jar /var/lib/jenkins/jenkins-cli.jar -s http://localhost:8080 -auth ${var.username}:${var.password} list-plugins 2>/dev/null | wc -l
     sudo cat /var/lib/jenkins/node.xml | java -jar /var/lib/jenkins/jenkins-cli.jar -s http://localhost:8080 -auth ${var.username}:${var.password} create-node ${aws_instance.ec2.tags.Name}
    EOT
  }
}








