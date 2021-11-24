# Full Horizontal Autoscaling Demo
The demo resources contained within this directory provide a basic demo for running full horizontal
application and cluster autoscaling using the Nomad Autoscaler. The application will scale based on
the average number of connections per instance of our application. The cluster will scale based on
the total allocated resources across our pool of Nomad client nodes.

***The infrastructure built as part of the demo has billable costs and is not suitable for
production use***

### Requirements
In order to build and run the demo, the following applications are required locally:
 * HashiCorp Nomad [0.12.0](https://releases.hashicorp.com/nomad/0.12.0/)
 * HashiCorp Packer [1.5.6](https://releases.hashicorp.com/packer/1.5.6/)
 * HashiCorp Terraform [0.12.23](https://releases.hashicorp.com/terraform/0.12.23/)
 * rakyll/hey [latest](https://github.com/rakyll/hey#installation)

## Infrastructure Build
There are specific steps to build the infrastructure depending on which provider you wish to use.
Please navigate to the appropriate section below.
 * [Amazon Web Services](./_docs/aws.md)

## The Demo
The steps below this point are generic across providers and form the main part of this demo. Enjoy.

## Generate Application Load
In order to generate some initial load we will call the `hey` application. This will cause the
application to scale up slightly.
```
hey -z 10m -c 20 -q 40 $NOMAD_CLIENT_DNS:80 &
```

Viewing the autoscaler logs or the Grafana dashboard should show the application count increase
from `1` to `2`. Once this scaling has taken place, you can trigger additional load on the app that
causes further scaling.
```
hey -z 10m -c 20 -q 40 $NOMAD_CLIENT_DNS:80 &
```

This will again causes the application to scale which in-turn reduces the available resources on
our cluster. The reduction is such that the Autoscaler will decide a cluster scaling action is
required and trigger the appropriate action.
```
2020-07-06T08:44:46.460Z [INFO]  agent.worker.check_handler: received policy check for evaluation: check=avg_sessions policy_id=6a60613b-be07-ba2d-1170-63237c5bb454 source=prometheus strategy=target-value target=nomad-target
2020-07-06T08:44:46.460Z [INFO]  agent.worker.check_handler: fetching current count: check=avg_sessions policy_id=6a60613b-be07-ba2d-1170-63237c5bb454 source=prometheus strategy=target-value target=nomad-target
2020-07-06T08:44:46.460Z [INFO]  agent.worker.check_handler: querying source: check=avg_sessions policy_id=6a60613b-be07-ba2d-1170-63237c5bb454 source=prometheus strategy=target-value target=nomad-target query=scalar(sum(traefik_entrypoint_open_connections{entrypoint="webapp"})/scalar(nomad_nomad_job_summary_running{task_group="demo"}))
2020-07-06T08:44:46.468Z [INFO]  agent.worker.check_handler: calculating new count: check=avg_sessions policy_id=6a60613b-be07-ba2d-1170-63237c5bb454 source=prometheus strategy=target-value target=nomad-target count=1 metric=19
2020-07-06T08:44:46.469Z [INFO]  agent.worker.check_handler: scaling target: check=avg_sessions policy_id=6a60613b-be07-ba2d-1170-63237c5bb454 source=prometheus strategy=target-value target=nomad-target from=1 to=2 reason="scaling up because factor is 1.900000" meta=map[]
2020-07-06T08:44:46.487Z [INFO]  agent.worker.check_handler: successfully submitted scaling action to target: check=avg_sessions policy_id=6a60613b-be07-ba2d-1170-63237c5bb454 source=prometheus strategy=target-value target=nomad-target desired_count=2
2020-07-06T08:44:46.487Z [INFO]  agent.worker: policy evaluation complete: policy_id=6a60613b-be07-ba2d-1170-63237c5bb454 target=nomad-target
2020-07-06T08:44:46.487Z [DEBUG] policy_manager.policy_handler: scaling policy has been placed into cooldown: policy_id=6a60613b-be07-ba2d-1170-63237c5bb454 cooldown=1m0s
```

The Nomad Autoscaler logs will detail the action which can also be viewed via the Grafana dashboard
or the provide UI.
```
2020-07-06T08:46:16.541Z [INFO]  agent.worker: received policy for evaluation: policy_id=bf68649a-d087-2e69-362e-bbe71b5544f7 target=aws-asg
2020-07-06T08:46:16.542Z [INFO]  agent.worker.check_handler: received policy check for evaluation: check=mem_allocated_percentage policy_id=bf68649a-d087-2e69-362e-bbe71b5544f7 source=prometheus strategy=target-value target=aws-asg
2020-07-06T08:46:16.542Z [INFO]  agent.worker.check_handler: fetching current count: check=mem_allocated_percentage policy_id=bf68649a-d087-2e69-362e-bbe71b5544f7 source=prometheus strategy=target-value target=aws-asg
2020-07-06T08:46:16.542Z [INFO]  agent.worker.check_handler: received policy check for evaluation: check=cpu_allocated_percentage policy_id=bf68649a-d087-2e69-362e-bbe71b5544f7 source=prometheus strategy=target-value target=aws-asg
2020-07-06T08:46:16.542Z [INFO]  agent.worker.check_handler: fetching current count: check=cpu_allocated_percentage policy_id=bf68649a-d087-2e69-362e-bbe71b5544f7 source=prometheus strategy=target-value target=aws-asg
2020-07-06T08:46:16.683Z [INFO]  agent.worker.check_handler: querying source: check=cpu_allocated_percentage policy_id=bf68649a-d087-2e69-362e-bbe71b5544f7 source=prometheus strategy=target-value target=aws-asg query=scalar(sum(nomad_client_allocated_cpu{node_class="hashistack"}*100/(nomad_client_unallocated_cpu{node_class="hashistack"}+nomad_client_allocated_cpu{node_class="hashistack"}))/count(nomad_client_allocated_cpu))
```

## Remove Application Load
We can now simulate a reduction in load on the application by killing the running `hey` processes.
```
pkill hey
```

The reduction in load will cause the Autoscaler to firstly scale in the taskgroup. Once the
taskgroup has scaled in a sufficient amount, the Autoscaler will scale in the cluster. It
performs this work by selecting a node to remove, draining the node of all work and then
terminating it within the provider.
```
2020-07-06T08:50:16.648Z [INFO]  agent.worker: received policy for evaluation: policy_id=bf68649a-d087-2e69-362e-bbe71b5544f7 target=aws-asg
2020-07-06T08:50:16.648Z [INFO]  agent.worker.check_handler: received policy check for evaluation: check=mem_allocated_percentage policy_id=bf68649a-d087-2e69-362e-bbe71b5544f7 source=prometheus strategy=target-value target=aws-asg
2020-07-06T08:50:16.648Z [INFO]  agent.worker.check_handler: fetching current count: check=mem_allocated_percentage policy_id=bf68649a-d087-2e69-362e-bbe71b5544f7 source=prometheus strategy=target-value target=aws-asg
2020-07-06T08:50:16.648Z [INFO]  agent.worker.check_handler: received policy check for evaluation: check=cpu_allocated_percentage policy_id=bf68649a-d087-2e69-362e-bbe71b5544f7 source=prometheus strategy=target-value target=aws-asg
2020-07-06T08:50:16.648Z [INFO]  agent.worker.check_handler: fetching current count: check=cpu_allocated_percentage policy_id=bf68649a-d087-2e69-362e-bbe71b5544f7 source=prometheus strategy=target-value target=aws-asg
2020-07-06T08:50:16.791Z [INFO]  agent.worker.check_handler: querying source: check=mem_allocated_percentage policy_id=bf68649a-d087-2e69-362e-bbe71b5544f7 source=prometheus strategy=target-value target=aws-asg query=scalar(sum(nomad_client_allocated_memory{node_class="hashistack"}*100/(nomad_client_unallocated_memory{node_class="hashistack"}+nomad_client_allocated_memory{node_class="hashistack"}))/count(nomad_client_allocated_memory))
2020-07-06T08:50:16.795Z [INFO]  agent.worker.check_handler: calculating new count: check=mem_allocated_percentage policy_id=bf68649a-d087-2e69-362e-bbe71b5544f7 source=prometheus strategy=target-value target=aws-asg count=2 metric=32
2020-07-06T08:50:16.824Z [INFO]  agent.worker.check_handler: querying source: check=cpu_allocated_percentage policy_id=bf68649a-d087-2e69-362e-bbe71b5544f7 source=prometheus strategy=target-value target=aws-asg query=scalar(sum(nomad_client_allocated_cpu{node_class="hashistack"}*100/(nomad_client_unallocated_cpu{node_class="hashistack"}+nomad_client_allocated_cpu{node_class="hashistack"}))/count(nomad_client_allocated_cpu))
```

## Destroy the Infrastructure
It is important to destroy the created infrastructure as soon as you are finished with the demo. In
order to do this you should navigate to your Terraform env directory and issue a `destroy` command.
```
$ cd terraform/env/<env>
$ terraform destroy --auto-approve
```

Please also check and complete any provider specific steps:
 * [Amazon Web Services](./aws.md#post-demo-steps)
