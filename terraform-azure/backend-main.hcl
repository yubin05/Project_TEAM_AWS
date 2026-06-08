# 팀플 계정용 Terraform state 백엔드 설정
# TODO: 팀플 Azure 계정에 아래 리소스를 먼저 생성 (최초 1회)
#   az group create --name threetier-dr-tfstate-rg --location koreacentral
#   az storage account create --name threetierdrtfsmain --resource-group threetier-dr-tfstate-rg --sku Standard_LRS
#   az storage container create --name tfstate --account-name threetierdrtfsmain
#
# storage_account_name은 전역적으로 유일해야 함 (소문자/숫자, 3~24자) — 충돌 시 끝에 숫자를 붙여 조정
#
# terraform init -backend-config=backend-main.hcl

resource_group_name  = "threetier-dr-tfstate-rg"
storage_account_name = "threetierdrtfsmain"
container_name       = "tfstate"
