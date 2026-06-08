# AWS DMS → Azure DB 복제 작업 가이드

## 개요

DR 시나리오의 핵심 요구사항인 **RPO 5분 이내**를 만족시키기 위해, AWS Aurora MySQL의 변경분을
**AWS DMS의 ongoing replication(CDC)** 으로 Azure Database for MySQL에 단방향 복제한다.

평소엔 Aurora가 원본(source of truth), Azure DB는 읽기 전용 복제본이며,
**AWS 장애 시 Azure DB를 쓰기 가능한 Primary로 승격(promote)** 하는 페일오버 절차와 맞물리는 작업이다.
(전체 시나리오는 [infra-scenario.md](infra-scenario.md), 인프라 작업은 [azure-dr-infra-guide.md](azure-dr-infra-guide.md) 참고)

---

## 왜 단방향 복제인가 (양방향이 아닌 이유)

- "Active-Active 멀티클라우드"라고 해서 DB까지 양쪽에서 동시에 쓰기를 허용하는 멀티 마스터 구조로 가면, **충돌 해결(conflict resolution)이 매우 복잡**해지고 데이터 정합성이 깨지기 쉽다
- 그래서 **앱/컴퓨트 계층은 Active-Active(읽기 트래픽 50:50 분산), 데이터 계층은 Single-Writer**로 설계했다
  - 평소: 쓰기는 항상 Aurora(원본)로, 읽기는 양쪽에서 분산 처리
  - 장애 시: Azure DB를 Primary로 승격해 쓰기까지 인계 (이때부터는 Azure가 단독 원본)
- 이 구조에서 DMS의 역할은 "평소에 Aurora의 변경분을 Azure DB로 계속 흘려보내, 장애가 나도 최근 데이터(RPO 5분 이내)를 가진 채로 승격할 수 있게 준비해두는 것"

---

## AWS ↔ Azure 대응

| AWS | Azure | 비고 |
|---|---|---|
| DMS Replication Instance | (AWS 쪽에 그대로 둠 — Azure에 별도 인스턴스 불필요) | 복제 작업의 주체는 AWS DMS |
| Aurora MySQL | DMS Source Endpoint | 복제 원본 |
| — | Azure Database for MySQL | DMS Target Endpoint (복제 타겟) |
| CloudWatch | Azure Monitor + Log Analytics | 복제 지연/오류 모니터링 (로그 파트와 협업) |

---

## 해야 할 작업

### 1. 사전 확인 — Azure DB 네트워크 구성 파악

인프라 파트가 구성한 [azure-mysql.tf](../terraform-azure/azure-mysql.tf)는 **퍼블릭 엔드포인트 없이 VNet 내부 전용(Private access)** 으로 구성되어 있다. 즉 AWS DMS 복제 인스턴스(AWS VPC 내부)에서 Azure VNet 내부의 DB로 **직접 도달할 경로가 없는 상태**다.

가능한 경로 옵션 (보안 파트와 함께 결정 필요):

| 옵션 | 설명 | 장단점 |
|---|---|---|
| Site-to-Site VPN | AWS VPN Gateway ↔ Azure VPN Gateway로 두 VNet/VPC 연결 | 가장 안전하지만 구성 복잡, 추가 비용 |
| Private Link / Private Endpoint | Azure Private Link로 외부에서 안전하게 접근 | Azure 쪽 추가 리소스 필요 |
| 퍼블릭 엔드포인트 + TLS (제한적 허용) | Azure DB에 한시적으로 퍼블릭 액세스 + 방화벽 규칙(AWS DMS 인스턴스 IP만 허용) + TLS 강제 | 구성은 간단하지만 보안 측면에서 신중한 검토 필요 — DR 보조용 DB라는 점 고려 시 임시 테스트 용도로는 고려 가능 |

> 어떤 방식으로 갈지에 따라 `azure-mysql.tf`의 네트워크 설정을 변경해야 할 수 있으니, 결정되는 대로 인프라 파트와 공유할 것.

### 2. DMS Source Endpoint 설정 (AWS 쪽 — 기존 작업과 동일)

- 기존에 같은 계정 내 마이그레이션([[project_microservices]] 관련 작업)에서 썼던 패턴을 참고해 Aurora MySQL을 Source Endpoint로 등록
- `binlog` 기반 CDC를 쓰므로 Aurora의 `binlog_format = ROW`, 보존 기간 등 사전 설정 확인

### 3. DMS Target Endpoint 설정 (Azure DB 등록)

- Azure Database for MySQL의 접속 정보(호스트, 포트, 관리자 계정)를 Target Endpoint로 등록
- 1번에서 정한 네트워크 경로를 통해 연결 테스트 (`Test connection`)
- TLS 연결 강제 설정 확인 (Azure MySQL Flexible Server는 기본적으로 TLS 연결 요구)

### 4. Replication Task 생성 (Full Load + CDC)

- **Full Load + CDC** 마이그레이션 유형으로 설정 — 최초 전체 데이터 적재 후 지속적 변경분(CDC) 복제로 전환
- 테이블 매핑(replicating할 스키마/테이블 범위)은 마이크로서비스별 DB 분리 구조([[project_microservices]])를 반영해 설정
- 작업 시작 후 **CloudWatch(또는 Azure Monitor 연동 후에는 그쪽도 함께)** 에서 `CDCLatencySource`/`CDCLatencyTarget` 지표로 복제 지연 확인

### 5. RPO 검증

- 복제 지연이 **5분 이내**로 유지되는지 일정 기간 모니터링
- 부하가 몰릴 때(예: 예약 폭주 시뮬레이션) 지연이 어떻게 변하는지도 함께 확인 — RPO 목표를 못 채우면 DMS 인스턴스 사양 조정 또는 테이블 범위 축소 검토

### 6. 장애 전환(failover) 절차와의 연계

- AWS 장애 감지 → Azure DB를 읽기 전용 복제본에서 **쓰기 가능한 Primary로 승격(promote)** 하는 절차를 인프라 파트와 함께 정의하고 문서화
- 승격 시점에 **DMS 복제 작업도 중단**해야 함 (계속 흘려보내면 승격된 Azure DB에 덮어쓰기가 발생할 수 있음)
- **복구 후 failback**: AWS가 정상화되면, 장애 동안 Azure에 쌓인 변경분을 Aurora로 역방향 동기화한 뒤에야 안전하게 트래픽을 되돌릴 수 있음 — 이 역방향 동기화도 DMS(방향을 바꾼 새 태스크) 또는 별도 방법으로 준비해둘 것
- 전체 흐름은 5일차(또는 마지막 단계) **DR 시나리오 테스트**에서 실제로 검증

### 7. 모니터링/알림 구성 (로그 파트와 협업)

- Azure Monitor + Log Analytics에 복제 지연, 연결 끊김 등의 이벤트를 수집
- RPO 초과, 복제 중단 등 임계 상황에 대한 알림(Alert) 설정

---

## 주의할 점 / 협업 포인트

- **네트워크 경로 결정이 최우선** — 이게 정해져야 Target Endpoint 연결 테스트부터 진행 가능 (보안 파트와 빠르게 협의)
- **승격(promote)/failback 절차는 인프라 파트와 공동 설계** — DMS 작업 시작/중단 시점이 그 절차와 맞물려 있음
- **단방향 복제 전제가 깨지지 않도록 주의** — 평소엔 Azure DB에 직접 쓰기가 들어가지 않아야 복제가 정합성을 유지함 (앱 레벨에서 쓰기 경로가 항상 Aurora로 가도록 보장되어야 함, 인프라/CI-CD 파트와 확인)
