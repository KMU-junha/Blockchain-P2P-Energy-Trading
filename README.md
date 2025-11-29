# ⚡ Blockchain-based P2P Energy Trading Simulation
> **NetLogo를 활용한 블록체인 기반 분산 전력 거래 멀티 에이전트 시뮬레이션**

## 1. Project Overview (프로젝트 개요)
* **기간:** 2025.03 ~ 2025.07 (약 4개월)
* **참여 인원:** 3명
* **핵심 내용:** 중앙 서버 없는 분산 환경(Decentralized)에서 다수의 프로슈머(Prosumer) 에이전트들이 블록체인 스마트 컨트랙트 규칙에 따라 잉여 전력을 자율적으로 거래하는 시뮬레이션 모델 구현.

## 2. Motivation & Problem Definition (배경 및 문제 정의)
* **기존 전력망의 한계:** 중앙 집중형 전력망(Centralized Grid)은 송배전 손실이 크고, 소규모 재생에너지(DER) 거래 시 중개 비용이 발생하는 비효율성 존재.
* **해결 방안:**
    * **블록체인(Blockchain):** 신뢰할 수 없는 노드 간의 투명한 거래 원장(Ledger) 기록.
    * **P2P 거래:** 중개자 없이 생산자와 소비자가 직접 가격을 매칭.
* **프로젝트 목표:** 복잡한 전력 거래 환경을 **MAS(Multi-Agent System)**로 모델링하여, 거래 성사율과 가격 수렴성을 검증하고자 함.

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
    * 전체 네트워크의 `X%`를 악의적 노드로 설정하여, 보유하지 않은 에너지를 판매하려는 **허위 트랜잭션(False Transaction)**을 지속적으로 생성합니다.
    * *Code Snippet:* `if malicious? [ set offer-amount (energy + random-float 10.0) ]` (실제 보유량보다 과장된 주문 생성)

3.  **Smart Contract Validation (보안 검증):**
    * 거래 체결 전, **Pre-validation Logic**이 실행되어 판매자의 실제 가용 에너지를 검증합니다.
    * 검증 실패 시 해당 트랜잭션은 **Invalid**로 간주하여 멤풀에서 즉시 폐기(Drop)하며, 이를 통해 **이중 지불(Double Spending)** 문제를 원천 차단했습니다.

#### 📊 Result
* 악의적 노드 비율이 20%일 때도 유효 거래(Valid Tx)만이 원장에 기록됨을 확인.
* P2P 거래의 신뢰성을 중앙 서버 없이 알고리즘적으로 보장.

### 4-2. Macro-scale Simulation (Tick = 6 hours)
* **목표:** 장기적인 에너지 수급 패턴 분석 및 **RE100 등 비즈니스 모델** 실효성 검증.
* **핵심 기능:**
    * **장기 관찰:** 계절별/일별 태양광 발전량 변화와 소비 패턴을 장기간 추적.
    * **사업성 분석:** 잉여 전력 거래를 통해 얻을 수 있는 경제적 이익과 RE100 달성 가능성 시뮬레이션.
* **사용 파일:** `ticks6h_final.nlogo`

## 5. Simulation Results (결과)
<img width="720" height="1017" alt="smartenergy_poster" src="https://github.com/user-attachments/assets/e81f6547-d26b-4ebe-a4aa-1e094274417b" />

* **실험 환경:** 총 N개의 에이전트(Prosumer 50, Consumer 50 등) 생성.
* **결과:**
    * 시뮬레이션 틱(Tick)이 지날수록 전력 수급 불균형이 해소되는 패턴 확인.
    * 중앙 통제 없이도 에이전트 간 자율 상호작용을 통해 시장 가격이 안정화됨을 검증.
* **(이미지 첨부 권장):** NetLogo의 Plot 그래프(가격 변화 추이, 거래량 등) 캡처 이미지.

## 6. Project Retrospective (배운 점)
* **Multi-Agent System 이해:** 개별 에이전트의 단순한 행동 규칙이 시스템 전체의 거동(Emergence)으로 이어지는 과정을 시각적으로 확인.
* **알고리즘 구현 역량:** 실제 블록체인 네트워크는 아니지만, 거래 메커니즘과 합의 알고리즘의 논리를 코드로 구현하며 시스템 설계 능력을 키움.
* **전자공학적 응용:** 분산 제어 시스템(Distributed Control System)의 기초가 되는 노드 간 통신 및 데이터 동기화 원리 습득.
