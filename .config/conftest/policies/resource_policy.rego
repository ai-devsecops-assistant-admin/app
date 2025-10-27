package main

import future.keywords.if
import future.keywords.in

# Resource management and best practices

# Validate replica count for production
warn[msg] if {
	input.kind == "Deployment"
	input.metadata.namespace in ["prod", "production"]
	input.spec.replicas < 2

	msg := sprintf(
		"WARN: Production Deployment '%s' should have at least 2 replicas for high availability",
		[input.metadata.name]
	)
}

# Require PodDisruptionBudget for production
warn[msg] if {
	input.kind == "Deployment"
	input.metadata.namespace in ["prod", "production"]
	input.spec.replicas >= 2
	# This would need to be checked against actual PDBs in the cluster
	# For now, this is a reminder

	msg := sprintf(
		"WARN: Production Deployment '%s' with multiple replicas should have a PodDisruptionBudget",
		[input.metadata.name]
	)
}

# Validate CPU limits are reasonable
warn[msg] if {
	input.kind == "Deployment"
	some container in input.spec.template.spec.containers
	cpu_limit := parse_cpu(container.resources.limits.cpu)
	cpu_request := parse_cpu(container.resources.requests.cpu)
	cpu_limit > cpu_request * 4

	msg := sprintf(
		"WARN: Container '%s' has CPU limit/request ratio > 4x, which may cause throttling",
		[container.name]
	)
}

# Validate memory limits are reasonable
warn[msg] if {
	input.kind == "Deployment"
	some container in input.spec.template.spec.containers
	mem_limit := parse_memory(container.resources.limits.memory)
	mem_request := parse_memory(container.resources.requests.memory)
	mem_limit > mem_request * 4

	msg := sprintf(
		"WARN: Container '%s' has memory limit/request ratio > 4x",
		[container.name]
	)
}

# Helper to parse CPU (simplified)
parse_cpu(cpu) := result if {
	result := to_number(trim_suffix(cpu, "m"))
}

parse_cpu(cpu) := result if {
	not endswith(cpu, "m")
	result := to_number(cpu) * 1000
}

# Helper to parse memory (simplified - converts to Mi)
parse_memory(mem) := result if {
	endswith(mem, "Mi")
	result := to_number(trim_suffix(mem, "Mi"))
}

parse_memory(mem) := result if {
	endswith(mem, "Gi")
	result := to_number(trim_suffix(mem, "Gi")) * 1024
}

parse_memory(mem) := result if {
	endswith(mem, "Ki")
	result := to_number(trim_suffix(mem, "Ki")) / 1024
}

# Validate HPA configuration
warn[msg] if {
	input.kind == "HorizontalPodAutoscaler"
	input.spec.minReplicas < 2
	input.metadata.namespace in ["prod", "production"]

	msg := sprintf(
		"WARN: Production HPA '%s' should have minReplicas >= 2",
		[input.metadata.name]
	)
}

# Validate HPA targets
warn[msg] if {
	input.kind == "HorizontalPodAutoscaler"
	some metric in input.spec.metrics
	metric.type == "Resource"
	metric.resource.name == "cpu"
	metric.resource.target.averageUtilization > 85

	msg := sprintf(
		"WARN: HPA '%s' has CPU target > 85%%, may cause frequent scaling",
		[input.metadata.name]
	)
}

# Require anti-affinity for production
warn[msg] if {
	input.kind == "Deployment"
	input.metadata.namespace in ["prod", "production"]
	input.spec.replicas >= 2
	not input.spec.template.spec.affinity.podAntiAffinity

	msg := sprintf(
		"WARN: Production Deployment '%s' with multiple replicas should use pod anti-affinity",
		[input.metadata.name]
	)
}

# Validate service type
deny[msg] if {
	input.kind == "Service"
	input.spec.type == "LoadBalancer"
	not input.metadata.annotations["service.beta.kubernetes.io/aws-load-balancer-type"]

	msg := sprintf(
		"FAIL: LoadBalancer Service '%s' should specify cloud provider annotations",
		[input.metadata.name]
	)
}

# Warn about NodePort services
warn[msg] if {
	input.kind == "Service"
	input.spec.type == "NodePort"

	msg := sprintf(
		"WARN: Service '%s' uses NodePort - consider using Ingress instead",
		[input.metadata.name]
	)
}
