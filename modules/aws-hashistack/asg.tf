resource "aws_launch_template" "nomad_client" {
  name_prefix = "nomad-client"
  image_id    = var.ami
  # instance_type          = var.client_instance_type
  instance_type          = ""
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.primary.id]
  user_data              = base64encode(data.template_file.user_data_client.rendered)

  iam_instance_profile {
    name = aws_iam_instance_profile.nomad_client.name
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name           = "${var.stack_name}-client"
      ConsulAutoJoin = "auto-join"
    }
  }

  block_device_mappings {
    device_name = "/dev/xvdd"
    ebs {
      volume_type           = "gp2"
      volume_size           = "50"
      delete_on_termination = "true"
    }
  }
}

resource "aws_autoscaling_group" "nomad_client" {
  name               = "${var.stack_name}-nomad_client"
  availability_zones = var.availability_zones
  desired_capacity   = var.client_count
  min_size           = 0
  max_size           = 10
  depends_on         = [aws_instance.nomad_server]
  load_balancers     = [aws_elb.nomad_client.name]

  mixed_instances_policy {
    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.nomad_client.id
        version            = "$Latest"
      }

      dynamic "override" {
        for_each = var.client_instance_types
        content {
          instance_type     = lookup(override.value, "instance_type", null)
          weighted_capacity = lookup(override.value, "weighted_capacity", null)
        }
      }
    }

    instances_distribution {
      on_demand_base_capacity                  = 1                    #var.on_demand_base_capacity
      on_demand_percentage_above_base_capacity = 0                    #var.on_demand_percentage_above_base_capacity
      spot_allocation_strategy                 = "capacity-optimized" #var.spot_allocation_strategy
      # spot_instance_pools                      = ""                   #var.spot_allocation_strategy == "lowest-price" ? var.spot_instance_pools : null
      # spot_max_price                           = var.spot_price
    }
  }

  tag {
    key                 = "OwnerName"
    value               = var.owner_name
    propagate_at_launch = true
  }
  tag {
    key                 = "OwnerEmail"
    value               = var.owner_email
    propagate_at_launch = true
  }
}
