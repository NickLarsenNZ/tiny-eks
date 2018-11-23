locals {
  az = ["us-east-1b", "us-east-1c"]
}

resource "aws_vpc" "vpc" {
  cidr_block = "10.255.0.0/16"

  tags {
    Environment = "test"
  }
}

resource "aws_internet_gateway" "igw" {
  tags = {
    Environment = "test"
  }

  vpc_id = "${aws_vpc.vpc.id}"
}

resource "aws_route_table" "t" {
  vpc_id = "${aws_vpc.vpc.id}"

  tags = {
    Environment = "test"
  }
}

resource "aws_route" "r" {
  route_table_id         = "${aws_route_table.t.id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.igw.id}"

}

resource "aws_subnet" "subnets" {
  count                   = 2
  vpc_id                  = "${aws_vpc.vpc.id}"
  cidr_block              = "10.255.${count.index}.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "${local.az[count.index]}"

  tags {
    Environment = "test"
  }
}

resource "aws_route_table_association" "a" {
  count = 2

  subnet_id      = "${aws_subnet.subnets.*.id[count.index]}"
  route_table_id = "${aws_route_table.t.id}"
}

module "eks" {
  source                 = "terraform-aws-modules/eks/aws"
  cluster_name           = "test-eks-cluster"
  subnets                = ["${aws_subnet.subnets.*.id}"]
  workers_group_defaults = "${var.workers_group_defaults_defaults}"

  tags = {
    Environment = "test"
  }

  vpc_id = "${aws_vpc.vpc.id}"
}

variable "workers_group_defaults_defaults" {
  type = "map"

  default = {
    asg_desired_capacity  = "1"         # Desired worker capacity in the autoscaling group.
    asg_max_size          = "1"         # Maximum worker capacity in the autoscaling group.
    asg_min_size          = "0"         # Minimum worker capacity in the autoscaling group.
    instance_type         = "t2.medium" # Size of the workers instances.
    root_volume_size      = "100"       # root volume size of workers instances.
    root_volume_type      = "gp2"       # root volume type of workers instances, can be 'standard', 'gp2', or 'io1'
    root_iops             = "0"         # The amount of provisioned IOPS. This must be set with a volume_type of "io1".
    ebs_optimized         = false       # sets whether to use ebs optimization on supported types.
    enable_monitoring     = true        # Enables/disables detailed monitoring.
    public_ip             = true        # Associate a public ip address with a worker
    kubelet_extra_args    = ""          # This string is passed directly to kubelet if set. Useful for adding labels or taints.
    autoscaling_enabled   = false       # Sets whether policy and matching tags will be added to allow autoscaling.
    protect_from_scale_in = false       # Prevent AWS from scaling in, so that cluster-autoscaler is solely responsible.

    #target_group_arns             = ""                              # A comma delimited list of ALB target group ARNs to be associated to the ASG
  }
}
