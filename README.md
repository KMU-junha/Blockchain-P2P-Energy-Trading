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

### 4-1. Micro-scale Simulation (Tick = 1 sec)
* **목표:** 실시간 거래 환경에서의 **시스템 안정성 및 보안(Security)** 검증.
* **핵심 기능:**
    * **공격 방어 메커니즘:** 악의적인 노드의 비정상 거래 시도나 트랜잭션 과부하 공격에 대한 방어 로직 구현.
    * **세부 거래 로직:** 초 단위의 전력 변동에 따른 스마트 컨트랙트 체결 정확도 테스트.
* **사용 파일:** `ticks1s_final.nlogo`

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
