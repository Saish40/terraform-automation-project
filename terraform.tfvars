availability_zone_1 = "us-east-1a"
availability_zone_2 = "us-east-1b"
image_id            = "ami-0c7217cdde317cfec"
instance_type       = "t2.micro"
key_name            = "ASG"
min_size            = "1"
max_size            = "3"
desired_size        = "1"
load_balancer_type  = "application"
metric_name         = "CPUUtilization"
period              = "120"
namespace           = "AWS/EC2"
threshold_high      = "75"
threshold_low       = "50"
start_time          = "2024-02-11T11:25:00Z"
recurrence          = "0 0 * * *"
sns_email           = "Enter your email here to receive notifications"
