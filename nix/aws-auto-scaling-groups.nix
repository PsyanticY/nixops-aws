{ config, lib, uuid, name, ... }:

with import ./lib.nix lib;
with lib;

{
  imports = [ ./common-ec2-auth-options.nix ];

  options = {

    autoScalingGroupName = mkOption {
      default = "nixops-${uuid}-${name}";
      type = types.str;
      description = "Name of the auto scaling group.";
    };

    launchTemplateName = mkOption {
      type = with types; either str (resource "aws-ec2-launch-template");
      apply = x: if builtins.isString x then x else x.templateName;
      description = "The launch template configuration for the auto scaling group";
    };
    launchTemplateVersion = mkOption {
      default = "$Default";
      type = with types; either str (resource "aws-ec2-launch-template");
      apply = x: if builtins.isString x then x else "res-" + x._name;
      description = "The launch template version to use";
    };
    launchTemplateOverrides = mkOption {
      default = [];
      type = types.listOf types.attrs;
      example = ''
        {
          InstanceType = 'm5.large';
          WeightedCapacity = "1";
        };
        ...
        check https://boto3.amazonaws.com/v1/documentation/api/latest/reference/services/autoscaling.html#AutoScaling.Client.create_auto_scaling_group
        for more details
      '';
      description = "Specific parameters to override launch template configurations.";
    };

    onDemandAllocationStrategy = mkOption {
      default = "prioritized";
      type = types.enum [ "prioritized" ];
      description = ''
        Indicates how to allocate instance types to fulfill
        On-Demand capacity. Currently the only valid value is prioritized.
      '';
    };

    onDemandBaseCapacity = mkOption {
      default = 0;
      type = types.int;
      description = ''
        The minimum amount of the Auto Scaling group's capacity that
        must be fulfilled by On-Demand Instances. This base portion
        is provisioned first as your group scales.
      '';
    };

    onDemandPercentageAboveBaseCapacity = mkOption {
      default = 100;
      type = types.int;
      description = ''
      Controls the percentages of On-Demand Instances and Spot Instances
      for your additional capacity beyond OnDemandBaseCapacity.
      '';
    };

    spotAllocationStrategy = mkOption {
      default = "capacity-optimized";
      type = types.enum [ "lowest-price" "capacity-optimized" ];
      description = ''
        Indicates how to allocate instances across Spot Instance pools.
      '';
    };

    spotInstancePools = mkOption {
      default = 2;
      type = types.int;
      description = ''
       The number of Spot Instance pools across which to allocate your
       Spot Instances. The Spot pools are determined from the different
       instance types in the Overrides array of LaunchTemplate
      '';
    };

    spotMaxPrice = mkOption {
      default = "";
      type = types.str;
      description = ''
      The maximum price per unit hour that you are willing to pay
      for a Spot Instance.
      '';
    };

    minSize = mkOption {
      type = types.int;
      description = "The minimum size of the group.";
    };

    maxSize = mkOption {
      type = types.int;
      description = "The maximum size of the group.";
    };

    desiredCapacity = mkOption {
      # how can we make minSize the default for this
      type = types.int;
      description = ''
        The number of Amazon EC2 instances that the Auto
        Scaling group attempts to maintain
      '';
    };

    defaultCooldown = mkOption {
      default = 300;
      type = types.int;
      description = ''
        he amount of time, in seconds, after a scaling activity
        completes before another scaling activity can start.
      '' ;
    };

    availabilityZones lofs
    LoadBalancerNames lofs
    TargetGroupARNs lofs
    HealthCheckType str
    HealthCheckGracePeriod int
    PlacementGroup str
    VPCZoneIdentifier str
    TerminationPolicies lofs
    NewInstancesProtectedFromScaleIn bool
    LifecycleHookSpecificationList list of stuff i need to check
    MaxInstanceLifetime str
    ServiceLinkedRoleARN
    tags

  }// (import ./common-ec2-options.nix { inherit lib; });

  config._type = "aws-auto-scaling-groups";
}