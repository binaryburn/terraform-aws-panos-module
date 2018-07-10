variable "name" {
  description = "Name to be used on all resources as prefix"
}

variable "fw_version" {
  description = ""
} # example: 8.1.0

variable "fw_bundle" {
  description = ""
} # possible values: bundle1, bundle2, byol

variable "fw_count" {
  description = "How many firewalls to instantiate"
  default     = 1
}

variable "data_interface_count" {
  description = "How many data interface on each firewall"
  default     = 2
}

variable "mgmt_subnet_id" {
  description = "List of the VPC Subnet IDs to launch in"
}

variable "data_subnet_ids" {
  description = "List of the VPC Subnet IDs to launch data interfaces in"
  type        = "list"
}

variable "private_ips" {
  description = "List of the private IPs to assign to each interface in order of interface for each firewall (2 firewalls with 3 interfaces each should have 6 private IP's with the first firewall's 3 interfaces listed first)"
  type        = "list"
  default     = []
}

variable "mgmt_security_group_id" {
  description = "A list of security group IDs to associate with (one of vpc_security_group_ids or security_group_vpc must be specified)"
  default     = ""
}

variable "data_security_group_ids" {
  description = "A list of security group IDs to associate with (one of vpc_security_group_ids or security_group_vpc must be specified)"
  type        = "list"
  default     = []
}

variable "generate_security_groups_in_vpc" {
  description = "A VPC in which to create the default set of security groups. Only needed if vpc_security_group_ids is not specified."
  default     = ""
}

variable "instance_type" {
  description = "The type of instance to start"
  default     = "m4.xlarge"
}

variable "ssh_key_name" {
  description = "The ssh key name to use for the instance"
  default     = ""
}

variable "placement_group" {
  description = "The Placement Group to start the instance in"
  default     = ""
}

variable "monitoring" {
  description = "If true, the launched EC2 instance will have detailed monitoring enabled"
  default     = "false"
}

variable "mgmt_interface_swap" {
  description = "Swap the management and ethernet1/1 interfaces so inbound traffic can be load balanced"
  default     = "false"
}

variable "bootstrap_s3" {
  description = "The S3 bucket to get bootstrap configuration (cause 'mgmt_interface_swap' to be ignored)"
  default     = ""
}

variable "associate_public_ip_address" {
  description = "If true, the EC2 instance will have associated public IP address"
  default     = "false"
}

variable "iam_instance_profile" {
  description = "The IAM Instance Profile to launch the instance with. Specified as the name of the Instance Profile."
  default     = ""
}

variable "tenancy" {
  description = "The tenancy of the instance (if the instance is running in a VPC). Available values: default, dedicated, host."
  default     = "default"
}

variable "disable_api_termination" {
  description = "If true, enables EC2 Instance Termination Protection"
  default     = "false"
}

variable "tags" {
  description = "A mapping of tags to assign to the resource"
  type        = "map"
  default     = {}
}
