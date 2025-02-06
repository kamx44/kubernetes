param (
    [string]$MasterIP,
    [string]$SSHKeyPath
)

# SSH into master node and get the join command
$joinCommand = ssh -o StrictHostKeyChecking=no -i $SSHKeyPath kamil@$MasterIP "cat /tmp/join_command.sh" #2>$null

# Convert output to JSON for Terraform
Write-Output "{ `"join_command`": `"$joinCommand`" }"