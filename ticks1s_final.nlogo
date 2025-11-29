; === 블록체인 기반 분산 에너지 거래 시뮬레이션 ===
; NetLogo 6.4.0 (64-bit)

extensions [time table]

; 1. 에이전트 및 글로벌 변수 정의
breed [ems-nodes ems]
breed [household-nodes household]
breed [company-nodes company]
breed [plant-nodes plant]
links-own [ttl creation-tick]

globals [
  economic-efficiency
  security-response-time
  monthly-shortages
  energy-price
  current-datetime
  selected-who
  selection-mode?
  validators                 ; 검증자 풀 추가
  shared-energy-status       ; 모든 노드의 실시간 상태 공유 리스트
  monthly-electricity-prices ; 12개월 전기요금 리스트
  token-price                ; 토큰 1개당 가격
  prev-positive-token-delta  ; 틱 별로 토큰 변화량 확인 변수
  prev-negative-token-delta
  tick-positive-token-delta
  tick-negative-token-delta
  solar-hourly-ratio       ;; 태양광 월별 6시간대별 발전 비율 (12 x 4)
  wind-hourly-ratio        ;; 풍력 월별 6시간대별 발전 비율 (12 x 4)
  solar-monthly-production ;; 태양광 월별 총 발전량 (MWh)
  wind-monthly-production  ;; 풍력 월별 총 발전량 (MWh)
  tick-peer-trade-count ; EMS/발전소 제외 노드 간 틱별 거래 횟수

  ; ========블록 관련========
  pending-transactions   ; 블록에 들어갈 거래 임시 저장
  block-id
  block-counter
  timestamp
  proposer
  last-block-hash        ; 직전 블록의 해시값
  ascii-table            ; 아스키 코드
  validator-rotation-tick ; 검증자 교체 주기 카운터
  proposed-block         ; 현재 제안된 블록 데이터
  block-approvals        ; 각 블록에 대한 검증자들의 승인(서명) 리스트
  consensus-threshold    ; 합의에 필요한 승인 수
  sync-needed ; 동기화 필요 여부 플래그

  ;=========거래 관련========
  offer-list                  ;; 모든 활성 오퍼 저장
  offer-counter          ; 거래 오퍼 고유 카운터
  accepted-offer-counter
  rejected-offer-counter
  tick-offer-counter
  offer-per-tick-limit  ;; 한 틱당 최대 오퍼 생성 수
  ems-node
  trusted-nodes         ;; EMS가 신뢰하는 노드들(agentset)
  max-pending-size      ;; pending-transactions 최대 허용 크기

  ;==========공격 관련========
  ddos-attackers        ;; DDoS 공격자로 선택된 turtles
  replay-attack-count   ;; 재전송 횟수
  timestamp-replay-detected?  ;; 공격 감지 플래그
  attack-log                    ; 공격 로그 저장 리스트
  attack-detection-history      ; 공격 감지 이력
  ddos-attack-count            ; DDoS 공격 횟수
  timestamp-replay-count       ; 타임스탬프 재전송 공격 횟수
  attack-response-times        ; 공격 대응 시간 기록
  network-delay-measurements   ; 네트워크 지연 측정값
  fake-transition-min    ;; 최소 틱 차이 (10)
  fake-transition-max    ;; 최대 틱 차이 (25)
  attacked-ticks-map   ;; 공격 오퍼의 생성 틱을 저장할 맵
  fake-transition-tick-map
  attack-conversion-delays  ;; 리스트: 각 공격별 전환 지연값 저장용
  offer-attack-type-map  ;; 테이블: offer-id → "DDoS" or "Timestamp-Replay"
  attacker-activity-map  ;; table: 공격자(agent) → 공격 횟수
  top-n-attackers         ;; 모니터링 시 상위 N명 출력용 변수
]

turtles-own [
  true-energy           ; 실제 보유 전력량 (내부용)
  true-production       ; 실제 생산량 (내부용)
  true-consumption      ; 실제 소비량 (내부용)
  inbox                 ; 수신함
  outbox                ; 발신함
  offer-inbox-count     ; 인박스 누적 수신(승인·거절 후에도 유지)
  next-offer-tick       ; 다음 오퍼 생성 가능 시점(틱)
  last-propose-tick     ; 검증자별 마지막 제안 틱 저장

  blockchain
  personal-blockchain
  selected?
  peer-chain-hashes     ; 각 노드가 수신한 검증자별 체인 해시 목록
  validated-offers-this-tick  ; 검증자당 틱별 오퍼 검사
  attempt-count    ;; 오퍼 작성(거래 시도) 누적
  success-count    ;; 거래 성공 누적
  fail-count       ;; 거래 실패 누적

  real-name             ; 기관명
  registration-id       ; 사업자등록번호/고유코드
  region                ; 지역
  validator-id          ; 암호화된 검증자 ID
  node-id               ; 사용자 정의 노드 ID (who 대신 사용)
  reputation-score      ; 평판 점수
  validator?            ; 검증자 여부 추가
  token-delta           ; 토큰 변화량 (양수=수입, 음수=지출)
  ess-capacity          ; ESS 용량
  current-energy

  monthly-consumption
  daily-consumption
  sixhour-consumption
  per-second-consumption
  consumption
  monthly-production
  daily-production
  sixhour-production
  per-second-production
  production
  base-color
  original-color
]

ems-nodes-own [
  ess-storage
]

;================================초기화 관련 함수==========================

; 2. 신원 정보 자동 생성 프로시저 (성북구 동 이름 적용)
to generate-identities
  let seongbuk-dong ["Dongseon-dong" "Samseon-dong" "Seongbuk-dong" "Anam-dong"
                     "Jongam-dong" "Seongdong-dong" "Gireum-dong" "Seokgwan-dong"
                     "Jingwan-dong" "Bomun-dong" "Hwarang-dong" "Seokdang-dong"
                     "Sungin-dong" "Sungmo-dong" "Sungbuk-dong" "Sungjeong-dong"
                     "Sungwoo-dong"]
  let korean-names ["Junha" "Minji" "Seojun" "Jiwoo" "Youngho" "Soomin" "Hyunwoo"
                    "Eunji" "Jaehyun" "Somin" "Haeun" "Dohyun" "Minseo" "Yoona"
                    "Jiwon" "Taeyang" "Sanghoon" "Yuri" "Joon" "Hana" "Jihoon"
                    "Sujin" "Hyunseo" "Yejin" "Sungmin" "Heejin" "Yuna" "Donghae"
                    "Kibum" "Ryeowook" "Yesung" "Siwon" "Leeteuk" "Heejin" "Hyojin"
                    "Bora" "Hyuna" "Jiyoon" "Sohyun" "Jihyun" "Naeun" "Chorong"
                    "Bomi" "Hayoung" "Namjoo" "Yookyung" "Yoonbum" "Jonghyun" "Onew"
                    "Key" "Minho" "Taemin" "Jongin" "Sehun" "Baekhyun" "Chanyeol" "D.O." "Kai"]
  let eco-company-names ["EcoVolt" "GreenSpark" "Solaris" "RenewGrid" "CleanWatt"
                         "TerraPower" "EcoDynamics" "SunHarvest" "WindBloom" "PureEnergy"
                         "EcoNexus" "SolarFlare" "GreenCircuit" "EcoFlow" "RenewSphere"
                         "CleanHorizon" "TerraVolt" "EcoSynergy" "SunPulse" "WindHaven"]
  ask turtles [
    if breed = ems-nodes [
      set real-name "EMS"
      set registration-id 1
      set region one-of seongbuk-dong
    ]
    if breed = household-nodes [
      set real-name one-of korean-names
      set region one-of seongbuk-dong
      set node-id who
    ]
    if breed = company-nodes [
      set real-name one-of eco-company-names
      set region one-of seongbuk-dong
      set node-id who
    ]
    if breed = plant-nodes [
      set real-name "EcoPowerPlant"
      set region "Seongbuk-gu"
      set node-id who
    ]
    set validator-id (word "VID-" node-id "-" random 1000)
    set registration-id (100000 + node-id + random 900000)
  ]
end

to ensure-uniqueness
  while [any? other turtles with [registration-id = [registration-id] of myself]] [
    set registration-id registration-id + random 1000
  ]
end

; 이름 중복 처리
to ensure-unique-names
  let name-counts table:make
  ask turtles [
    let n real-name
    ifelse table:has-key? name-counts n [
      table:put name-counts n (table:get name-counts n + 1)
    ][
      table:put name-counts n 1
    ]
  ]
  let name-index table:make
  ask turtles [
    let n real-name
    if table:get name-counts n > 1 [
      ifelse table:has-key? name-index n [
        table:put name-index n (table:get name-index n + 1)
      ][
        table:put name-index n 1
      ]
      let idx table:get name-index n
      if is-list? idx [ set idx first idx ]
      let suffix (ifelse-value idx < 10 [word "_0" idx] [word "_" idx])
      set real-name (word n suffix)
    ]
  ]
end
; 가정노드 좌표 및 ess보유 여부
to-report household-node-coords-and-ess
  report [
    [ [-11 -3] true ]
    [ [-7 -5] true ]
    [ [-4 -9] true ]
    [ [-3 -7] true ]
    [ [-5 -8] true ]
    [ [-1 -6] true ]
    [ [-3 -5] true ]
    [ [1 -2] true ]
    [ [0 -4] true ]
    [ [-4 -5] true ]
    [ [-3 -3] true ]
    [ [-2 -4] true ]
    [ [2 -6] true ]
    [ [1 -9] true ]
    [ [-1 -8] true ]
    [ [-1 -10] true ]
    [ [-2 -1] true ]
    [ [-2 -2] true ]
    [ [-3 0] true ]
    [ [-6 -2] true ]
    [ [-4 -2] true ]
    [ [-8 0] true ]
    [ [-7 2] true ]
    [ [-4 -2] true ]
    [ [-5 4] true ]
    [ [-7 5] true ]
    [ [0 -2] true ]
    [ [0 -1] true ]
    [ [-1 2] true ]
    [ [-1 0] true ]
    [ [0 0] true ]
    [ [1 -1] true ]
    [ [3 -1] true ]
    [ [2 1] true ]
    [ [5 -6] true ]
    [ [5 -4] true ]
    [ [3 -3] true ]
    [ [2 -4] true ]
    [ [3 -5] true ]
    [ [4 -1] true ]
    [ [6 0] true ]
    [ [5 1] true ]
    [ [4 0] true ]
    [ [6 -2] true ]
    [ [7 -4] true ]
    [ [7 0] true ]
    [ [6 2] true ]
    [ [7 2] true ]
    [ [9 4] true ]
    [ [9 3] true ]
    [ [8 1] true ]
    [ [11 3] true ]
    [ [12 2] true ]
    [ [10 0] true ]
    [ [11 -2] true ]
    [ [12 -1] true ]
    [ [14 2] true ]
    [ [15 0] true ]
  ]
end

; 회사 노드 좌표
to-report company-node-positions
  report [
    [6 -1]
    [1 -6]
    [-3 -9]
    [-3 3]
    [10 -1]
    [-9 0]
    [-12 -4]
    [-5 -6]
    [-3 -1]
    [0 -8]
  ]
end

; 3. 초기화 프로시저 (EMS 노드 ID 0로 설정)
to setup
  clear-all
  reset-ticks
  setup-ascii-table
  set block-size 20
  init-attack-monitoring
  import-drawing "imaged.png"
  set pending-transactions []
  set last-block-hash "GENESIS"
  set block-counter 0
  set energy-price 12.9
  set prev-positive-token-delta 0
  set prev-negative-token-delta 0
  set tick-positive-token-delta 0
  set tick-negative-token-delta 0
  set validator-rotation-tick 0  ; 검증자 교체 카운터 초기화
  set monthly-shortages 0
  set current-datetime time:create start-datetime
  set validators []
  set shared-energy-status []
  set monthly-electricity-prices [169.37 150.84 165.78 157.40 157.67 157.30 163.80
    177.17 170.16 148.55 143.53 147.91]
  set token-price 65
  set offer-list []
  set tick-offer-counter 0
  set offer-per-tick-limit 50  ;; 예: 틱당 최대 50건 생성 허용
  set trusted-nodes turtles with [reputation-score >= 80]
  set max-pending-size 100     ;; 예: 최대 100건까지 유지
  set timestamp-replay-detected? false
  set selection-mode? false
  set fake-transition-min 10
  set fake-transition-max 250
  set attacked-ticks-map table:make
  set fake-transition-tick-map table:make
  set attack-conversion-delays []
  set offer-attack-type-map table:make
  set attacker-activity-map table:make
  set top-n-attackers 5     ;; 기본 상위 5명

  set solar-monthly-production [
    107.0825 100.7353 167.4365 174.5713 217.3787 196.9251
    146.3377 192.6779 166.1437 130.4443 124.1665 114.9379
  ]
  set wind-monthly-production [
    64.9811 50.2356 63.8003 34.5685 51.3811 24.0678
    53.9996 20.4341 23.6783 35.5765 51.1133 87.3264
  ]
  let total-sum (sum solar-monthly-production + sum wind-monthly-production)
  let solar-adjust-factor 0.375 / (sum solar-monthly-production / total-sum)
  let wind-adjust-factor 0.625 / (sum wind-monthly-production / total-sum)
  set solar-monthly-production map [x -> x * solar-adjust-factor] solar-monthly-production
  set wind-monthly-production map [x -> x * wind-adjust-factor] wind-monthly-production

  set solar-hourly-ratio [
    [0.000124 0.313593 0.611614 0.074668]
    [0.000125 0.310768 0.621498 0.067609]
    [0.000119 0.349176 0.580751 0.069954]
    [0.000162 0.362445 0.564740 0.072653]
    [0.000605 0.381635 0.543212 0.074548]
    [0.001142 0.366303 0.551678 0.080877]
    [0.000371 0.334417 0.582172 0.083039]
    [0.000273 0.361129 0.560208 0.078390]
    [0.000157 0.384530 0.543708 0.071604]
    [0.000183 0.404140 0.524521 0.071156]
    [0.000183 0.387492 0.540773 0.071553]
    [0.000174 0.352593 0.584185 0.063048]
  ]
  set wind-hourly-ratio [
    [0.259422 0.251052 0.228457 0.261069]
    [0.239112 0.243249 0.250276 0.267363]
    [0.261231 0.237733 0.236457 0.264578]
    [0.271952 0.251598 0.212278 0.264172]
    [0.283304 0.255987 0.251546 0.209162]
    [0.287969 0.204528 0.245417 0.262085]
    [0.238864 0.253095 0.255996 0.252045]
    [0.262351 0.227292 0.259143 0.251214]
    [0.251882 0.234313 0.239531 0.274275]
    [0.247460 0.245753 0.232093 0.274694]
    [0.261968 0.245363 0.226087 0.266582]
    [0.271021 0.248502 0.233095 0.247382]
  ]

  create-ems-nodes 1 [
    set breed ems-nodes
    set color blue
    set base-color blue
    set shape "house"
    set real-name "EMS"
    set region "Seongbuk-gu"
    set registration-id 1
    set reputation-score 100
    set ess-storage 10000
    set current-energy 10000
    set blockchain []
    set peer-chain-hashes []
    set inbox []
    set outbox []
    set personal-blockchain []
    set selected? false
    set validator? false
    setxy -7 0
    set node-id who
  ]
  set ems-node one-of ems-nodes
  set offer-counter 0
  set tick-offer-counter 0
  set offer-list []

  create-household-nodes 20 [
    set color green
    set base-color green
    set shape "person"
    set ess-capacity 25
    set current-energy 0.02
    set inbox []
    set outbox []
    set personal-blockchain []
    set blockchain []
    set peer-chain-hashes []
    set selected? false
    set validator? false
    setxy -5 0
    set node-id who
    let ratio-c (0.9 + random-float 0.2)
    let ratio-p (0.9 + random-float 0.2)
    set monthly-production 250 * ratio-p
    set monthly-consumption 400 * ratio-c
    set per-second-production monthly-production / 2592000
    set production per-second-production
    set per-second-consumption monthly-consumption / 2592000
    set consumption per-second-consumption
  ]

  create-household-nodes 40 [
    set color yellow
    set base-color yellow
    set shape "person"
    set ess-capacity 5
    set current-energy 0.02
    set inbox []
    set outbox []
    set personal-blockchain []
    set blockchain []
    set peer-chain-hashes []
    set selected? false
    set validator? false
    setxy 0 0
    set node-id who
    let ratio-c (0.9 + random-float 0.2)
    let ratio-p (0.9 + random-float 0.2)
    set monthly-production 250 * ratio-p
    set monthly-consumption 400 * ratio-c
    set per-second-production monthly-production / 2592000
    set production per-second-production
    set per-second-consumption monthly-consumption / 2592000
    set consumption per-second-consumption
  ]

  let co-coords company-node-positions
  foreach co-coords [
    xy ->
    create-company-nodes 1 [
      set color red
      set base-color red
      set shape "square"
      set ess-capacity 500
      set current-energy 0.03
      set inbox []
      set outbox []
      set personal-blockchain []
      set blockchain []
      set peer-chain-hashes []
      set selected? false
      set validator? false
      setxy (item 0 xy + random-float 0.5 - 0.25) (item 1 xy + random-float 0.5 - 0.25)
      set node-id who
      let ratio-c (0.9 + random-float 0.2)
      let ratio-p (0.9 + random-float 0.2)
      set monthly-production 5000 * ratio-p
      set monthly-consumption 20000 * ratio-c
      set per-second-production monthly-production / 2592000
      set production per-second-production
      set per-second-consumption monthly-consumption / 2592000
      set consumption per-second-consumption
    ]
  ]
  create-plant-nodes 1 [
    set color orange
    set base-color orange
    set shape "wheel"
    set production 200000
    set current-energy 500000
    set ess-capacity 600000
    set inbox []
    set outbox []
    set personal-blockchain []
    set blockchain []
    set peer-chain-hashes []
    set selected? false
    set validator? false
    setxy -9 7
    set node-id who
  ]

  generate-identities
  ensure-unique-names
  ask turtles [ ensure-uniqueness ]
  ask household-nodes [ set reputation-score 80 ]
  ask company-nodes [ set reputation-score 80 ]
  ask ems-nodes [ set color blue ]
  ask household-nodes [
    ifelse ess-capacity = 25 [ set color green ] [ set color yellow ]
  ]
  ask company-nodes [ set color red ]
  ask plant-nodes [ set color orange ]
  ask turtles [ set size 1.0 ]

  ask turtles [
    type "Node ID: " type node-id
    type ", Name: " type real-name
    type ", Region: " type region
    type ", Reputation: " type reputation-score
    type ", Validator: " type validator?
    type ", RegID: " type registration-id
    type ", ValidatorID: " print validator-id
    set token-delta 0
    set next-offer-tick 0 + random 100  ;; 0~100틱 사이 랜덤 초기화
    set peer-chain-hashes []
    set attempt-count 0
    set success-count 0
    set fail-count 0
  ]
  ask turtles [
    if breed = household-nodes [
      if ess-capacity = 25 [ set original-color green ]
      if ess-capacity != 25 [ set original-color yellow ]
    ]
    if breed = company-nodes [ set original-color red ]
    if breed = plant-nodes [ set original-color orange ]
    if breed = ems-nodes [ set original-color blue ]
    set base-color original-color
    set color base-color
  ]

  assign-validators
  update-shared-energy-status
  set consensus-threshold ceiling (count validators * 0.67) ; 2/3 이상 동의 필요

  let coord-ess-list household-node-coords-and-ess
  let ess25-count 20
  let idx 0
  foreach coord-ess-list [
    ce ->
    let xy item 0 ce
    ask household-nodes with [node-id = position ce coord-ess-list] [
      setxy (item 0 xy + random-float 0.5 - 0.25) (item 1 xy + random-float 0.5 - 0.25)
      if idx < ess25-count [
        set ess-capacity 25
        set current-energy 0.02
      ]
      if idx >= ess25-count [
        set ess-capacity 5
        set current-energy 0.02
      ]
    ]
    set idx idx + 1
  ]
end

;====================================인터페이스 관련 함수===========================

; 링크 TTL 관리 (시각적 거래 연결)
to manage-link-ttl
  ask links [
    set ttl ttl - 1
    if ttl <= 0 [ die ]
  ]
end

; 총 누적 거래 오퍼 개수
to-report total-trade-attempts
  report length offer-list
end

; 총 미처리 거래 횟수
to-report pending-offer-count
  report length filter [ o ->
    (item 5 o = "PENDING") or (item 5 o = "PENDING-DDOS")
  ] offer-list
end

; 총 거래 성공 횟수
to-report accepted-offer-count
  report length filter [o -> (length o = 7) and ((item 5 o = "ACCEPTED") or (item 5 o = "ATTACKED"))] offer-list
end

; 총 거래 실패 횟수
to-report rejected-offer-count
  report length filter [o -> (length o = 7) and (item 5 o = "REJECTED")] offer-list
end

; 총 가짜 거래 횟수
to-report fake-offer-count
  report length filter [o -> (length o = 7) and (item 5 o = "FAKE")] offer-list
end

; 30분(1800틱) 단위 P2P 거래 승인 횟수 리포터
to-report p2p-accepted-count-30min
  let start-tick ticks - (ticks mod 1800)
  report length filter [o ->
    (length o = 7) and
    (item 5 o = "ACCEPTED") and
    (item 6 o >= start-tick) and
    is-agent? (item 1 o) and
    is-agent? (item 2 o) and
    member? (word [breed] of (item 1 o)) ["household" "company"] and
    member? (word [breed] of (item 2 o)) ["household" "company"]
  ] offer-list
end

; 성능 지표 계산
to update-metrics
  let total-trades length [blockchain] of one-of ems-nodes
  set economic-efficiency total-trades * energy-price * 0.8
end

; 현재 날짜/시간 리포트
to-report current-date-time
  report time:show current-datetime "yyyy-MM-dd HH:mm"
end

; 거래 성공률 (총 거래 성공 횟수 / 총 누적 거래 오퍼 개수)
to-report trade-success-rate
  let total-attempts length offer-list
  if total-attempts = 0 [ report 0 ]
  let accepted-count length filter [o -> (length o = 7) and (item 5 o = "ACCEPTED")] offer-list
  report precision (accepted-count / total-attempts) 6
end

; 안정성
to-report shortage-count
  report count turtles with [current-energy < 0]
end

; 검증자 이름 반환 함수
to-report validator-names
  let names sort [real-name] of validators
  ifelse length names = 0 [
    report ""
  ] [
    report reduce [[?1 ?2] -> (word ?1 ", " ?2)] names
  ]
end

;노드 선택
to handle-selection
  if selection-mode? and mouse-down? [
    let target one-of turtles with [ distancexy mouse-xcor mouse-ycor < 0.7 ]
    if target != nobody [
      ask turtles [ set selected? false set color base-color ]
      ask target [
        set selected? true
        set color magenta
      ]
      ;; 선택된 노드 정보 갱신
      set selected-who [who] of target
      ;; 마우스 릴리즈 대기
      wait 0.1
    ]
  ]
end

; 선택 노드 거래 시도 누적 횟수
to-report selected-attempt-count
  if any? turtles with [selected?] [
    report [attempt-count] of one-of turtles with [selected?]
  ]
  report 0
end

; 선택 노드 거래 성공 누적 횟수
to-report selected-accepted-count
  if any? turtles with [selected?] [
    report [success-count] of one-of turtles with [selected?]
  ]
  report 0
end

; 선택 노드 거래 실패 누적 횟수
to-report selected-rejected-count
  if any? turtles with [selected?] [
    report [fail-count] of one-of turtles with [selected?]
  ]
  report 0
end

; 선택 노드의 평판 점수
to-report selected-reputation
  if any? turtles with [selected?] [
    report [reputation-score] of one-of turtles with [selected?]
  ]
  report 0
end

; 선택된 노드의 이름 / ID 리포터
to-report selected-name-and-id
  if any? turtles with [selected?] [
    let t one-of turtles with [selected?]
    let nm [real-name] of t
    let id [who] of t
    report (word nm " / " id)
  ]
  report ""
end

; 선택된 노드의 현재 에너지량 리포터
to-report selected-current-energy
  if any? turtles with [selected?] [
    report precision [current-energy] of one-of turtles with [selected?] 3
  ]
  report precision 0 3
end

; 선택된 노드의 종류 리포터
to-report selected-node-type
  if any? turtles with [selected?] [
    let t one-of turtles with [selected?]

    ifelse member? t validators [
      report "검증자 노드"
    ] [
      ifelse member? t ems-nodes [
        report "EMS 노드"
      ] [
        ifelse member? t household-nodes [
          report "가정 노드"
        ] [
          ifelse member? t company-nodes [
            report "기업 노드"
          ] [
            ifelse member? t plant-nodes [
              report "발전소 노드"
            ] [
              report "알 수 없는 노드"
            ]
          ]
        ]
      ]
    ]
  ]
  report "노드 미선택"
end


;===================================아웃풋 관련 함수==============================
; 문자열을 원하는 길이로 맞춰주는 유틸리티 함수
to-report pad-string [val width]
  let s word val ""
  if length s >= width [
    report substring s 0 width
  ]
  let pad-length (width - length s)
  let pad-str reduce word (n-values pad-length [i -> " "])
  report (word s pad-str)
end

; 전체 노드 현황
to print-all-nodes-info
  clear-output
  output-print "---ALL-NODES_INFO---"

  ; 각 칼럼의 폭을 정의
  let id-width 6
  let name-width 18
  let energy-width 9
  let reputation-width 12
  let validator-width 10

  ; 헤더 출력
  output-print (word
    pad-string "ID" id-width
    " | " pad-string "Name" name-width
    " | " pad-string "Energy" energy-width
    " | " pad-string "Reputation" reputation-width
    " | " pad-string "Validator" validator-width
  )

  let sorted-turtles sort-on [node-id] turtles
  foreach sorted-turtles [a-turtle ->
    ask a-turtle [
      output-print (word
        pad-string node-id id-width
        " | " pad-string real-name name-width
        " | " pad-string (precision current-energy 2) energy-width
        " | " pad-string reputation-score reputation-width
        " | " pad-string validator? validator-width
      )
    ]
  ]
end

; 블록 정보 리포트
to-report block-list-info
  let blocks   [blockchain] of one-of ems-nodes
  let info-list []
  foreach blocks [ block ->
    set info-list lput (list
      item 0 block  ;; ID
      item 4 block  ;; Proposer
      length item 5 block  ;; TxCount
      item 3 block  ;; Hash
      item 6 block  ;; MerkleRoot
    ) info-list
  ]
  report info-list
end

to print-block-row [idx block id-w proposer-w tx-w hash-w merkle-w]
  output-print (word
    pad-string idx id-w
    " | " pad-string item 4 block proposer-w
    " | " pad-string (length item 5 block) tx-w
    " | " pad-string item 3 block hash-w
    " | " pad-string item 6 block merkle-w
  )
end

to print-blockchain-table
  clear-output
  let id-w       4
  let proposer-w 13
  let tx-w       7
  let hash-w    25
  let merkle-w  25
  output-print (word
    pad-string "ID" id-w
    " | " pad-string "Proposer" proposer-w
    " | " pad-string "TxCount" tx-w
    " | " pad-string "Hash" hash-w
    " | " pad-string "MerkleRoot" merkle-w
  )
  let blocks [blockchain] of one-of ems-nodes
  let idxs   n-values length blocks [i -> i]
  foreach idxs [ idx ->
    print-block-row idx (item idx blocks) id-w proposer-w tx-w hash-w merkle-w
  ]
end

;=====================================시간 설정============================
; 시간 업데이트(1초 단위)
to update-time
  set current-datetime time:plus current-datetime 1 "second"
end


;=====================================평판 점수 관련 함수=======================

; 평판 점수 관리
to increase-reputation [node]
  ask node [
    set reputation-score min (list 100 (reputation-score + 0.5))
  ]
end

to decrease-reputation [node]
  ask node [
    set reputation-score max (list 0 (reputation-score - 5))
  ]
end

;=================================생산량/소비량 관련 함수==============================

; 전력 소비 우선도 적용
to apply-consumption-priority
  ask turtles with [
    breed != ems-nodes and
    breed != plant-nodes and
    ess-capacity > 0
  ] [
    let need consumption
    ; 1순위: 생산 전력만큼 우선 소비
    let prod-use min (list production need)
    set need need - prod-use

    ; 2순위: ESS 보유 전력 추가 소비
    let ess-portion current-energy
    let ess-use min (list ess-portion need)
    set current-energy current-energy - ess-use
    set need need - ess-use

    ; 실제 소비/생산/보유량 기록
    set true-consumption consumption
    set true-production production
    set true-energy current-energy
    set outbox []
  ]
end

; 생산/소비량 및 관련 값 일괄 설정 함수 (1초 단위 포함)
to set-production-consumption [node base-prod base-cons seasonal-factor]
  let ratio-c (0.9 + random-float 0.2)
  let ratio-p (0.9 + random-float 0.2)
  ask node [
    set monthly-consumption base-cons * ratio-c * seasonal-factor
    set monthly-production base-prod * ratio-p * seasonal-factor
    set per-second-consumption monthly-consumption / 2592000 ; 1달=2,592,000초
    set consumption per-second-consumption
    set per-second-production monthly-production / 2592000
    set production per-second-production
  ]
end

; 생산/소비량 및 관련 값 일괄 초기화 함수
to update-energy-values
  ;; 1. 계절 감지 (월 기준)
  let current-month time:get "month" current-datetime
  let summer? member? current-month [6 7 8]  ;; 6~8월: 여름
  let winter? member? current-month [12 1 2] ;; 12~2월: 겨울
  let seasonal-factor 1.0

  if summer? [ set seasonal-factor 1.15 ]  ;; 여름철 15% 증가 (냉방)
  if winter? [ set seasonal-factor 1.10 ]  ;; 겨울철 10% 증가 (난방)
    ;; 2. 가정용 노드 - ESS 용량별 분기, 1초 단위만 유지
  ask household-nodes [
    let ratio-c (0.9 + random-float 0.2)
    let ratio-p (0.9 + random-float 0.2)

    set monthly-consumption 400 * ratio-c * seasonal-factor
    set monthly-production 250 * ratio-p * seasonal-factor

    set per-second-consumption monthly-consumption / 2592000  ; 1달 = 2,592,000초
    set consumption per-second-consumption

    set per-second-production monthly-production / 2592000
    set production per-second-production

    set true-consumption consumption
    set true-production production
    set true-energy current-energy
  ]
    ;; 3. 회사 노드
  ask company-nodes [
    let ratio-c (0.9 + random-float 0.2)
    let ratio-p (0.9 + random-float 0.2)

    set monthly-consumption 1000 * ratio-c * seasonal-factor
    set monthly-production 150 * ratio-p * seasonal-factor

    set per-second-consumption monthly-consumption / 2592000
    set consumption per-second-consumption

    set per-second-production monthly-production / 2592000
    set production per-second-production

    set true-consumption consumption
    set true-production production
    set true-energy current-energy
  ]

  ;; 4. 발전소 노드 - 월별 총 생산량을 1초 단위로 환산
  let m time:get "month" current-datetime

  let solar-monthly item (m - 1) solar-monthly-production * 1000000  ;; MWh → Wh
  let wind-monthly  item (m - 1) wind-monthly-production * 1000000   ;; MWh → Wh

  let solar-per-second solar-monthly / 2592000
  let wind-per-second  wind-monthly  / 2592000

  ask plant-nodes [
    set production solar-per-second + wind-per-second
    set true-production production
    set true-energy current-energy
    set true-consumption 0
  ]
end

; 실시간 에너지 현황 공유
to update-shared-energy-status
  set shared-energy-status []
  ask turtles [
    if breed = household-nodes or breed = company-nodes [
      set shared-energy-status lput (list node-id current-energy production consumption reputation-score) shared-energy-status
    ]
    if breed = plant-nodes [
      set shared-energy-status lput (list node-id current-energy production 0 reputation-score) shared-energy-status
    ]
    if breed = ems-nodes [
      set shared-energy-status lput (list node-id current-energy 0 0 reputation-score) shared-energy-status
    ]
  ]
end

;=================================블록체인=========================
; 아스키 코드 구현
to setup-ascii-table
  set ascii-table []
  let chars " !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~"
  let i 0
  let n length chars
  while [i < n] [
    set ascii-table lput (list (substring chars i (i + 1)) (i + 32)) ascii-table
    set i i + 1
  ]
end

to-report ascii [c]
  let code 0
  foreach ascii-table [pair ->
    if item 0 pair = c [ set code item 1 pair ]
  ]
  report code
end

; === 이중 해시 함수 정의 ===
to-report improved-hash1 [str]
  let hash 5381
  let len length str
  let i 0
  while [i < len] [
    let c substring str i (i + 1)
    set hash ((hash * 33) + ascii c) mod 1000000007
    set i i + 1
  ]
  report hash
end

to-report improved-hash2 [str]
  let hash 0
  let len length str
  let i 0
  while [i < len] [
    let c substring str i (i + 1)
    set hash ((hash * 65599) + ascii c) mod 1000000009
    set i i + 1
  ]
  report hash
end

to-report combined-hash [str]
  ; 두 해시값을 문자열로 결합
  let h1 improved-hash1 str
  let h2 improved-hash2 str
  report (word h1 "-" h2)
end

; 머클 트리 루트 계산
to-report merkle-root [tx-list]
  ;; 1) 빈 리스트 처리
  if empty? tx-list [ report "" ]
  ;; 2) 홀수 개일 때 마지막 요소 복제
  if (length tx-list) mod 2 = 1 [
    set tx-list lput last tx-list tx-list
  ]
  ;; 3) 순수 리포터로 map
  let parent-list
    map [[pair] ->
      combined-hash (word (item 0 pair) (item 1 pair))
    ] (partition tx-list 2)
  ;; 4) 재귀 또는 단일 반환
  ifelse length parent-list = 1 [
    report first parent-list
  ] [
    report merkle-root parent-list
  ]
end

; 리스트를 k개씩 묶어 서브 리스트 생성
to-report partition [lst k]
  let result []
  let n length lst
  let i 0
  while [i < n] [
    set result lput sublist lst i (min (list n (i + k))) result
    set i i + k
  ]
  report result
end

to-report join-with-bar [lst]
  if not is-list? lst [ report "" ]
  if length lst = 0 [ report "" ]
  let result (word item 0 lst)
  if length lst > 1 [
    let i 1
    while [i < length lst] [
      set result (word result "|" item i lst)
      set i i + 1
    ]
  ]
  report result
end

;; 블록 문자열 생성용 공용 reporter
to-report block-header-string [bid tsp prev-hash block-proposer merkle-value tx-list]
  let txs-str join-with-bar tx-list
  report (word bid "|" tsp "|" prev-hash "|" block-proposer "|" merkle-value "|" txs-str)
end

; 블록 생성 함수
to create-block [tx-list]
  let bid         block-id
  let ts          timestamp
  let proposerNm  [real-name] of proposer
  let merkleRoot  merkle-root tx-list
  let header-str  block-header-string bid ts last-block-hash proposerNm merkleRoot tx-list
  let blockHash   combined-hash header-str
  let blockData   (list bid ts last-block-hash blockHash proposerNm tx-list merkleRoot)
  ask ems-nodes [ set blockchain lput blockData blockchain ]
  set last-block-hash blockHash
  set block-counter block-counter + 1
end

; 블록체인 트랜잭션 처리
to conduct-transaction [seller-agent buyer-agent amount price]
  let token-amount amount * price
  if [breed] of buyer-agent = ems-nodes [
    let ems-space ([ess-storage] of buyer-agent) - ([current-energy] of buyer-agent)
    if amount > ems-space [
      ask seller-agent [
        decrease-reputation self
      ]
      ask buyer-agent [
        set inbox lput (word "Offer failed: EMS has insufficient storage space") inbox
      ]
      stop
    ]
  ]
  ask buyer-agent [ set token-delta token-delta - token-amount ]
  ask seller-agent [ set token-delta token-delta + token-amount ]
  ask seller-agent [ set current-energy current-energy - amount ]
  ask buyer-agent [ set current-energy current-energy + amount ]

  let tx-data (list
    (word "\"seller\": \"" [real-name] of seller-agent "\"")
    (word "\"buyer\": \"" [real-name] of buyer-agent "\"")
    (word "\"amount\": " amount)
    (word "\"price\": " price)
    (word "\"timestamp\": \"" (time:show current-datetime "yyyy-MM-dd HH:mm") "\"")
    ticks
  )
  add-transaction-to-pending tx-data
  ask seller-agent [ set personal-blockchain lput tx-data personal-blockchain ]
  ask buyer-agent [ set personal-blockchain lput tx-data personal-blockchain ]
  ask seller-agent [
    create-link-with buyer-agent [
      set color yellow
      set thickness 0.01 + (amount / 500)
      set label (word precision amount 2 " kWh")
      set hidden? false
      set creation-tick ticks
      set ttl 600
    ]
  ]
  ask seller-agent [
    increase-reputation self
    set success-count success-count + 1
  ]
  ask buyer-agent [
    increase-reputation self
    set success-count success-count + 1
  ]
  if ([breed] of seller-agent != ems-nodes and [breed] of seller-agent != plant-nodes and
      [breed] of buyer-agent != ems-nodes and [breed] of buyer-agent != plant-nodes) [
    set tick-peer-trade-count tick-peer-trade-count + 1
  ]
end

;; 헬퍼 리포터: tx 리스트에서 판매자(agent) 추출
to-report turtle-from-tx [tx]
  ;; tx 리스트 구조:
  ;; item 0: "\"seller\": \"SellerName\""
  ;; item 1: "\"buyer\": \"BuyerName\""
  ;; item 2: "\"amount\": value"
  ;; item 3: "\"price\": value"
  ;; item 4: "\"timestamp\": \"YYYY-MM-DD HH:MM\""
  ;; item 5: ticks

  ;; 1) seller 필드 문자열 추출
  let seller-field item 0 tx
  ;; 2) prefix 길이 계산 ("\"seller\": \"" 부분)
  let prefix "\"seller\": \""
  let prefix-len length prefix
  ;; 3) seller 이름만 추출 (마지막 쌍따옴표 전까지)
  ;; 전체 길이에서 맨 끝의 "\"" 하나를 뺌
  let name-end (length seller-field - 1)
  let seller-name substring seller-field prefix-len name-end

  ;; 4) real-name이 seller-name과 일치하는 turtle 찾기
  let target one-of turtles with [ real-name = seller-name ]
  if target = nobody [
    error (word "판매자 '" seller-name "'에 해당하는 거북이가 없습니다.")
  ]
  report target
end


; 거래 누적 함수
to add-transaction-to-pending [tx]
  ;; 1) 타임스탬프 리플레이 방어: 오래된 거래 거부
  if length tx < 6 [ stop ]            ;; 최소 7개 요소(tx-data+ticks) 확인
  let offer-ts item 5 tx               ;; 6번째 요소가 숫자형 ticks

  ;; 2) 재전송 거래 허용 범위 검사
  ifelse abs (ticks - offer-ts) > 1000 [
    ;; 1,000틱 초과: 거래 거부
    stop
  ] [
    ;; 1,000틱 이내: 재전송 거래(공격)로 간주하여 플래그 설정
    set timestamp-replay-detected? true
  ]

  ;; 2) 큐 과부하 검사
  if length pending-transactions >= max-pending-size [
    ;; 평판 낮은 순으로 정렬된 리스트 생성
    let sorted-pending sort-by
      [ [a b] ->
          ([reputation-score] of turtle-from-tx a)
          <
          ([reputation-score] of turtle-from-tx b)
      ]
      pending-transactions
    ;; 가장 평판 낮은 항목 제거
    set pending-transactions
    remove-item
    (position first sorted-pending pending-transactions)
    pending-transactions
  ]

  ;; 2) 새 트랜잭션 추가
  set pending-transactions lput tx pending-transactions

  ;; 3) 블록 생성 트리거
  if length pending-transactions >= block-size [
    let block-proposer-agent one-of validators
    process-block pending-transactions block-proposer-agent
    set pending-transactions []
  ]
end

; 무결성 검증
to-report is-blockchain-valid
  let prev-hash "GENESIS"
  let valid?   true
  let blocks   [blockchain] of one-of ems-nodes

  foreach blocks [ block ->
    let bid          item 0 block
    let ts           item 1 block
    let storedPrev   item 2 block
    let storedHash   item 3 block
    let proposer-name item 4 block
    let txs          item 5 block
    let storedMerkle item 6 block

    ifelse storedPrev = "GENESIS" [
      if storedMerkle != merkle-root txs [
        user-message (word "Genesis Merkle mismatch at block " bid)
        set valid? false
      ]
    ] [
      let recMerkle merkle-root txs
      if storedMerkle != recMerkle [
        user-message (word "Merkle mismatch at block " bid)
        set valid? false
      ]
      let header-str block-header-string bid ts storedPrev proposer-name recMerkle txs
      let recHash    combined-hash header-str
      if storedPrev != prev-hash [
        user-message (word "Prev-hash mismatch at block " bid)
        set valid? false
      ]
      if storedHash != recHash [
        user-message (word "Hash mismatch at block " bid)
        set valid? false
      ]
    ]
    set prev-hash storedHash
  ]
  report valid?
end

; 검증자 선정
to assign-validators
  let candidates household-nodes
  if count candidates = 0 [
    set validators turtle-set nobody
    stop
  ]
  let sorted-candidates sort-by [[a b] -> ([reputation-score] of b) > ([reputation-score] of a)] candidates
  let validator-count min (list 7 (count candidates) (length sorted-candidates))
  let selected-nodes n-of validator-count sorted-candidates

  ; 모든 후보의 validator? false 및 색상 복원
  ask candidates [
    set validator? false
    set base-color original-color
    set color base-color
  ]

  ; 새 검증자에게 연한 초록색 부여
  foreach selected-nodes [ node ->
    ask node [
      set validator? true
      set base-color green + 5
      set color base-color
    ]
  ]
  set validators turtle-set selected-nodes
  ask validators [
    set last-propose-tick -1000000000
  ]
end

; 검증자 중 한 명이 블록을 제안
to propose-block [tx-list block-proposer-agent]
  ;; 1. 20틱 이내 재제안 금지 및 제안 틱 갱신
  ask block-proposer-agent [
    if ticks - last-propose-tick < 20 [
      stop
    ]
    set last-propose-tick ticks
  ]

  ;; 2. 기존 블록 제안 로직
  let bid         block-id
  let ts          timestamp
  let proposerNm  [real-name] of block-proposer-agent
  let merkleRoot  merkle-root tx-list
  let header-str  block-header-string bid ts last-block-hash proposerNm merkleRoot tx-list
  let blockHash   combined-hash header-str

  set proposed-block (list
    bid
    ts
    last-block-hash
    blockHash
    proposerNm
    tx-list
    merkleRoot
  )
  set block-approvals (list [who] of block-proposer-agent)
end


; 각 검증자가 제안된 블록을 검증(서명)
to validate-block
  if proposed-block = [] [ stop ]
  ask validators [
    ; 예시: 블록 무결성, 트랜잭션 유효성 등 추가 검증 가능
    if not member? who block-approvals [
      set block-approvals lput who block-approvals
    ]
  ]
end

; 합의 도달 시 블록을 체인에 추가
to finalize-block
  if length block-approvals >= consensus-threshold [
    ask ems-nodes [ set blockchain lput proposed-block blockchain ]
    set last-block-hash item 3 proposed-block
    set block-counter block-counter + 1
    set proposed-block []
    set block-approvals []
    set sync-needed true ; 동기화 필요 플래그만 설정
  ]
end

; 블록 생성 전체 프로세스(제안→검증→합의)
to process-block [tx-list block-proposer-agent]
  propose-block tx-list block-proposer-agent
  validate-block
  finalize-block
end

; 블록체인 동기화
to synchronize-blockchain
  let master-chain [blockchain] of one-of ems-nodes
  ask turtles [
    set blockchain master-chain
  ]
end

; 검증자 해시 수신 프로시저: 각 검증자로부터 최신 블록체인 해시 리스트를 수신
to receive-validator-hashes
  ask turtles with [breed != ems-nodes] [
    set peer-chain-hashes []
    ;; 모든 검증자(v)의 blockchain을 수집하되, 리스트인 경우만
    let raw-chains map [ v -> [blockchain] of v ] sort validators
    set peer-chain-hashes filter [ c -> is-list? c ] raw-chains
  ]
end

; 가장 긴,검증된 체인 선택 프로시저
to select-longest-valid-chain
  ask turtles with [breed != ems-nodes] [
    ;; peer-chain-hashes가 리스트가 아닐 때 빈 리스트로 초기화
    if not is-list? peer-chain-hashes [
      set peer-chain-hashes []
    ]
    ;; 중복 제거
    let all-chains remove-duplicates peer-chain-hashes
    ;; 리스트 아닌 항목을 걸러내고 유효 체인만 필터
    let valid-chains filter [ chain ->
      is-list? chain and is-chain-valid? chain
    ] all-chains
    ;; 리스트가 비어있지 않을 때만 최장 체인 선택
    if not empty? valid-chains [
      let sorted sort-by [[a b] -> length a < length b] valid-chains
      set blockchain last sorted
    ]
  ]
end


; 체인 유효성 검사 일반화 reporter
to-report is-chain-valid? [chain]
  ;; 1) 입력 검증
  if not is-list? chain [ report false ]
  if empty? chain     [ report true  ]

  ;; 2) 초기값 설정
  let prev-hash "GENESIS"
  let valid?   true

  ;; 3) 체인 순회
  foreach chain [ block ->
    ;; 3.1) 블록 구조 검증
    if not is-list? block or length block < 7 [
      set valid? false
      stop  ;; 즉시 foreach 중단
    ]

    ;; 3.2) 필드 추출
    let storedPrevHash  item 0 block
    let storedHash      item 1 block
    let storedMerkle    item 2 block
    let ts      item 3 block
    let block-proposer        item 4 block
    let tx-list         item 5 block
    let difficulty      item 6 block  ;; 예시: 7번째 필드

    ;; 3.3) 머클 루트 검증
    let recalculatedMerkle merkle-root tx-list
    if recalculatedMerkle != storedMerkle [
      set valid? false
      stop
    ]

    ;; 3.4) 해시 재계산
    let header-str (word storedPrevHash "-" storedMerkle "-" ts "-" block-proposer "-" difficulty)
    ;; ※ block-header-string 대신 직접 word 조합 예시
    let recHash combined-hash header-str

    ;; 3.5) 이전 해시 및 저장된 해시 비교
    if storedPrevHash != prev-hash or recHash != storedHash [
      set valid? false
      stop
    ]

    ;; 3.6) prev-hash 갱신
    set prev-hash recHash
  ]

  ;; 4) 결과 리포트
  report valid?
end





;====================================거래 관련 함수==============================
to-report random-price
  let base get-current-price-per-kwh-hourly
  let factor (0.8 + random-float 0.4)  ;; 0.8 ~ 1.2
  report precision (base * factor) 5
end

; 오퍼 구조: [ID 제안자 수신자 전력량 단가 상태 타임스탬프]
to create-offer [ offer-proposer receiver amount unit-price ]
  ;; 1) 틱당 오퍼 생성 제한
  if tick-offer-counter >= offer-per-tick-limit [ stop ]

  ;; 2) EMS 노드 대상일 때 trusted-nodes 필터링
  ;; 기존: if breed-of receiver = ems-nodes [
  if ([breed] of receiver) = ems-nodes [
    if not member? offer-proposer trusted-nodes [
      ;; 비신뢰 노드의 요청 무시
      stop
    ]
  ]

  ;; 3) 오퍼 생성 및 리스트 추가
  set offer-counter offer-counter + 1
  set tick-offer-counter tick-offer-counter + 1
  let new-offer (list
    offer-counter
    offer-proposer
    receiver
    amount
    unit-price
    "PENDING"
    ticks
  )
  set offer-list lput new-offer offer-list
  ask offer-proposer [
    set outbox lput new-offer outbox
    set attempt-count attempt-count + 1
  ]
  ask receiver [
    set inbox lput new-offer inbox
    set offer-inbox-count offer-inbox-count + 1
    set attempt-count attempt-count + 1
  ]
end

; PENDING 오퍼가 있는지 확인하는 리포터
to-report has-pending-offer? [my-outbox]
  let found? false
  let i 0
  while [i < length my-outbox and not found?] [
    let o item i my-outbox
    if item 5 o = "PENDING" [
      set found? true
    ]
    set i i + 1
  ]
  report found?
end

; 구매 희망 오퍼 생성
;; 구매 희망 오퍼 생성 – 수신자 우선도 확률 적용 및 후보군 안전 처리
to generate-buy-offers
  ask turtles with [
    breed != ems-nodes
    and breed != plant-nodes
    and current-energy <= ess-capacity * 0.1
  ] [
    if not has-pending-offer? outbox [
      let min-amt ess-capacity * 0.1
      let max-amt ess-capacity * 0.5
      let desired-amt min-amt + random-float (max-amt - min-amt)

      ;; 각 후보군별 agentset 정의
      let plant-candidates       plant-nodes with [self != myself and current-energy >= desired-amt]
      let company-candidates     company-nodes with [self != myself and current-energy >= desired-amt]
      let household25-candidates household-nodes with [self != myself and ess-capacity = 25 and current-energy >= desired-amt]
      let household5-candidates  household-nodes with [self != myself and ess-capacity = 5 and current-energy >= desired-amt]
      let ems-candidates         ems-nodes with [self != myself and current-energy >= desired-amt]

      ;; 후보군과 가중치 리스트
      let candidate-sets (list plant-candidates company-candidates household25-candidates household5-candidates ems-candidates)
      let weights (list 40 20 20 10 10)

      ;; 실제 후보가 있는 그룹만 추림 (인덱스 리스트)
      let available-indices filter [i -> any? item i candidate-sets] (range 0 5)

      ;; 후보가 하나도 없으면 skip
      if length available-indices > 0 [
        ;; 후보군별 가중치와 agentset 추출
        let available-weights map [i -> item i weights] available-indices
        let available-candidate-sets map [i -> item i candidate-sets] available-indices

        ;; 가중치 합 구해 정규화
        let total-weight sum available-weights
        let norm-weights map [w -> w / total-weight] available-weights

        ;; 누적합으로 확률적 그룹 선택
        let r random-float 1.0
        let acc 0
        let idx 0
        while [idx < length norm-weights and acc + item idx norm-weights < r] [
          set acc acc + item idx norm-weights
          set idx idx + 1
        ]

        ;; 최종 후보 agentset에서 무작위 1명 선택
        let group item idx available-candidate-sets
        if any? group [
          let receiver one-of group
          let price random-price
          create-offer self receiver desired-amt price
        ]
      ]
    ]
  ]
end

; 구매 희망 오퍼 평가
to evaluate-buy-offers
  let now ticks
  ask turtles [
    let my-inbox inbox
    let updated-inbox []
    foreach my-inbox [[o] ->
      let offer-id item 0 o
      let offer-proposer item 1 o
      let receiver item 2 o
      let amt item 3 o
      let ts item 6 o
      let elapsed now - ts
      let offer-status item 5 o
      let updated-offer o
      let offer-pos position o offer-list

      ;; === 발전소 노드는 오퍼를 받은 즉시 평가 ===
      if (offer-status = "PENDING") and ([breed] of self = plant-nodes) [
        let receiver-energy [current-energy] of self
        let receiver-capacity [ess-capacity] of self

        ;; 에너지 부족 시 거절
        if receiver-energy < amt [
          set updated-offer replace-item 5 o "REJECTED"
          ask offer-proposer [ set fail-count fail-count + 1 ]
          ask receiver [ set fail-count fail-count + 1 ]
          if offer-pos != false [
            set offer-list replace-item offer-pos offer-list updated-offer
          ]
          if is-agent? offer-proposer [
            ask offer-proposer [
              set outbox filter [[x] -> item 0 x != offer-id] outbox
            ]
          ]
        ]
        ;; 에너지 충분 시 즉시 승인
        if receiver-energy >= amt [
          set updated-offer replace-item 5 o "ACCEPTED"
          if offer-pos != false [
            set offer-list replace-item offer-pos offer-list updated-offer
          ]
          if is-agent? offer-proposer [
            ask offer-proposer [ set reputation-score reputation-score + 1 ]
          ]
          set reputation-score reputation-score + 1

          ;; 거래 직전 조건 재확인 후 실행
          if ([current-energy] of self >= amt) and ([ess-capacity] of offer-proposer - [current-energy] of offer-proposer >= amt) [
            conduct-transaction self offer-proposer amt (item 4 o)
          ]
        ]
        ;; 인박스에서는 아래에서 제거
      ]

      ;; === 발전소 외 노드는 기존 로직 유지 ===
      if (offer-status = "PENDING") and ([breed] of self != plant-nodes) [
        ; 1. 하루(3600틱) 이상 경과 → 자동 거절 및 평판 -3
        if elapsed > 3600 [
          set updated-offer replace-item 5 o "REJECTED"
          ask offer-proposer [ set fail-count fail-count + 1 ]
          ask receiver [ set fail-count fail-count + 1 ]
          if offer-pos != false [
            set offer-list replace-item offer-pos offer-list updated-offer
          ]
          set reputation-score reputation-score - 3
          if is-agent? offer-proposer [
            ask offer-proposer [
              set outbox filter [[x] -> item 0 x != offer-id] outbox
            ]
          ]
        ]
        ; 2. 5~10분(300~600틱) 경과 → 평가
        if (elapsed >= 300) and (elapsed <= 600) [
          let receiver-energy [current-energy] of self
          let receiver-capacity [ess-capacity] of self
          if receiver-energy < amt [
            set updated-offer replace-item 5 o "REJECTED"
            ask offer-proposer [ set fail-count fail-count + 1 ]
            ask receiver [ set fail-count fail-count + 1 ]
            if offer-pos != false [
              set offer-list replace-item offer-pos offer-list updated-offer
            ]
            if is-agent? offer-proposer [
              ask offer-proposer [
                set outbox filter [[x] -> item 0 x != offer-id] outbox
              ]
            ]
          ]
          if receiver-energy >= amt [
            ;; Division by zero 방지: 분모가 0이면 ratio를 0으로 설정
            let ratio ifelse-value (receiver-capacity != 0) [receiver-energy / receiver-capacity] [0]
            let base-prob ifelse-value (ratio < 0.3) [0.3] [ifelse-value (ratio < 0.7) [0.7] [1.0]]
            let offer-proposer-rep [reputation-score] of offer-proposer
            let inbox-count length my-inbox
            let weight ifelse-value (inbox-count >= 5) [1.0 + min (list 0.1 (offer-proposer-rep / 1000))] [1.0]
            let accept-prob base-prob * weight

            if random-float 1.0 <= accept-prob [
              set updated-offer replace-item 5 o "ACCEPTED"
              if offer-pos != false [
                set offer-list replace-item offer-pos offer-list updated-offer
              ]
              if is-agent? offer-proposer [
                ask offer-proposer [ set reputation-score reputation-score + 1 ]
              ]
              set reputation-score reputation-score + 1

              if ([current-energy] of self >= amt) and ([ess-capacity] of offer-proposer - [current-energy] of offer-proposer >= amt) [
                conduct-transaction self offer-proposer amt (item 4 o)
              ]
            ]
            if random-float 1.0 > accept-prob [
              set updated-offer replace-item 5 o "REJECTED"
              ask offer-proposer [ set fail-count fail-count + 1 ]
              ask receiver [ set fail-count fail-count + 1 ]
              if offer-pos != false [
                set offer-list replace-item offer-pos offer-list updated-offer
              ]
              if is-agent? offer-proposer [
                ask offer-proposer [
                  set outbox filter [[x] -> item 0 x != offer-id] outbox
                ]
              ]
            ]
          ]
        ]
        if not ((elapsed > 3600) or ((elapsed >= 300) and (elapsed <= 600))) [
          set updated-inbox lput o updated-inbox
        ]
      ]
      ;; PENDING이 아니면 인박스에 유지하지 않음
    ]
    set inbox updated-inbox
  ]
end

; 전력 판매 희망 오퍼 생성
;; 판매 희망 오퍼 생성 – 노드별 오퍼 타이밍 분산(5분=300틱) 적용
to generate-sell-offers
  ask turtles with [
    current-energy >= ess-capacity * 0.5
    and length outbox < 3
    and breed != ems-nodes
    and breed != plant-nodes
  ] [
    ;; 5분(300틱) 대기 타이밍 분산: next-offer-tick이 현재 ticks 이하일 때만 시도
    if (not has-pending-offer? outbox) and (ticks >= next-offer-tick) [
      let potential-buyers turtles with [
        self != myself
        and (ess-capacity - current-energy) > 0
      ]
      if any? potential-buyers [
        let buyer one-of potential-buyers
        let buyer-excess ([current-energy] of buyer - [ess-capacity] of buyer * 0.5) * 0.5
        let seller-available (current-energy - ess-capacity * 0.5) * 0.5
        let max-sale-amount min (list buyer-excess seller-available)
        if max-sale-amount > 0 [
          let sale-amount random-float max-sale-amount
          let price random-price
          create-offer self buyer sale-amount price
          ;; 오퍼 생성 후 다음 오퍼 생성 가능 시점 갱신 (5분+0~60틱 랜덤)
          set next-offer-tick ticks + 300 + random 60
        ]
      ]
    ]
  ]
end

;; 판매 희망 오퍼 평가: PENDING 상태 오퍼만 평가
to evaluate-sell-offers
  let now ticks
  ask turtles [
    let my-inbox inbox
    let updated-inbox []
    foreach my-inbox [[o] ->
      let offer-id item 0 o
      let offer-proposer item 1 o
      let receiver item 2 o
      let amt item 3 o
      let ts item 6 o
      let elapsed now - ts
      let offer-status item 5 o
      let updated-offer o
      let offer-pos position o offer-list

      ;; === 발전소 노드는 오퍼를 받은 즉시 평가 ===
      if (offer-status = "PENDING") and ([breed] of self = plant-nodes) [
        let receiver-energy [current-energy] of self
        let receiver-capacity [ess-capacity] of self

        ;; 저장공간 부족 시 거절
        if receiver-energy > receiver-capacity - amt [
          set updated-offer replace-item 5 o "REJECTED"
          ask offer-proposer [ set fail-count fail-count + 1 ]
          ask receiver [ set fail-count fail-count + 1 ]
          if offer-pos != false [
            set offer-list replace-item offer-pos offer-list updated-offer
          ]
          if is-agent? offer-proposer [
            ask offer-proposer [
              set outbox filter [[x] -> item 0 x != offer-id] outbox
            ]
          ]
        ]
        ;; 저장공간 충분 시 즉시 승인
        if receiver-energy <= receiver-capacity - amt [
          set updated-offer replace-item 5 o "ACCEPTED"
          if offer-pos != false [
            set offer-list replace-item offer-pos offer-list updated-offer
          ]
          if is-agent? offer-proposer [
            ask offer-proposer [ set reputation-score reputation-score + 1 ]
          ]
          set reputation-score reputation-score + 1

          if ([current-energy] of offer-proposer >= amt) and ([ess-capacity] of self - [current-energy] of self >= amt) [
            conduct-transaction offer-proposer self amt (item 4 o)
          ]
        ]
        ;; 인박스에서는 아래에서 제거
      ]

      ;; === 발전소 외 노드는 기존 로직 유지 ===
      if (offer-status = "PENDING") and ([breed] of self != plant-nodes) [
        if elapsed > 86400 [
          set updated-offer replace-item 5 o "REJECTED"
          ask offer-proposer [ set fail-count fail-count + 1 ]
          ask receiver [ set fail-count fail-count + 1 ]
          if offer-pos != false [
            set offer-list replace-item offer-pos offer-list updated-offer
          ]
          if is-agent? offer-proposer [
            ask offer-proposer [
              set outbox filter [[x] -> item 0 x != offer-id] outbox
            ]
          ]
        ]
        if (elapsed >= 300) and (elapsed <= 600) [
          let receiver-energy [current-energy] of self
          let receiver-capacity [ess-capacity] of self
          if receiver-energy > receiver-capacity - amt [
            set updated-offer replace-item 5 o "REJECTED"
            ask offer-proposer [ set fail-count fail-count + 1 ]
            ask receiver [ set fail-count fail-count + 1 ]
            if offer-pos != false [
              set offer-list replace-item offer-pos offer-list updated-offer
            ]
            if is-agent? offer-proposer [
              ask offer-proposer [
                set outbox filter [[x] -> item 0 x != offer-id] outbox
              ]
            ]
          ]
          if receiver-energy <= receiver-capacity - amt [
            let ratio receiver-energy / receiver-capacity
            let base-prob ifelse-value (ratio < 0.3) [0.7] [ifelse-value (ratio < 0.7) [0.3] [0.0]]
            let offer-proposer-rep [reputation-score] of offer-proposer
            let inbox-count length my-inbox
            let weight ifelse-value (inbox-count >= 5) [1.0 + min (list 0.1 (offer-proposer-rep / 1000))] [1.0]
            let accept-prob base-prob * weight

            if random-float 1.0 <= accept-prob [
              set updated-offer replace-item 5 o "ACCEPTED"
              if offer-pos != false [
                set offer-list replace-item offer-pos offer-list updated-offer
              ]
              if is-agent? offer-proposer [
                ask offer-proposer [ set reputation-score reputation-score + 1 ]
              ]
              set reputation-score reputation-score + 1

              if ([current-energy] of offer-proposer >= amt) and ([ess-capacity] of self - [current-energy] of self >= amt) [
                conduct-transaction offer-proposer self amt (item 4 o)
              ]
            ]
            if random-float 1.0 > accept-prob [
              set updated-offer replace-item 5 o "REJECTED"
              ask offer-proposer [ set fail-count fail-count + 1 ]
              ask receiver [ set fail-count fail-count + 1 ]
              if offer-pos != false [
                set offer-list replace-item offer-pos offer-list updated-offer
              ]
              if is-agent? offer-proposer [
                ask offer-proposer [
                  set outbox filter [[x] -> item 0 x != offer-id] outbox
                ]
              ]
            ]
          ]
        ]
        if not ((elapsed > 86400) or ((elapsed >= 300) and (elapsed <= 600))) [
          set updated-inbox lput o updated-inbox
        ]
      ]
      ;; PENDING이 아니면 인박스에 유지하지 않음
    ]
    set inbox updated-inbox
  ]
end

; 에너지 초과분 EMS에 판매
to auto-sell-excess
  ask turtles with [
    breed != ems-nodes
    and current-energy > ess-capacity
  ] [
    let excess current-energy - ess-capacity
    let price random-price
    conduct-transaction self ems-node excess price
  ]
end

;=================================에너지 토큰 관련 함수============================
; 토큰 변화량 합(양수)
to-report sum-positive-token-delta
  report sum [token-delta] of turtles with [token-delta > 0]
end

; 토큰 변화량 합(음수)
to-report sum-negative-token-delta
  report sum [token-delta] of turtles with [token-delta < 0 ]
end

; 매 tick마다 변화량 계산
to update-token-delta-per-tick
  let current-positive sum [token-delta] of turtles with [token-delta > 0]
  let current-negative sum [token-delta] of turtles with [token-delta < 0]
  set tick-positive-token-delta current-positive - prev-positive-token-delta
  set tick-negative-token-delta current-negative - prev-negative-token-delta
  set prev-positive-token-delta current-positive
  set prev-negative-token-delta current-negative
end

; 시간대별 전기료 가중치함수 (단위:6시간)
to-report get-hourly-price-factor [hour]
  ifelse hour < 6 [
    report 0.80
  ][ifelse hour < 12 [
      report 1.00
    ][ifelse  hour < 18 [
        report 1.20
      ][
        report 1.00
  ]]]
end

; 시간대별(6시간) 토큰 환산 전기요금
to-report get-current-price-per-kwh-hourly
  let current-month time:get "month" current-datetime
  let base-price item (current-month - 1) monthly-electricity-prices
  let hour time:get "hour" current-datetime
  let factor get-hourly-price-factor hour
  let hourly-price base-price * factor
  report hourly-price / token-price
end

;=====================================공격 함수=======================================
; DDoS 공격
to do-ddos
  ;; 1. 공격자 집합 선택
  let candidates shuffle sort household-nodes
  set ddos-attackers sublist candidates 0 ddos-attackers-cnt

  ;; 2. ddos-total-offers 개수만큼 거짓 오퍼 생성
  repeat ddos-total-offers [
    let ddos-proposer one-of ddos-attackers
    let receiver      one-of remove ddos-proposer ddos-attackers
    let fake-amount   ([ess-capacity] of ddos-proposer) * 0.1
    let fake-price    energy-price

    ;; 2-1. offer-counter 한 번만 증가 및 ID 할당
    set offer-counter offer-counter + 1
    let new-id offer-counter

    ;; 2-2. ATTACKED 상태 오퍼 생성
    let new-offer (list
      new-id
      ddos-proposer
      receiver
      fake-amount
      fake-price
      "ATTACKED"
      ticks
    )

    ;; 2-3. 생성 틱 기록
    table:put attacked-ticks-map new-id ticks
    table:put offer-attack-type-map new-id "DDoS"

    ;; 공격자별 카운트 누적
    let count-so-far table:get-or-default attacker-activity-map [who] of ddos-proposer 0
    table:put attacker-activity-map [who] of ddos-proposer (count-so-far + 1)

    ;; 2-4. 랜덤 전환 틱 기록 (10~250 틱 사이)
    let random-tick fake-transition-min + random (fake-transition-max - fake-transition-min + 1)
    table:put fake-transition-tick-map new-id random-tick

    ;; 2-5. offer-list 및 inbox/outbox 기록
    set offer-list lput new-offer offer-list
    ask ddos-proposer [ set outbox lput new-offer outbox ]
    ask receiver      [ set inbox  lput new-offer inbox  ]

    ;; 2-6. pending-transactions에 추가 (기존 블록 생성 로직 활용)
    let tx-data (list new-id ddos-proposer receiver fake-amount fake-price ticks)
    add-transaction-to-pending tx-data
  ]

  ;; 3. 공격 로그 기록
  let attacker-names map [a -> [real-name] of a] ddos-attackers
  let attacker-list sort ddos-attackers
  let risk-level calculate-risk-level "DDoS" length attacker-list 1
  log-attack-event "DDoS" risk-level attacker-names ["All Nodes"]
end

;; 문자열에서 real-name 뽑아 에이전트를 반환
to-report agent-from-string [ s ]
  ;; 예시 s = "\"buyer\": \"Taeyang_01\""

  ;; 1) prefix ("\"seller\": \"" 또는 "\"buyer\": \"") 길이 계산
  ;;    – '"' 포함해서 전체 prefix 길이를 정확히 맞춰 주세요.
  let prefix-len ifelse-value (substring s 0 9 = "\"seller\":") [
    length "\"seller\": \""
  ] [
    length "\"buyer\": \""
  ]

  ;; 2) 실제 이름 부분만 추출
  let rest substring s prefix-len (length s - 1)
    ;; 마지막 쌍따옴표 전까지 자름

  ;; 3) real-name과 일치하는 turtle 찾기
  let target one-of turtles with [ real-name = rest ]
  if target = nobody [
    error (word "거북이를 찾을 수 없음: " rest)
  ]
  report target
end




; 타임스탬프 리플레이 공격
to do-timestamp-replay-attack
  ;; 1) 공격 감지 플래그 초기화
  set timestamp-replay-detected? false

  ;; 2) 공격자 후보 선정
  let candidates turtles with [breed != ems-nodes and reputation-score >= 80]
  if count candidates = 0 [ stop ]
  let actual-count min list tsp-rp-cnt count candidates
  let attackers n-of actual-count candidates

  ;; 3) 재전송 공격 수행
  ask attackers [
    if empty? personal-blockchain [ stop ]
    ;; 과거 거래 하나 선택
    let tx one-of personal-blockchain
    set attempt-count attempt-count + 1

    ;; 팝업용 플래그 세팅
    set timestamp-replay-detected? true

    ;; 새 오퍼 ID 발급
    set offer-counter offer-counter + 1
    let new-id offer-counter

    ;; tx에서 실제 에이전트 및 필드 꺼내기
    let seller-agent agent-from-string item 0 tx
    let buyer-agent  agent-from-string item 1 tx
    let amount        item 3 tx
    let price         item 4 tx

    ;; ATTACKED 상태 오퍼 생성
    let replay-offer (list
      new-id
      seller-agent
      buyer-agent
      amount
      price
      "ATTACKED"
      ticks
    )

    ;; 3-1) 생성 틱 기록
    table:put attacked-ticks-map new-id ticks
    table:put offer-attack-type-map new-id "Timestamp-Replay"

    ;; → 공격자별 카운트 누적
    let count-so-far table:get-or-default attacker-activity-map self 0
    let agent-id [who] of self
    table:put attacker-activity-map agent-id (count-so-far + 1)

    ;; 3-2) 랜덤 전환 틱 기록 (10~250틱 사이)
    let random-tick fake-transition-min
    + random (fake-transition-max - fake-transition-min + 1)
    table:put fake-transition-tick-map new-id random-tick

    ;; 3-3) offer-list, inbox/outbox 기록
    set offer-list lput replay-offer offer-list
    ask seller-agent [ set outbox lput replay-offer outbox ]
    ask buyer-agent  [ set inbox  lput replay-offer inbox  ]

    ;; 3-4) pending-transactions에 추가 (블록체인 합의 로직 유지)
    let tx-data (list new-id seller-agent buyer-agent amount price ticks)
    add-transaction-to-pending tx-data
  ]

  ;; 4) 팝업 및 로그 처리 (ask 블록 바깥에서)
  if timestamp-replay-detected? [
    let attacker-list sort attackers
    let first-attacker first attacker-list
    user-message (word "Timestamp replay attack detected from node " [node-id] of first-attacker)

    let attacker-names map [a -> [real-name] of a] attacker-list
    let risk-level calculate-risk-level "Timestamp-Replay" length attacker-list 1
    log-attack-event "Timestamp-Replay" risk-level attacker-names ["Network"]
  ]
end


;; ATTACKED → FAKE 전환 리포터
to-report convert-offer [o now]
  let status item 5 o
  let id     item 0 o

  if status = "ATTACKED" [
    if table:has-key? fake-transition-tick-map id [
      let created    table:get attacked-ticks-map id
      let trigger    table:get fake-transition-tick-map id
      let age        now - created
      if age >= trigger [
        ;; 전환 직전 지연값 기록: [공격유형 delay]
        let attack-type table:get offer-attack-type-map id
        set attack-conversion-delays lput (list attack-type age) attack-conversion-delays

        ;; 상태 전환
        table:remove attacked-ticks-map id
        table:remove fake-transition-tick-map id
        report replace-item 5 o "FAKE"
      ]
    ]
  ]
  report o
end

to record-attacked-offer [offer-id]
  table:put attacked-ticks-map offer-id ticks
end

;===========================공격 출력 함수=============================
; 공격 로그 초기화
to init-attack-monitoring
  set attack-log []
  set attack-detection-history []
  set attack-response-times []
  set network-delay-measurements []
  set ddos-attack-count 0
  set timestamp-replay-count 0
end

; 공격 정보 기록
to log-attack-event [attack-type risk-level attacker-list target-list]
  let attack-id length attack-log + 1
  let detection-time ticks
  let current-delay calculate-network-delay
  let response-time calculate-response-time attack-type

  let attack-record (list
    attack-id
    attack-type
    risk-level
    detection-time
    response-time
    current-delay
    attacker-list
    target-list
    "DETECTED"
  )

  set attack-log lput attack-record attack-log
  set attack-detection-history lput attack-record attack-detection-history

  ; 공격 유형별 카운트 증가
  if attack-type = "DDoS" [
    set ddos-attack-count ddos-attack-count + 1
  ]
  if attack-type = "Timestamp-Replay" [
    set timestamp-replay-count timestamp-replay-count + 1
  ]

  ; 대응 시간 기록
  set attack-response-times lput response-time attack-response-times
  set network-delay-measurements lput current-delay network-delay-measurements
end

; 위험도 계산
to-report calculate-risk-level [attack-type attacker-count target-count]
  let base-risk 0

  ; 공격 유형별 기본 위험도
  if attack-type = "DDoS" [
    set base-risk 3  ; 높음
  ]
  if attack-type = "Timestamp-Replay" [
    set base-risk 2  ; 중간
  ]

  ; 공격자 수와 대상 수에 따른 위험도 조정
  let scale-factor (attacker-count + target-count) / 10
  let final-risk base-risk + scale-factor

  ; 위험도 레벨 반환
  if final-risk <= 1 [ report "LOW" ]
  if final-risk <= 2 [ report "MEDIUM" ]
  if final-risk <= 3 [ report "HIGH" ]
  report "CRITICAL"
end

; 네트워크 지연 계산
to-report calculate-network-delay
  let total-delay 0
  let count-nodes 0

  ask turtles with [breed != ems-nodes] [
    if length inbox > 0 [
      let avg-delay mean map [o -> ticks - item 6 o] inbox
      set total-delay total-delay + avg-delay
      set count-nodes count-nodes + 1
    ]
  ]

  ifelse count-nodes > 0 [
    report total-delay / count-nodes
  ] [
    report 0
  ]
end

; 대응 시간 계산
to-report calculate-response-time [attack-type]
  ; 공격 유형별 기본 대응 시간 (틱 단위)
  if attack-type = "DDoS" [
    report 150 + random 50  ; 150-200틱
  ]
  if attack-type = "Timestamp-Replay" [
    report 100 + random 30  ; 100-130틱
  ]
  report 120 + random 40    ; 기본값
end

; 공격 현황 출력
to print-attack-monitoring
  clear-output
  ; 초기화 확인
  if not is-list? attack-log [
    output-print "Error: attack-log is not initialized properly"
    stop
  ]
  output-print "=== ATTACK MONITORING DASHBOARD ==="
  output-print ""

  ; 공격 통계 요약
  output-print "--- ATTACK STATISTICS ---"
  output-print (word "Total Attacks Detected: " length attack-log)
  output-print (word "DDoS Attacks: " ddos-attack-count)
  output-print (word "Timestamp Replay Attacks: " timestamp-replay-count)

  ; FAKE 오퍼 확정 개수 출력
  let fake-count fake-offer-count
  output-print (word "Confirmed FAKE Offers: " fake-count)
  output-print ""

  ;; DDoS 방어 조치
  ifelse ddos-attack-count > 0 [
    output-print "DDoS protections applied: rate limiting, offer filtering"
  ] [
    output-print "No DDoS protection actions were needed."
  ]

  ;; 타임스탬프 리플레이 방어 조치
  ifelse timestamp-replay-count > 0 [
    output-print "Timestamp replay defenses: transaction timestamp validation, replay attack detection"
  ] [
    output-print "No timestamp replay defense actions were needed."
  ]

  output-print ""

  ;; 7. 공격자별 활동 (상위 N명)
  output-print (word "--- ATTACKER ACTIVITY (Top " top-n-attackers " Agents) ---")

  ;; 1) 모든 공격자 ID 리스트 가져오기 (키는 who 또는 node-id)
  let agent-ids table:keys attacker-activity-map

  ;; 2) (agent-id, count) 쌍 리스트 생성
  let counts map [ id -> (list id (table:get attacker-activity-map id)) ] agent-ids

  ;; 3) 공격 횟수 내림차순 정렬
  let sorted-counts sort-by [[p1 p2] -> item 1 p1 > item 1 p2] counts

  ;; 4) 상위 N개만 출력
  let top-list sublist sorted-counts 0 (min list top-n-attackers length sorted-counts)
  foreach top-list [ rec ->
    let agent-id first rec        ;; 숫자형 ID
    let cnt      last rec         ;; 공격 횟수
    ;; 숫자 ID에서 실제 거북이 객체로 변환
    let ag turtle agent-id
    if ag != nobody [
      output-print (word
        "[Agent " [node-id] of ag "] "
        [real-name] of ag ": "
        cnt " attacks"
      )
    ]
  ]

  ; 평균 대응 시간
  if length attack-response-times > 0 [
    let avg-response precision (mean attack-response-times) 2
    output-print (word "Average Response Time: " avg-response " ticks")
  ]

  ; 평균 네트워크 지연
  if length network-delay-measurements > 0 [
    let avg-delay precision (mean network-delay-measurements) 2
    output-print (word "Average Network Delay: " avg-delay " ticks")
  ]
  output-print ""

  ; 상세 공격 로그 테이블
  output-print "--- DETAILED ATTACK LOG ---"
  let id-w 4
  let type-w 15
  let risk-w 8
  let time-w 8
  let resp-w 8
  let delay-w 8
  let status-w 10

  output-print (word
    pad-string "ID" id-w
    " | " pad-string "Attack Type" type-w
    " | " pad-string "Risk" risk-w
    " | " pad-string "Time" time-w
    " | " pad-string "Response" resp-w
    " | " pad-string "Delay" delay-w
    " | " pad-string "Status" status-w
  )

  output-print (word
    pad-string "----" id-w
    " | " pad-string "---------------" type-w
    " | " pad-string "--------" risk-w
    " | " pad-string "--------" time-w
    " | " pad-string "--------" resp-w
    " | " pad-string "--------" delay-w
    " | " pad-string "----------" status-w
  )

  ; 최근 20개 공격 로그만 출력
  let recent-attacks []
  let start-idx max (list 0 (length attack-log - 20))
  let end-idx length attack-log

  let i start-idx
  while [i < end-idx] [
    set recent-attacks lput (item i attack-log) recent-attacks
    set i i + 1
  ]

  foreach recent-attacks [ attack ->
    output-print (word
      pad-string (item 0 attack) id-w
      " | " pad-string (item 1 attack) type-w
      " | " pad-string (item 2 attack) risk-w
      " | " pad-string (item 3 attack) time-w
      " | " pad-string (precision (item 4 attack) 1) resp-w
      " | " pad-string (precision (item 5 attack) 1) delay-w
      " | " pad-string (item 8 attack) status-w
    )
  ]

  ;; Average Conversion Delay 계산
  if (is-list? attack-conversion-delays) and (length attack-conversion-delays > 0) [
    output-print ""
    output-print "--- AVERAGE CONVERSION DELAY ---"
    let by-type remove-duplicates map [d -> first d] attack-conversion-delays
    foreach by-type [atype ->
      let delays filter [d -> first d = atype] attack-conversion-delays
      let values map [d -> last d] delays
      let avg precision (sum values / length values) 2
      output-print (word atype ": " avg " ticks")
    ]
  ]

  output-print ""
  output-print "--- RISK LEVEL DISTRIBUTION ---"
  print-risk-distribution

  output-print ""
  output-print "--- NETWORK SECURITY STATUS ---"
  print-network-security-status
end

; 위험도 분포 출력
to print-risk-distribution
  let low-count 0
  let medium-count 0
  let high-count 0
  let critical-count 0

  foreach attack-log [ attack ->
    let risk-level item 2 attack
    if risk-level = "LOW" [ set low-count low-count + 1 ]
    if risk-level = "MEDIUM" [ set medium-count medium-count + 1 ]
    if risk-level = "HIGH" [ set high-count high-count + 1 ]
    if risk-level = "CRITICAL" [ set critical-count critical-count + 1 ]
  ]

  output-print (word "LOW: " low-count " | MEDIUM: " medium-count " | HIGH: " high-count " | CRITICAL: " critical-count)
end

; 네트워크 보안 상태 출력
to print-network-security-status
  let current-delay calculate-network-delay
  let security-level "SECURE"

  if current-delay > 100 [ set security-level "DEGRADED" ]
  if current-delay > 300 [ set security-level "COMPROMISED" ]
  if timestamp-replay-detected? [ set security-level "UNDER ATTACK" ]

  output-print (word "Current Security Level: " security-level)
  output-print (word "Current Network Delay: " precision current-delay 2 " ticks")
  output-print (word "Timestamp Replay Detected: " timestamp-replay-detected?)
end



;===========================go 함수=========================

to go
  handle-selection
  ;; 틱당 오퍼 카운터 초기화
  set tick-offer-counter 0

  ;; 틱당 검증자 처리 카운터 초기화
  ask validators [
    set validated-offers-this-tick 0
  ]

  ;; 1) 시간 및 에너지 업데이트
  update-time
  update-energy-values
  apply-consumption-priority
  update-shared-energy-status

  ;; 2) ESS 초과분 자동 판매 우선 처리
  auto-sell-excess

  ;; 3) 판매·구매 오퍼 생성
  if tick-offer-counter < offer-per-tick-limit [
    generate-sell-offers
    generate-buy-offers
  ]

  ;; 4) 오퍼 평가
  evaluate-buy-offers
  evaluate-sell-offers

  ;; 5) 기타 토큰·메트릭 업데이트
  update-token-delta-per-tick
  update-metrics

  ;; 다중 원본 검증 체인 선택
  receive-validator-hashes
  select-longest-valid-chain

  manage-link-ttl
  let now ticks
  set offer-list map [ o -> convert-offer o now ] offer-list
  ask turtles [
    set outbox map [ o -> convert-offer o now ] outbox
    set inbox  map [ o -> convert-offer o now ] inbox
  ]

  ; 검증자 교체 주기 관리
  set validator-rotation-tick validator-rotation-tick + 1
  if validator-rotation-tick >= 24000 [
    assign-validators
    set validator-rotation-tick 0
  ]

  ask turtles [
    if validator? [ set base-color green + 5 ]
    if not validator? [ set base-color original-color ]
    set color base-color
  ]
  tick
end
@#$#@#$#@
GRAPHICS-WINDOW
219
14
716
512
-1
-1
15.8
1
10
1
1
1
0
0
0
1
-15
15
-15
15
0
0
1
ticks
30.0

BUTTON
23
100
216
133
setup
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
23
134
119
167
자동 실행
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
120
134
216
167
실행(1sec)
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
120
332
216
377
총 거절 거래
rejected-offer-count
17
1
11

MONITOR
523
23
597
68
총 블록 수
length [blockchain] of one-of ems-nodes
17
1
11

MONITOR
227
23
350
68
날짜
current-date-time
17
1
11

MONITOR
817
15
913
60
전력 소모량 (6h)
precision ([consumption] of turtle selected-who) 4
17
1
11

BUTTON
721
15
816
60
노드 선택
set selection-mode? not selection-mode?
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
817
62
913
107
전력 생산량 (6h)
precision ([production] of turtle selected-who) 4
17
1
11

OUTPUT
934
54
1572
550
12

MONITOR
353
23
442
68
평균 평판 점수
precision (mean [reputation-score] of turtles) 4
17
1
11

MONITOR
24
238
120
283
토큰 변화량(+)
sum-positive-token-delta
3
1
11

MONITOR
120
238
216
283
토큰 변화량(-)
sum-negative-token-delta
3
1
11

MONITOR
444
23
521
68
거래 성공률
trade-success-rate
17
1
11

MONITOR
24
285
120
330
총 거래 시도
total-trade-attempts
17
1
11

MONITOR
24
332
120
377
총 성공 거래
accepted-offer-count
17
1
11

MONITOR
120
285
216
330
총 미처리 거래
pending-offer-count
17
1
11

MONITOR
817
108
913
153
거래 시도 횟수
selected-attempt-count
17
1
11

MONITOR
817
155
913
200
거래 성공 횟수
selected-accepted-count
17
1
11

MONITOR
817
202
913
247
거래 실패 횟수
selected-rejected-count
17
1
11

PLOT
24
380
216
510
거래 추이
Tick
거래 건수
0.0
1.0
0.0
1.0
true
false
"" ""
PENS
"총 거래 시도 횟수" 1.0 0 -13791810 true "" "plot length offer-list"
"총 거래 성공 횟수" 1.0 0 -15040220 true "" "plot length filter [o -> (length o = 7) and (item 5 o = \"ACCEPTED\")] offer-list"
"총 거래 실패 횟수" 1.0 0 -5298144 true "" "plot length filter [o -> (length o = 7) and (item 5 o = \"REJECTED\")] offer-list"
"총 미처리 거래 횟수" 1.0 0 -9276814 true "" "plot length filter [ o ->\n  (length o = 7) and\n  ( (item 5 o = \"PENDING\") or (item 5 o = \"PENDING-DDOS\") )\n] offer-list\n"

MONITOR
225
459
708
504
현재 검증자 노드
validator-names
17
1
11

BUTTON
1028
15
1142
48
전체 노드 정보
print-all-nodes-info\n  
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
1146
15
1259
48
블록체인 현황
print-blockchain-table
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
23
169
119
202
10분
repeat 600 [ go ]
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
120
169
216
202
1시간
repeat 3600 [ go ]
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

INPUTBOX
23
15
216
75
start-datetime
2025-07-17 08:30
1
0
String

TEXTBOX
51
81
206
99
XXXX-XX-XX XX:XX 으로 입력
10
0.0
1

TEXTBOX
723
259
874
279
공격 이벤트\n
12
0.0
1

SLIDER
720
321
867
354
ddos-total-offers
ddos-total-offers
0
200
51.0
1
1
NIL
HORIZONTAL

BUTTON
720
391
867
425
DDoS & 다중 협업
do-ddos\n
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
720
355
867
388
ddos-attackers-cnt
ddos-attackers-cnt
2
10
4.0
2
1
NIL
HORIZONTAL

TEXTBOX
155
21
208
39
날짜 설정\n
12
0.0
1

SLIDER
1265
15
1437
48
block-size
block-size
1
100
20.0
1
1
NIL
HORIZONTAL

BUTTON
721
466
868
500
타임스탬프 리플레이
do-timestamp-replay-attack
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
721
431
868
464
tsp-rp-cnt
tsp-rp-cnt
1
10
3.0
1
1
NIL
HORIZONTAL

MONITOR
721
155
817
200
평판 점수
selected-reputation
17
1
11

MONITOR
721
62
817
107
이름 / ID
selected-name-and-id
17
1
11

MONITOR
721
202
817
247
에너지 보유량
selected-current-energy
17
1
11

MONITOR
721
108
817
153
노드 종류
selected-node-type
17
1
11

BUTTON
936
15
1024
48
공격 로그
print-attack-monitoring
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
720
275
867
320
가짜 거래 식별
fake-offer-count
17
1
11

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

factory
false
0
Rectangle -7500403 true true 76 194 285 270
Rectangle -7500403 true true 36 95 59 231
Rectangle -16777216 true false 90 210 270 240
Line -7500403 true 90 195 90 255
Line -7500403 true 120 195 120 255
Line -7500403 true 150 195 150 240
Line -7500403 true 180 195 180 255
Line -7500403 true 210 210 210 240
Line -7500403 true 240 210 240 240
Line -7500403 true 90 225 270 225
Circle -1 true false 37 73 32
Circle -1 true false 55 38 54
Circle -1 true false 96 21 42
Circle -1 true false 105 40 32
Circle -1 true false 129 19 42
Rectangle -7500403 true true 14 228 78 270

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.4.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
