# Script PowerShell simples para push das imagens
$Region = "us-east-2"
$AccountId = "918859180133"
$ECR_REGISTRY = "$AccountId.dkr.ecr.$Region.amazonaws.com"

Write-Host "Iniciando push das imagens para ECR..." -ForegroundColor Green

# Login no ECR
Write-Host "Fazendo login no ECR..." -ForegroundColor Yellow
$loginCmd = "aws ecr get-login-password --region $Region | docker login --username AWS --password-stdin $ECR_REGISTRY"
Invoke-Expression $loginCmd

# Push das imagens
$images = @("backend", "frontend", "mobile")

foreach ($image in $images) {
    Write-Host "Fazendo push de $image..." -ForegroundColor Yellow
    
    # Tag para ECR
    docker tag "case-$image`:latest" "$ECR_REGISTRY/case-$image`:latest"
    
    # Push para ECR
    docker push "$ECR_REGISTRY/case-$image`:latest"
    
    Write-Host "$image enviado com sucesso!" -ForegroundColor Green
}

Write-Host "Processo concluido!" -ForegroundColor Green