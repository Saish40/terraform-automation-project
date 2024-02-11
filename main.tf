# Create a VPC
resource "aws_vpc" "VPC" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "VPC"
  }

}
# Create 2 subnets 
resource "aws_subnet" "subnet1" {
  vpc_id                  = aws_vpc.VPC.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = var.availability_zone_1
  tags = {
    Name = "Subnet1"
  }

}
resource "aws_subnet" "subnet2" {
  vpc_id                  = aws_vpc.VPC.id
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = true
  availability_zone       = var.availability_zone_2
  tags = {
    Name = "Subnet2"
  }

}
# Create Internet gateway
resource "aws_internet_gateway" "IGW" {
  vpc_id = aws_vpc.VPC.id
  tags = {
    Name = "autoscaling-igw"
  }

}
# Create route tables
resource "aws_route_table" "route_table_1" {
  vpc_id = aws_vpc.VPC.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.IGW.id
  }
  tags = {
    Name = "RT1"
  }
}
resource "aws_route_table" "route_table_2" {
  vpc_id = aws_vpc.VPC.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.IGW.id
  }
  tags = {
    Name = "RT2"
  }
}
# Create route table association
resource "aws_route_table_association" "rt_association_1" {
  subnet_id      = aws_subnet.subnet1.id
  route_table_id = aws_route_table.route_table_1.id
}

resource "aws_route_table_association" "rt_association_2" {
  subnet_id      = aws_subnet.subnet2.id
  route_table_id = aws_route_table.route_table_2.id
}

# Create a security group that allows inbound HTTP traffic and SSH access
resource "aws_security_group" "sg" {
  name        = "autoscaling-sg"
  description = "Allow HTTP and SSH access"
  vpc_id      = aws_vpc.VPC.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "autoscaling-sg"
  }
}
# Create a launch template
resource "aws_launch_template" "lt" {
  name                   = "launch-template"
  vpc_security_group_ids = [aws_security_group.sg.id]
  image_id               = var.image_id
  instance_type          = var.instance_type
  key_name               = var.key_name
  user_data              = base64encode(file("script.sh"))

}
# Create Autoscaling group
resource "aws_autoscaling_group" "asg" {
  name             = "autoscaling-asg"
  min_size         = var.min_size
  max_size         = var.max_size
  desired_capacity = var.desired_size
  launch_template {
    id      = aws_launch_template.lt.id
    version = "$Latest"
  }
  vpc_zone_identifier = [aws_subnet.subnet1.id, aws_subnet.subnet2.id]
  health_check_type   = "EC2"
  tag {
    key                 = "Name"
    value               = "autoscale-instance"
    propagate_at_launch = true
  }
}
# Create target group
resource "aws_lb_target_group" "target_group" {
  name        = "tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.VPC.id
  target_type = "instance"
  health_check {
    path = "/"
  }

}
# Create an application load balancer that distributes traffic to the target group
resource "aws_lb" "alb" {
  name               = "autoscale-alb"
  load_balancer_type = var.load_balancer_type
  subnets            = [aws_subnet.subnet1.id, aws_subnet.subnet2.id]
  security_groups    = [aws_security_group.sg.id]

}
# Create a listener that forwards requests to the target group
resource "aws_lb_listener" "alb_listner" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target_group.arn
  }

}
# Attach the target group to the autoscaling group
resource "aws_autoscaling_attachment" "asg_attach" {
  autoscaling_group_name = aws_autoscaling_group.asg.id
  lb_target_group_arn    = aws_lb_target_group.target_group.arn

}
# Create a ASG policy for scaling
resource "aws_autoscaling_policy" "scale_up" {
  name                   = "autoscaling-scale-up"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.asg.name
}

resource "aws_autoscaling_policy" "scale_down" {
  name                   = "autoscaling-scale-down"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.asg.name
}
# Create a cloudwatch metric alarm that triggers when the average load is reached
resource "aws_cloudwatch_metric_alarm" "high_load_alarm" {
  alarm_name                = "asg-high-alarm"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = 1
  metric_name               = var.metric_name
  namespace                 = var.namespace
  period                    = var.period
  statistic                 = "Average"
  threshold                 = var.threshold_high
  insufficient_data_actions = []
  dimensions = {
    autoscaling_group_name = aws_autoscaling_group.asg.name
  }
  alarm_actions = [aws_autoscaling_policy.scale_up.arn]

}
resource "aws_cloudwatch_metric_alarm" "low_load_alarm" {
  alarm_name                = "asg-low-alarm"
  comparison_operator       = "LessThanOrEqualToThreshold"
  evaluation_periods        = 1
  metric_name               = var.metric_name
  namespace                 = var.namespace
  period                    = var.period
  statistic                 = "Average"
  threshold                 = var.threshold_low
  insufficient_data_actions = []
  dimensions = {
    autoscaling_group_name = aws_autoscaling_group.asg.name
  }
  alarm_actions = [aws_autoscaling_policy.scale_down.arn]

}
# Create a schedule to refresh all instances at a particular time
resource "aws_autoscaling_schedule" "schedule" {
  scheduled_action_name  = "autoscaling-refresh"
  min_size               = var.min_size
  max_size               = var.max_size
  desired_capacity       = var.desired_size
  start_time             = var.start_time
  recurrence             = var.recurrence
  autoscaling_group_name = aws_autoscaling_group.asg.name
}
# Create an SNS topic that receives notifications from the autoscaling group
resource "aws_sns_topic" "topic" {
  name = "autoscaling-topic"
}
# Create an SNS subscription that sends email alerts to a given address
resource "aws_sns_topic_subscription" "subscription" {
  topic_arn = aws_sns_topic.topic.arn
  protocol  = "email"
  endpoint  = var.sns_email
}
# Create an autoscaling notification that publishes events to the SNS topic
resource "aws_autoscaling_notification" "notification" {
  group_names = [aws_autoscaling_group.asg.name]
  notifications = [
    "autoscaling:EC2_INSTANCE_LAUNCH",
    "autoscaling:EC2_INSTANCE_TERMINATE",
    "autoscaling:EC2_INSTANCE_LAUNCH_ERROR",
    "autoscaling:EC2_INSTANCE_TERMINATE_ERROR"
  ]
  topic_arn = aws_sns_topic.topic.arn
}