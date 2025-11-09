# PowerShell script para push das imagens para ECR
param(
    [string]$Region = "us-east-2",
    [string]$AccountId = "918859180133"
)

$ECR_REGISTRY = "$AccountId.dkr.ecr.$Region.amazonaws.com"

Write-Host "Iniciando push das imagens para ECR..." -ForegroundColor Green

# Função para fazer push de uma imagem
function Push-ImageToECR {
    param(
        [string]$ImageName,
        [string]$Tag = "latest"
    )
    
    Write-Host "Fazendo push de $ImageName..." -ForegroundColor Yellow
    
    # Tag para ECR
    $ecrImage = "$ECR_REGISTRY/case-$ImageName`:$Tag"
    docker tag "case-$ImageName`:$Tag" $ecrImage
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Tag criada: $ecrImage" -ForegroundColor Green
        
        # Push para ECR
        docker push $ecrImage
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "$ImageName enviado com sucesso!" -ForegroundColor Green
            Write-Host "URI: $ecrImage" -ForegroundColor Cyan
        } else {
            Write-Host "Erro ao enviar $ImageName" -ForegroundColor Red
        }
    } else {
        Write-Host "Erro ao criar tag para $ImageName" -ForegroundColor Red
    }
    
    Write-Host ""
}

# Fazer login no ECR
Write-Host "Fazendo login no ECR..." -ForegroundColor Yellow
try {
    $loginPassword = aws ecr get-login-password --region $Region 2>$null
    if ($loginPassword) {
        $loginPassword | docker login --username AWS --password-stdin $ECR_REGISTRY
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Login no ECR realizado com sucesso!" -ForegroundColor Green
        } else {
            Write-Host "Erro no login do Docker" -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "Erro ao obter senha do ECR" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "Erro ao executar comando AWS CLI: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Push das imagens
Push-ImageToECR "backend"
Push-ImageToECR "frontend" 
Push-ImageToECR "mobile"

Write-Host "Processo concluído!" -ForegroundColor Green
Write-Host ""
Write-Host "URIs das imagens:" -ForegroundColor Cyan
Write-Host "  Backend:  $ECR_REGISTRY/case-backend:latest" -ForegroundColor White
Write-Host "  Frontend: $ECR_REGISTRY/case-frontend:latest" -ForegroundColor White
Write-Host "  Mobile:   $ECR_REGISTRY/case-mobile:latest" -ForegroundColor White