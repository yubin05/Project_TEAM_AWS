# ================================================================
# Failback: AWS 복구 시 Azure Active 기간에 쌓인 변경분을 S3로 되돌린다.
#
# Azure Blob (hotels, uploads 컨테이너) → 로컬 임시 폴더 (azcopy)
#                                       → S3 uploads 버킷  (aws s3 sync)
#
# 사전 준비:
#   - azcopy, aws cli 설치 + AWS 자격 증명(--profile default) 구성
#   - Storage Account에 대한 SAS 토큰 발급 (Azure Portal > 컨테이너 > Shared access tokens, 읽기/목록 권한)
#
# 사용:
#   .\failback-blob-to-s3.ps1 -StorageAccount threetierdruploadsmain -Sas "<SAS 토큰>" -S3Bucket threetier-uploads-<account-id>
# ================================================================

param(
  [Parameter(Mandatory = $true)] [string]$StorageAccount,
  [Parameter(Mandatory = $true)] [string]$Sas,
  [Parameter(Mandatory = $true)] [string]$S3Bucket,
  [string]$Region = "ap-northeast-2",
  [string]$TempDir = "$env:TEMP\blob-failback"
)

$containers = @("hotels", "uploads")

foreach ($container in $containers) {
  $localPath = Join-Path $TempDir $container
  New-Item -ItemType Directory -Force -Path $localPath | Out-Null

  Write-Host "==> Azure Blob $container -> $localPath (azcopy)"
  azcopy copy "https://$StorageAccount.blob.core.windows.net/${container}?$Sas" $localPath --recursive

  Write-Host "==> $localPath -> s3://$S3Bucket/$container (aws s3 sync)"
  aws s3 sync $localPath "s3://$S3Bucket/$container" --profile default --region $Region
}

Write-Host "==> Failback sync 완료"
