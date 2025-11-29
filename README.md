# ⚡ Blockchain-based P2P Energy Trading Simulation
> **NetLogo를 활용한 블록체인 기반 분산 전력 거래 멀티 에이전트 시뮬레이션**

## 1. Project Overview (프로젝트 개요)
* **기간:** 2025.03 ~ 2025.07 (약 4개월)
* **참여 인원:** 3명
* **핵심 내용:** 중앙 서버 없는 분산 환경(Decentralized)에서 다수의 프로슈머(Prosumer) 에이전트들이 블록체인 스마트 컨트랙트 규칙에 따라 잉여 전력을 자율적으로 거래하는 시뮬레이션 모델 구현.

### 🏅 Achievements (수상 성과)
* **2025 대한전기학회(KIEE) 하계학술대회 '스마트 에너지 챌린지'**
    * **수상:** 장려상 (Encouragement Award)
    * **부문:** 캡스톤디자인 (Capstone Design)
    * **의의:** 블록체인 기술을 전력 시장(PPA/RE100)에 접목한 아이디어의 독창성과 시뮬레이션 구현의 완성도를 인정받음.

## 2. Motivation & Problem Definition (배경 및 문제 정의)
* **기존 전력망의 한계:** 중앙 집중형 전력망(Centralized Grid)은 송배전 손실이 크고, 소규모 재생에너지(DER) 거래 시 중개 비용이 발생하는 비효율성 존재.
* **해결 방안:**
    * **블록체인(Blockchain):** 신뢰할 수 없는 노드 간의 투명한 거래 원장(Ledger) 기록.
    * **P2P 거래:** 중개자 없이 생산자와 소비자가 직접 가격을 매칭.
* **프로젝트 목표:** 복잡한 전력 거래 환경을 **MAS(Multi-Agent System)** 로 모델링하여, 거래 성사율과 가격 수렴성을 검증하고자 함.

## 3. Tech Stack (기술 스택)
* **Simulation Tool:** NetLogo 6.4.0 (Agent-Based Modeling Environment)
* **Language:** NetLogo Language
* **Algorithm:** Double Auction (이중 경매 알고리즘), Smart Contract Logic

## 4. Simulation Scenarios (시뮬레이션 시나리오)
본 프로젝트는 목적에 따라 두 가지 시간 스케일(Time Scale)로 시뮬레이션을 이원화하여 구현하였습니다.

### 4-1. Micro-scale Simulation (Tick = 1 sec) : Security Focus
실시간 전력 거래 환경에서 발생할 수 있는 **악의적 공격(Malicious Attack)과 시스템의 방어 로직**을 검증하는 데 초점을 맞추었습니다.

#### 🛠 Key Logic & Implementation
1.  **State-Based Behavior (상태 기반 동작):**
    * 각 노드는 매초(`1 tick`) 달라지는 발전량/소비량에 따라 **Buyer ↔ Seller** 역할을 동적으로 스위칭합니다.
    * 넷로고의 `turtles-own` 변수를 활용하여 각 에이전트의 에너지 잔고(Balance)와 지갑(Wallet) 상태를 실시간 추적합니다.

2.  **Malicious Node Simulation (공격 시뮬레이션):**
    * 전체 네트워크의 `X%`를 악의적 노드로 설정하여, 보유하지 않은 에너지를 판매하려는 **허위 트랜잭션(False Transaction)** 을 지속적으로 생성합니다.
    * *Code Snippet:* `if malicious? [ set offer-amount (energy + random-float 10.0) ]` (실제 보유량보다 과장된 주문 생성)

3.  **Smart Contract Validation (보안 검증):**
    * 거래 체결 전, **Pre-validation Logic**이 실행되어 판매자의 실제 가용 에너지를 검증합니다.
    * 검증 실패 시 해당 트랜잭션은 **Invalid**로 간주하여 멤풀에서 즉시 폐기(Drop)하며, 이를 통해 **이중 지불(Double Spending)** 문제를 원천 차단했습니다.

#### 📊 Result
* 악의적 노드 비율이 20%일 때도 유효 거래(Valid Tx)만이 원장에 기록됨을 확인.
* P2P 거래의 신뢰성을 중앙 서버 없이 알고리즘적으로 보장.

### 4-2. Macro-scale Simulation (Tick = 6 hours) : Business Model & PPA
기업의 RE100 달성과 에너지 비용 절감을 위한 **PPA(전력 구매 계약) 및 VPP(가상 발전소) 모델**의 경제성을 검증하는 장기 시뮬레이션입니다.

#### 🛠 Key Logic & Implementation
1.  **PPA (Power Purchase Agreement) Logic:**
    * **Direct PPA:** 기업 노드(Company)가 발전소와 1:1로 장기 계약을 체결하여, 시장 가격(SMP) 변동과 무관하게 고정된 가격으로 전력을 공급받는 로직 구현.
    * *Code Snippet:* `setup-ppa-contracts` 프로시저를 통해 계약 용량과 기간을 설정하고, 매 틱마다 `execute-ppa-contracts`로 우선 공급 처리.
    * **Effect:** 전력 시장의 가격 변동성(Volatility)을 회피하고 안정적인 재생에너지 수급망 확보.

2.  **VPP (Virtual Power Plant) Aggregation:**
    * 분산된 소규모 재생에너지원(DER)을 하나의 발전소처럼 통합 관리하는 **VPP 노드** 도입.
    * 간헐적인 발전량을 VPP가 통합하여 PPA 계약 이행률을 높이는 구조 모델링.

3.  **RE100 & Economic Analysis (경제성 분석):**
    * **RE100 달성률 추적:** 전체 소비 전력 중 재생에너지(PPA + 자가발전) 비율을 실시간 계산.
    * **비용 비교:** `일반 전력망 사용 시 요금` vs `PPA 계약 + 블록체인 거래 시 비용`을 비교하여 프로젝트의 손익분기점(BEP) 분석.

#### 📊 Result
* PPA 도입 시 기업의 전력 구매 비용이 연간 약 X% 절감됨을 시뮬레이션으로 확인.
* 재생에너지 발전소 입장에서도 안정적인 수익원(Cash Flow) 확보 가능성을 입증.

## 5. Simulation Results (결과)
<img width="720" height="1017" alt="smartenergy_poster" src="https://github.com/user-attachments/assets/e81f6547-d26b-4ebe-a4aa-1e094274417b" />

* **실험 환경:** 총 N개의 에이전트(Prosumer 50, Consumer 50 등) 생성.
* **결과:**
    * 시뮬레이션 틱(Tick)이 지날수록 전력 수급 불균형이 해소되는 패턴 확인.
    * 중앙 통제 없이도 에이전트 간 자율 상호작용을 통해 시장 가격이 안정화됨을 검증.
* **(이미지 첨부 권장):** NetLogo의 Plot 그래프(가격 변화 추이, 거래량 등) 캡처 이미지.

## 6. Project Retrospective (배운 점 & 인사이트)

### 🚀 Technical Insights (기술적 성장)
* **분산 시스템의 동기화 문제 해결:**
  * 중앙 서버 없는 P2P 환경에서 다수의 노드가 동시에 거래를 요청할 때 발생하는 **트랜잭션 충돌(Race Condition)** 문제를 경험했습니다.
  * 이를 해결하기 위해 NetLogo의 `ask`와 `tick` 메커니즘을 활용하여 **이산 사건 시뮬레이션(Discrete Event Simulation)** 의 순차 처리 로직을 최적화했습니다.

* **이종(Heterogeneous) 네트워크 모델링:**
  * 단순히 똑같은 노드들이 아니라, `Company`(대량 거래, PPA), `Household`(소량 거래, 변동성 큼), `Malicious Node`(공격자) 등 성격이 다른 에이전트들이 섞여 있는 복잡한 네트워크를 설계하며 **시스템 복잡도 관리 역량**을 키웠습니다.

### 💡 Domain Knowledge (도메인 지식)
* **에너지 데이터의 특성 이해:**
  * 태양광/풍력 발전 데이터가 기상 상황에 따라 급격히 변동하는 **간헐성(Intermittency)** 을 직접 시뮬레이션 데이터로 구현해보며, 왜 에너지 분야에서 정교한 **예측(Prediction) 알고리즘** 과 **ESS(에너지 저장 장치)** 가 필수적인지 체감했습니다.

* **비즈니스 모델(PPA)과 기술의 결합:**
  * 기술적으로 완벽한 블록체인이라도 경제성이 없으면 무용지물임을 깨닫고, 기업의 **RE100 달성 시나리오(PPA)** 를 시뮬레이션에 통합하여 **'돈이 되는 기술'** 을 검증하는 시각을 갖게 되었습니다.

---
**Next Step:** 본 시뮬레이션을 통해 검증된 알고리즘을 바탕으로, 실제 하드웨어(Jetson/Raspberry Pi)와 통신 모듈을 연동한 **V2G(Vehicle-to-Grid) 실증 프로젝트**로 확장할 계획입니다.
