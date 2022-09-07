# node file to create node

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

#creating ec2 instance for jenkins slave agent

resource "aws_instance" "ec2" {

  ami                         = "ami-0b68ffacaa25f6879"
  instance_type               = "t2.micro"
  associate_public_ip_address = true
  key_name                    = var.key-name
  security_groups             = [var.security-group]

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

# creating null resource to change permission on remote server

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

# creating null resource to configure slave agent in  jenkins master

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








