.PHONY: init plan apply destroy status logs

# Inicializa Terraform
init:
	tflocal init

# Muestra qué recursos se van a crear/modificar
plan:
	tflocal plan

# Aplica la infraestructura sin preguntar "yes"
apply:
	tflocal apply -auto-approve

# Destruye toda la infraestructura sin preguntar
destroy:
	tflocal destroy -auto-approve

# Comando largo que tenías para ver el estado de las EC2
status:
	awslocal ec2 describe-instances --query "Reservations[*].Instances[*].{ID:InstanceId,State:State.Name}" --output table

# Comando que intentaste para ver los logs
logs:
	awslocal logs describe-log-streams --log-group-name "/aws/ec2/self-healing-app/nginx"
