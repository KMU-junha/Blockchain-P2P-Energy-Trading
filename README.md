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

## 4. Key Features & Logic (핵심 기능 및 설계)
*(여기에 NetLogo 시뮬레이션 실행 화면 캡처나 구조도를 넣으면 좋습니다)*

### 4-1. Agent Modeling (에이전트 설계)
* **Prosumer (생산자 겸 소비자):** 태양광 발전량과 자체 소비량에 따라 '판매자(Seller)' 또는 '구매자(Buyer)'로 상태가 동적으로 변함.
* **Smart Contract Node:** 거래 조건을 검증하고 원장에 기록하는 논리적 노드 구현.

### 4-2. Trading Algorithm (거래 알고리즘)
1.  **Bidding (입찰):** 각 에이전트는 현재 보유 전력량과 시장 가격을 기반으로 매도/매수 주문 생성.
2.  **Matching (매칭):** **Double Auction(이중 경매)** 방식을 통해 최적의 거래 가격 도출 및 거래 체결.
3.  **Settlement (청산):** 체결된 거래 내역을 리스트(Simulated Blockchain)에 업데이트하고 에너지/토큰 잔액 갱신.

## 5. Simulation Results (결과)
* **실험 환경:** 총 N개의 에이전트(Prosumer 50, Consumer 50 등) 생성.
* **결과:**
    * 시뮬레이션 틱(Tick)이 지날수록 전력 수급 불균형이 해소되는 패턴 확인.
    * 중앙 통제 없이도 에이전트 간 자율 상호작용을 통해 시장 가격이 안정화됨을 검증.
* **(이미지 첨부 권장):** NetLogo의 Plot 그래프(가격 변화 추이, 거래량 등) 캡처 이미지.

## 6. Project Retrospective (배운 점)
* **Multi-Agent System 이해:** 개별 에이전트의 단순한 행동 규칙이 시스템 전체의 거동(Emergence)으로 이어지는 과정을 시각적으로 확인.
* **알고리즘 구현 역량:** 실제 블록체인 네트워크는 아니지만, 거래 메커니즘과 합의 알고리즘의 논리를 코드로 구현하며 시스템 설계 능력을 키움.
* **전자공학적 응용:** 분산 제어 시스템(Distributed Control System)의 기초가 되는 노드 간 통신 및 데이터 동기화 원리 습득.
