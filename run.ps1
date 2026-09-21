Set-Location -Path $PSScriptRoot

Write-Host "Запуск серверов..." -ForegroundColor Cyan
docker compose up -d

Write-Host "`nСтатус контейнеров:" -ForegroundColor Cyan
docker compose ps

Write-Host "`nСерверы запущены:" -ForegroundColor Green
Write-Host "Frontend: http://localhost:5173" -ForegroundColor Green
Write-Host "Backend:  http://localhost:8000" -ForegroundColor Green
Write-Host "Логи:     docker compose logs -f" -ForegroundColor Gray
Write-Host "Стоп:     docker compose down" -ForegroundColor Gray