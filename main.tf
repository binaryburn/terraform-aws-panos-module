######
# AMI detection
######
data "aws_ami" "panos_firewall_ami" {
  most_recent = "${var.fw_version == "latest" ? true : false}"
  owners      = ["679593333241"]

  filter {
    name   = "name"
    values = ["PA-VM-AWS-${replace(var.fw_version, "/latest/", "")}*"]
  }

  filter {
    name   = "product-code.type"
    values = ["marketplace"]
  }

  filter {
    name   = "product-code"
    values = ["${lookup(var.bundles, var.fw_bundle)}"]
  }
}

#####
# Templates
#####

provider "template" {
  version = "~> 1.0"
}

data "template_file" "mgmt_interface_swap" {
  count = "${data.template_file.bootstrap_s3.count * 2 + var.mgmt_interface_swap == 1 ? 1 : 0}"

  template = "mgmt-interface-swap=enable"
}

data "template_file" "bootstrap_s3" {
  count = "${var.bootstrap_s3 == "" ? 0 : 1}"

  template = "vmseries-bootstrap-aws-s3bucket=$${s3bucket}"

  vars {
    s3bucket = "${var.bootstrap_s3}"
  }
}

data "template_file" "data_subnet_ids" {
  template = "$${first},$${rest}"

  vars {
    first = "${var.mgmt_interface_swap == true ? var.mgmt_subnet_id : var.data_subnet_ids[0]}"
    rest  = "${join(",", slice(var.data_subnet_ids, 1, length(var.data_subnet_ids)))}"
  }
}

data "template_file" "data_security_groups" {
  template = "$${first},$${rest}"

  vars {
    first = "${var.mgmt_interface_swap == true ? var.mgmt_security_group_id : var.data_security_group_ids[0]}"
    rest  = "${join(",", slice(var.data_security_group_ids, 1, length(var.data_security_group_ids)))}"
  }
}

######
# EC2 Instance
######
resource "aws_instance" "firewall" {
  count = "${var.fw_count}"

  ami           = "${data.aws_ami.panos_firewall_ami.image_id}"
  instance_type = "${var.instance_type}"
  key_name      = "${var.ssh_key_name}"
  monitoring    = "${var.monitoring}"

  #vpc_security_group_ids = ["${var.vpc_security_group_ids}"]
  iam_instance_profile = "${var.iam_instance_profile}"

  subnet_id = "${var.mgmt_interface_swap == true ? var.data_subnet_ids[0] : var.mgmt_subnet_id}"

  vpc_security_group_ids      = ["${length(var.vpc_security_group_ids) == 0 ? module.security_group_mgmt.this_security_group_id : var.vpc_security_group_ids[0]}"]
  associate_public_ip_address = "${var.associate_public_ip_address}"
  private_ip                  = "${length(var.private_ips) == 0 ? "" : var.private_ips[count.index * length(var.data_subnet_ids)]}"

  #ipv6_address_count          = "${var.ipv6_address_count}"
  #ipv6_addresses              = "${var.ipv6_addresses}"

  ebs_optimized = true

  #volume_tags            = "${var.volume_tags}"
  #root_block_device      = "${var.root_block_device}"
  #ebs_block_device       = "${var.ebs_block_device}"
  #ephemeral_block_device = "${var.ephemeral_block_device}"

  source_dest_check                    = false
  disable_api_termination              = "${var.disable_api_termination}"
  instance_initiated_shutdown_behavior = "stop"
  placement_group                      = "${var.placement_group}"
  tenancy                              = "${var.tenancy}"
  user_data                            = "${element(concat(data.template_file.mgmt_interface_swap.*.rendered, data.template_file.bootstrap_s3.*.rendered, list("")), 0)}"
  tags                                 = "${merge(var.tags, map("Name", format("%s-%d", var.name, count.index+1)))}"
  lifecycle {
    # Due to several known issues in Terraform AWS provider related to arguments of aws_instance:
    # (eg, https://github.com/terraform-providers/terraform-provider-aws/issues/2036)
    # we have to ignore changes in the following arguments
    ignore_changes = ["private_ip", "vpc_security_group_ids", "root_block_device"]
  }
}

######
# Network Interfaces (ENI)
######
resource "aws_network_interface" "firewall" {
  #count     = "${(length(var.data_subnet_ids)-1)*var.fw_count}"
  count     = "${var.data_interface_count}"
  subnet_id = "${element(split(",", data.template_file.data_subnet_ids.rendered), count.index)}"

  #security_groups = ["${length(var.vpc_security_group_ids) == 0 ? module.security_group_mgmt.this_security_group_id  : element(slice(var.vpc_security_group_ids, 1, length(var.data_subnet_ids)), count.index)}"]
  security_groups = ["${element(coalescelist(list(module.security_group_mgmt.this_security_group_id), ), count.index)}"]

  #private_ip      = "${length(var.private_ips) == 0 ? "" : element(slice(var.private_ips, count.index / length(var.data_subnet_ids) * length(var.data_subnet_ids) + 1, count.index / length(var.data_subnet_ids) * length(var.data_subnet_ids) + length(var.data_subnet_ids)), count.index)}"

  attachment {
    instance     = "${aws_instance.firewall.*.id[count.index / (length(var.data_subnet_ids)-1)]}"
    device_index = "${(count.index % (length(var.data_subnet_ids)-1))+1}"
  }
}

######
# Default security groups
######

module "security_group_mgmt" {
  source = "terraform-aws-modules/security-group/aws"
  create = "${var.generate_security_groups_in_vpc == "" ? 0 : 1}"

  name        = "${format("%s-Management", var.name)}"
  description = "Allows HTTPS, SSH, and ICMP on firewall management interface"
  vpc_id      = "${var.generate_security_groups_in_vpc}"

  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_rules       = ["https-443-tcp", "ssh-tcp", "all-icmp"]
  egress_rules        = ["all-all"]
}

module "security_group_data" {
  source = "terraform-aws-modules/security-group/aws"
  create = "${var.generate_security_groups_in_vpc == "" ? 0 : 1}"

  name        = "${format("%s-Data", var.name)}"
  description = "Permit everything on data interfaces"
  vpc_id      = "${var.generate_security_groups_in_vpc}"

  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_rules       = ["all-all"]
  egress_rules        = ["all-all"]
}
