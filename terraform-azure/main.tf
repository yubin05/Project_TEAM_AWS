terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }

  required_version = ">= 1.10.0"

  # TODO: Azure 계정/구독 생성 후 Storage Account를 만들고 주석 해제
  # resource_group_name, storage_account_name, container_name은 backend-dev.hcl / backend-main.hcl 에서 주입
  # terraform init -backend-config=backend-dev.hcl   (개인 계정)
  # terraform init -backend-config=backend-main.hcl  (팀플 계정)
  #
  backend "azurerm" {
    key = "terraform.tfstate"
  }
}

provider "azurerm" {
  features {}

  subscription_id = var.azure_subscription_id

  # Free Trial 등 일부 구독에서 전체 Resource Provider 자동 등록이 매우 느리거나
  # 권한 문제로 멈출 수 있어 비활성화 (이 프로젝트가 쓰는 리소스의 프로바이더는 기본 등록되어 있음)
  # azurerm v3 속성명 (v4부터는 resource_provider_registrations = "none")
  skip_provider_registration = true
}

resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
}
