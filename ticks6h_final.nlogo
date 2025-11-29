; === 블록체인 기반 분산 에너지 거래 시뮬레이션 ===
; NetLogo 6.4.0 (64-bit)

extensions [time table]

; 1. 에이전트 및 글로벌 변수 정의
breed [ems-nodes ems]
breed [household-nodes household]
breed [company-nodes company]
breed [plant-nodes plant]
breed [vpp-nodes vpp-node]
links-own [ttl]

globals [
  economic-efficiency
  security-response-time
  monthly-shortages
  block-counter
  energy-price
  current-datetime
  selected-who
  selection-mode?
  selected-nodde
  tick-unmet-nodes-count-list ;tick별 에너지 소비 미충족 노드
  validators  ; 검증자 풀 추가
  shared-energy-status ; 모든 노드의 실시간 상태 공유 리스트
  monthly-electricity-prices ; 12개월 전기요금 리스트
  token-price ; 토큰 1개당 가격
  prev-positive-token-delta ; 틱 별로 토큰 변화량 확인 변수
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
  last-block-hash        ; 직전 블록의 해시값
  ascii-table            ; 아스키 코드
  validator-rotation-tick ; 검증자 교체 주기 카운터
  proposed-block         ; 현재 제안된 블록 데이터
  block-approvals        ; 각 블록에 대한 검증자들의 승인(서명) 리스트
  consensus-threshold    ; 합의에 필요한 승인 수
  sync-needed ; 동기화 필요 여부 플래그

  ;=============PPA========
  ppa-proposer        ; PPA 제안자 에이전트
  ppa-receivers       ; PPA 수신자 agentset
  ppa-tick-count      ; PPA 경과 틱 수
  ppa-received-this-tick
  ppa-monitor-factor        ;; 한 틱당 고정 랜덤 계수(0.9~1.1)
  ppa-energy-delivery-rate
  ppa-cost-savings-percentage
  ppa-received-avg-per-tick

  ;===========VPP============
  vpp-capacity-utilization-rate
  vpp-demand-response-success-rate
  vpp-revenue-per-mwh
  demand-response-request-count
  successful-dispatch-count
  total-revenue
  total-mwh-sold
  base-price
  actual-price
]

turtles-own [
  true-energy           ; 실제 보유 전력량 (내부용)
  true-production       ; 실제 생산량 (내부용)
  true-consumption      ; 실제 소비량 (내부용)
  base-color
  inbox
  outbox
  current-energy
  personal-blockchain
  selected?
  real-name             ; 기관명
  registration-id       ; 사업자등록번호/고유코드
  region                ; 지역
  validator-id          ; 암호화된 검증자 ID
  node-id               ; 사용자 정의 노드 ID (who 대신 사용)
  reputation-score      ; 평판 점수
  validator?            ; 검증자 여부 추가
  token-delta           ; 토큰 변화량 (양수=수입, 음수=지출)
  cooldown-tick
  has-ess?              ; ESS 보유 여부
  ess-capacity          ; ESS 용량
  monthly-consumption
  daily-consumption
  sixhour-consumption
  consumption
  monthly-production
  daily-production
  sixhour-production
  production
  is-vpp-member?  ;; VPP 소속 여부
  my-vpp          ;; 해당 노드가 소속된 VPP
]
household-nodes-own [
  current-energy
  ess-capacity
  has-ess?
  inbox
  outbox
  personal-blockchain
  true-consumption
  true-production
  true-energy
]
vpp-nodes-own [
  member-list         ;; 구성원 agentset
  current-energy      ;; 전체 VPP의 전력 보유량
  ess-capacity        ;; 전체 ESS 저장용량
  true-production     ;; 구성원 생산량 합계 ✅
  true-consumption    ;; 구성원 소비량 합계 ✅
  inbox
  outbox
  personal-blockchain
  has-ess?
]
ems-nodes-own [
  current-energy
  ess-storage
  inbox
  outbox
  blockchain
  personal-blockchain
]
company-nodes-own [
  current-energy
  ess-capacity
  has-ess?
  inbox
  outbox
  personal-blockchain
  true-consumption
  true-production
  true-energy
]
plant-nodes-own [
  current-energy
  ess-capacity
  has-ess?
  inbox
  outbox
  personal-blockchain
  true-production
  true-consumption
  true-energy
]



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

to-report household-node-coords-and-ess
  report [
    [ [-11 -3] true ]
    [ [-7 -5] false ]
    [ [-4 -9] true ]
    [ [-3 -7] false ]
    [ [-5 -8] false ]
    [ [-1 -6] true ]
    [ [-3 -5] false ]
    [ [1 -2] true ]
    [ [0 -4] false ]
    [ [-4 -5] true ]
    [ [-3 -3] false ]
    [ [-2 -4] false ]
    [ [2 -6] true ]
    [ [1 -9] false ]
    [ [-1 -8] true ]
    [ [-1 -10] false ]
    [ [-2 -1] true ]
    [ [-2 -2] false ]
    [ [-3 0] true ]
    [ [-6 -2] false ]
    [ [-4 -2] false ]
    [ [-8 0] true ]
    [ [-7 2] false ]
    [ [-4 -2] true ]
    [ [-5 4] false ]
    [ [-7 5] false ]
    [ [0 -2] true ]
    [ [0 -1] false ]
    [ [-1 2] false ]
    [ [-1 0] false ]
    [ [0 0] false ]
    [ [1 -1] true ]
    [ [3 -1] false ]
    [ [2 1] false ]
    [ [5 -6] true ]
    [ [5 -4] false ]
    [ [3 -3] false ]
    [ [2 -4] false ]
    [ [3 -5] false ]
    [ [4 -1] true ]
    [ [6 0] false ]
    [ [5 1] false ]
    [ [4 0] false ]
    [ [6 -2] true ]
    [ [7 -4] false ]
    [ [7 0] false ]
    [ [6 2] true ]
    [ [7 2] false ]
    [ [9 4] false ]
    [ [9 3] true ]
    [ [8 1] false ]
    [ [11 3] true ]
    [ [12 2] false ]
    [ [10 0] true ]
    [ [11 -2] false ]
    [ [12 -1] false ]
    [ [14 2] false ]
    [ [15 0] false ]
  ]
end

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

; 3. 초기화 프로시저 (EMS 노드 ID 0로 설정)
to setup
  clear-all
  reset-ticks
  setup-ascii-table
  import-drawing "imaged.png"
  set block-size 20
  set pending-transactions []
  set last-block-hash "GENESIS"
  set block-counter 0
  set energy-price 65
  set tick-unmet-nodes-count-list []
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
  set base-price item 0 monthly-electricity-prices
  set actual-price base-price
  set token-price 12.9
  set selection-mode? false

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
    set inbox []
    set outbox []
    set personal-blockchain []
    set selected? false
    set validator? false
    setxy -7 0
    set node-id who
    set cooldown-tick 0
  ]

  let co-coords company-node-positions
  foreach co-coords [
    xy ->
    create-company-nodes 1 [
      set color red
      set base-color red
      set shape "square"
      set has-ess? true
      set ess-capacity 500
      set current-energy 300
      set inbox []
      set outbox []
      set personal-blockchain []
      set selected? false
      set validator? false
      setxy (item 0 xy + random-float 0.5 - 0.25) (item 1 xy + random-float 0.5 - 0.25)
      set node-id who
      let ratio-c (0.9 + random-float 0.2)
      let ratio-p (0.9 + random-float 0.2)
      set monthly-consumption 20000 * ratio-c
      set daily-consumption monthly-consumption / 30
      set sixhour-consumption monthly-consumption / 120
      set consumption sixhour-consumption
      set monthly-production 5000 * ratio-p
      set daily-production monthly-production / 30
      set sixhour-production monthly-production / 120
      set production sixhour-production
      set cooldown-tick 0
    ]
  ]

  let coord-ess-list household-node-coords-and-ess
  foreach coord-ess-list [
    ce ->
    let xy item 0 ce
    let ess? item 1 ce
    create-household-nodes 1 [
      setxy (item 0 xy + random-float 0.5 - 0.25) (item 1 xy + random-float 0.5 - 0.25)
      set shape "person"
      set color (ifelse-value ess? [green][yellow])
      set base-color (ifelse-value ess? [green][yellow])
      set has-ess? ess?
      set ess-capacity (ifelse-value ess? [25][0])
      set current-energy (ifelse-value ess? [25][0])
      set inbox []
      set outbox []
      set personal-blockchain []
      set selected? false
      set validator? false
      set node-id who
      set cooldown-tick 0
      if has-ess? [
        set monthly-production 250
        set monthly-consumption 400
        set daily-production monthly-production / 30
        set sixhour-production monthly-production / 120
        set production sixhour-production
        set daily-consumption monthly-consumption / 30
        set sixhour-consumption monthly-consumption / 120
        set consumption sixhour-consumption
      ]
      if not has-ess? [
        let ratio-c (0.9 + random-float 0.2)
        let ratio-p (0.9 + random-float 0.2)
        set monthly-consumption 400 * ratio-c
        set daily-consumption monthly-consumption / 30
        set sixhour-consumption monthly-consumption / 120
        set consumption sixhour-consumption
        set monthly-production 25 * ratio-p
        set daily-production monthly-production / 30
        set sixhour-production monthly-production / 120
        set production sixhour-production
      ]
    ]
  ]

  create-plant-nodes 1 [
    set color orange
    set base-color orange
    set shape "wheel"
    set production 200000
    set current-energy 600000
    set has-ess? true
    set ess-capacity 600000
    set inbox []
    set outbox []
    set personal-blockchain []
    set selected? false
    set validator? false
    setxy -11 8
    set node-id who
    set cooldown-tick 0
  ]
  create-vpp-nodes 1 [
    set color magenta + 1
    set base-color magenta + 1
    set shape "factory"
    set node-id who
    set real-name "VPP"
    set personal-blockchain []
    setxy 8 0
    set ess-capacity 10000  ;; kWh 기준
    set current-energy 0

    set demand-response-request-count 0
    set successful-dispatch-count    0
    set total-revenue                0
    set total-mwh-sold               0
    set selected? false
    set validator? false
  ]
  ask turtles [ set is-vpp-member? false ]
  assign-vpp-members            ;; VPP 구성원 자동 등록

  generate-identities
  ensure-unique-names
  ask turtles [ set size 1.0 ]
  ask turtles [ ensure-uniqueness ]
  ask household-nodes [ set reputation-score 80 ]
  ask company-nodes [ set reputation-score 80 ]
  ask vpp-nodes [ set reputation-score 80 set size 1.3 ]
  ask plant-nodes [ set reputation-score 80 ]
  ask ems-nodes [ set color blue ]
  ask plant-nodes [ set color orange ]

  ; layout-circle turtles 10

  ask turtles [
    type "Node ID: " type node-id
    type ", Name: " type real-name
    type ", Region: " type region
    type ", Reputation: " type reputation-score
    type ", Validator: " type validator?
    type ", RegID: " type registration-id
    type ", ValidatorID: " print validator-id
    set token-delta 0
  ]

  assign-validators
  update-shared-energy-status
  set consensus-threshold ceiling (count validators * 0.67) ; 2/3 이상 동의 필요
  ask household-nodes [
    if is-vpp-member? [
      set color violet ;vpp참여하는 가정은 보라
    ]
    if (not is-vpp-member?) and has-ess? [
      set color green
    ]
    if (not is-vpp-member?) and (not has-ess?) [
      set color yellow
    ]
  ]
  ask company-nodes [
    if is-vpp-member? [
      set color violet + 2 ; vpp참여하는 기업은 보라
    ] if (not is-vpp-member?) [
      set color red
    ]
  ]
  setup-ppa
  set selected-nodde nobody
  reset-ticks
end

to assign-vpp-members
  let vpp-agent one-of vpp-nodes
  if vpp-agent = nobody [ stop ]

  ;; 1) ESS 보유 가정 중 3개 선택
  let ess-hh household-nodes with [has-ess? and not is-vpp-member?]
  let selected-ess n-of (min (list 3 count ess-hh)) ess-hh

  ;; 2) ESS 미보유 가정 중 7개 선택
  let noness-hh household-nodes with [not has-ess? and not is-vpp-member?]
  let selected-noness n-of (min (list 7 count noness-hh)) noness-hh

  ;; 3) 최종 멤버 집합 (turtle-set 안에 agentset 두 개를 괄호 없이 나열)
  let members (turtle-set selected-ess selected-noness)

  ;; 4) VPP 등록
  if any? members [
    ask members [
      set is-vpp-member? true
      set my-vpp vpp-agent
    ]
    ask vpp-agent [
      set member-list members
    ]
  ]
end


to vpp-trade-cycle
  ;; 모든 VPP 노드에 대해 반복
  ask vpp-nodes [
    ;; 총 잉여 전력 및 총 부족 전력을 저장할 변수 초기화
    let total-surplus 0
    let total-deficit 0

    ;; 🧮 구성원들의 잉여/부족 에너지 합산
    if is-agentset? member-list [
      ask member-list [
        ;; net-energy = 현재 보유 전력 - 소비 전력
        let net-energy current-energy - consumption

        ;; 잉여일 경우 합산
        if net-energy > 0 [
          set total-surplus total-surplus + net-energy
        ]

        ;; 부족일 경우 합산 (양수로 표현)
        if net-energy < 0 [
          set total-deficit total-deficit - net-energy
        ]
      ]
    ]

    ;; ✅ [1] VPP가 EMS에 전력 판매
    if total-surplus > 0 [
      let buyer one-of (ems-nodes with [ess-storage - current-energy > 0])
      if buyer != nobody [
        let sell-amount min (list total-surplus ([ess-storage] of buyer - [current-energy] of buyer))
        conduct-transaction self buyer sell-amount get-current-price-per-kwh-hourly
      ]
    ]

    ;; ✅ [2] VPP가 발전소에서 전력 구매
    if total-deficit > 0 [
      ;; 전력이 남아있는 발전소 중 한 곳 선택
      let seller one-of (plant-nodes with [current-energy > 0])

      if seller != nobody [
        ;; 구매 가능량 = VPP 부족 전력과 발전소 보유 전력 중 작은 값
        let space ess-capacity - current-energy
        let buy-amount min (list total-deficit space [current-energy] of seller)

        ;; 거래 수행 (Plant → VPP)
        conduct-transaction seller self buy-amount get-current-price-per-kwh-hourly
      ]
    ]
  ]
end

to enforce-vpp-ess-limit
  ask vpp-nodes [
    if current-energy > ess-capacity [
      let surplus current-energy - ess-capacity
      set current-energy ess-capacity

      ;; EMS로 초과분 판매
      ask one-of ems-nodes [
        let space ess-storage - current-energy
        let send-amount min (list surplus space)
        conduct-transaction myself self send-amount get-current-price-per-kwh-hourly
      ]
    ]
  ]
end


; 평판 점수 관리
to increase-reputation [node]
  ask node [
    set reputation-score min (list 100 (reputation-score + 1))
  ]
end

to decrease-reputation [node]
  ask node [
    set reputation-score max (list 0 (reputation-score - 2))
  ]
end

to decrease-vpp-reputation [node]
  ask node [
    set reputation-score max (list 0 (reputation-score - 5))
  ]
end

; ESS 초과분 EMS 자동 판매
to enforce-ess-limit
  ; breed != ems-nodes를 먼저 평가하여 EMS 노드가 has-ess?를 평가하지 않도록 한다
  ask turtles with [
    breed != ems-nodes and
    is-boolean? has-ess? and has-ess?
  ] [
    if current-energy > ess-capacity [
      let surplus current-energy - ess-capacity
      set current-energy ess-capacity
      ask one-of ems-nodes [
        let ems-space2 ess-storage - current-energy
        let ems-charge2 min (list surplus ems-space2)
        set current-energy current-energy + ems-charge2
      ]
    ]
  ]
end

; 전력 소비 우선도 적용
to apply-consumption-priority
  ask turtles with [
    breed != ems-nodes and
    breed != plant-nodes and
    is-boolean? has-ess? and
    has-ess?
  ] [
    let need consumption
    ; 1순위: 생산 전력만큼 우선 소비
    let prod-use min (list production need)
    set need need - prod-use

    ; 2순위: ESS 보유 전력의 30%만 추가 소비
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


; 판매 희망 오퍼 생성 (한 틱당 최대 2회)
to create-sell-offers
  ask turtles with [
    breed != ems-nodes and
    breed != plant-nodes and
    is-boolean? has-ess? and
    has-ess?
  ] [
    if current-energy >= ess-capacity * 0.5 [
      let max-sell current-energy * 0.5
      let offer-count 0
      while [offer-count < 2 and max-sell > 0] [
        let sell-amount random-float max-sell
        let buyers (turtle-set (household-nodes with [has-ess?]) company-nodes ems-nodes plant-nodes)
        let buyer one-of buyers with [
          self != myself and
          inbox = [] and
          cooldown-tick = 0
        ]

        if buyer != nobody [
          send-trade-offer self buyer sell-amount get-current-price-per-kwh-hourly
          set offer-count offer-count + 1
        ]
        set max-sell max-sell - sell-amount
      ]
    ]
  ]
end

; 구매 희망 오퍼 생성 (한 틱당 최대 2회)
to create-buy-offers
  ask turtles with [
    (breed = household-nodes or breed = company-nodes)
  ] [
    let need consumption - (production + current-energy)
    let offer-amount need + (ess-capacity * 0.7)
    if offer-amount > 0 [
      let r random-float 1
      let target-agent nobody
      if r < 0.5 [
        if any? plant-nodes with [current-energy >= offer-amount] [
          set target-agent one-of plant-nodes with [current-energy >= offer-amount]
        ]
      ]
      if (r >= 0.5 and r < 0.8) [
        let ess-peers (turtle-set (household-nodes with [has-ess?]) company-nodes)
        with [self != myself and current-energy >= offer-amount and not is-vpp-member?]
        if any? ess-peers [
          set target-agent one-of ess-peers
        ]
      ]
      if (r >= 0.8) [
        if any? ems-nodes with [current-energy >= offer-amount] [
          set target-agent one-of ems-nodes with [current-energy >= offer-amount]
        ]
      ]
      if target-agent != nobody [
        send-trade-offer target-agent self offer-amount get-current-price-per-kwh-hourly
      ]
    ]
  ]
end


; 구매 희망 오퍼 처리 (판매자 기준)
to process-buy-offers
  ask turtles with [
    breed != ems-nodes and
    breed != plant-nodes and
    is-boolean? has-ess? and
    has-ess? and
    not is-vpp-member?
  ] [

    let buy-offers filter [o -> (is-list? o) and (item 2 o = self) and (item 5 o = "PENDING")] inbox
    let sorted-buy-offers sort-by
      [ [a b] ->
        ifelse-value ([reputation-score] of item 1 b) = ([reputation-score] of item 1 a)
        [ (item 6 a) < (item 6 b) ]
        [ ([reputation-score] of item 1 b) > ([reputation-score] of item 1 a) ]
    ] buy-offers
    if not empty? sorted-buy-offers [
      let offer first sorted-buy-offers
      let buyer item 1 offer

      let amount item 3 offer
      if current-energy >= ess-capacity * 0.7 [
        conduct-transaction self buyer amount item 4 offer
        set inbox replace-item (position offer inbox) inbox (replace-item 5 offer "ACCEPTED")
      ]
      foreach but-first sorted-buy-offers [ o ->
        set inbox replace-item (position o inbox) inbox (replace-item 5 o "REJECTED")
      ]
    ]
  ]
end

to process-buy-offers-plant-ems
  ask turtles with [breed = plant-nodes or breed = ems-nodes] [
    let buy-offers filter [o -> (is-list? o) and (item 2 o = self) and (item 5 o = "PENDING")] inbox
    foreach buy-offers [ offer ->
      let buyer item 1 offer
      let amount item 3 offer
      let idx position offer inbox
      ifelse current-energy >= amount [
        conduct-transaction self buyer amount item 4 offer
        if idx != false [
          set inbox (replace-item idx inbox (replace-item 5 offer "ACCEPTED"))
        ]
      ] [
        if idx != false [
          set inbox (replace-item idx inbox (replace-item 5 offer "REJECTED"))
        ]
      ]
    ]
  ]
end

; 판매 희망 오퍼 처리 (구매자 기준)
to process-sell-offers
  ask turtles with [
    breed != ems-nodes and
    breed != plant-nodes and
    is-boolean? has-ess? and
    has-ess? and
    not is-vpp-member?
  ] [

    let sell-offers filter [o -> (is-list? o) and (item 1 o = self) and (item 5 o = "PENDING")] inbox
    let sorted-sell-offers sort-by
      [ [a b] ->
        ([reputation-score] of item 2 b) > ([reputation-score] of item 2 a)
    ] sell-offers
    if not empty? sorted-sell-offers [
      let offer first sorted-sell-offers
      let seller item 2 offer

      let amount item 3 offer
      if current-energy >= ess-capacity * 0.7 [
        conduct-transaction seller self amount item 4 offer
        set inbox replace-item (position offer inbox) inbox (replace-item 5 offer "ACCEPTED")
      ]
      foreach but-first sorted-sell-offers [ o ->
        set inbox replace-item (position o inbox) inbox (replace-item 5 o "REJECTED")
      ]
    ]
  ]
end

; 거래 오퍼 생성
to send-trade-offer [seller buyer amount price]
  let offer (list (word "OFFER-" block-counter)
    buyer
    seller
    amount
    price
    "PENDING"
    block-counter)
  ask seller [ set inbox lput offer inbox ]
  ask buyer [ set outbox lput offer outbox ]
  set block-counter block-counter + 1
  print (word "Offer created: " offer)
end

to update-vpp-energy-status
  ask vpp-nodes [
    ;; 합산용 변수 초기화
    let total-energy 0
    let total-cap 0
    let total-prod 0
    let total-cons 0

    if is-agentset? member-list [   ;;구성원(agentset) 존재 여부 확인
      ask member-list [                 ;;구성원 데이터 합산
        set total-energy total-energy + current-energy
        if has-ess? [
          set total-cap total-cap + ess-capacity
        ]
        set total-prod total-prod + production
        set total-cons total-cons + consumption
      ]
    ]
    ;;합산 결과 VPP에 반영
    set current-energy total-energy
    set ess-capacity total-cap
    set true-production total-prod
    set true-consumption total-cons
  ]
end


; 쿨타임 감소
to update-cooldown
  ask turtles [
    if cooldown-tick > 0 [ set cooldown-tick cooldown-tick - 1 ]
  ]
end


;==========================PPA==============================
to setup-ppa
  ; 1-1) 제안자 선정: company-nodes 중 1개
  set ppa-proposer one-of company-nodes
  ask ppa-proposer [
    set color black
    set label "PPA 제안자"
  ]

  ; 1-2) 수신자 선정: company-nodes 2개 + ESS 보유 가정 2개
  let comp-recv n-of 2 other company-nodes with [self != ppa-proposer]
  let hh-recv  n-of 2 (household-nodes with [has-ess?])
  set ppa-receivers (turtle-set comp-recv hh-recv)
  ask ppa-receivers [
    set color black + 4
    set label "PPA 수신자"
  ]

  ; 1-3) PPA 틱 초기화
  set ppa-tick-count 0
end

; 2. PPA 계약 실행 (매 틱)
to ppa-trade
  if ppa-tick-count >= 20000 [ stop ]  ; 48틱 후 종료

  ask ppa-receivers [
    ; 2-1) 틱당 계약량 = ESS 용량의 최대 50%
    let max-contract ess-capacity * 0.5
    ; 2-2) 수신자 ESS 잔량이 부족하면 발전소에서 충전
    if current-energy < ess-capacity [
      let needed ess-capacity - current-energy
      let from-plant one-of plant-nodes with [current-energy > 0]
      if from-plant != nobody [
        let charge min (list needed ([current-energy] of from-plant))
        ; 발전소 → 수신자 충전
        conduct-transaction from-plant self charge get-current-price-per-kwh-hourly
      ]
    ]
    ; 2-3) 제안자에게 전력 전송 (ESS 잔량 한도 고려)
    let send-amount min (list max-contract current-energy)
    if send-amount > 0 [
      conduct-transaction self ppa-proposer send-amount get-current-price-per-kwh-hourly
      set ppa-received-this-tick ppa-received-this-tick + send-amount
    ]
  ]

  set ppa-tick-count ppa-tick-count + 1
end

;RE100
to-report re100
  ;; (ppa-received-this-tick / 6) × factor 를 소수점 둘째 자리에서 반올림
  report round ((ppa-received-this-tick / 6) * ppa-monitor-factor * 100) / 100
end



; 생산/소비량 및 관련 값 일괄 설정 함수
to set-production-consumption [node base-prod base-cons seasonal-factor]
  let ratio-c (0.9 + random-float 0.2)
  let ratio-p (0.9 + random-float 0.2)
  ask node [
    set monthly-consumption base-cons * ratio-c * seasonal-factor
    set monthly-production base-prod * ratio-p * seasonal-factor
    set daily-consumption monthly-consumption / 30
    set sixhour-consumption monthly-consumption / 120
    set consumption sixhour-consumption
    set daily-production monthly-production / 30
    set sixhour-production monthly-production / 120
    set production sixhour-production
  ]
end

; 소비/생산량 업데이트
to update-energy-values
  ;; 1. 계절 감지 (월 기준)
  let current-month time:get "month" current-datetime
  let summer? member? current-month [6 7 8]  ;; 6~8월: 여름
  let winter? member? current-month [12 1 2] ;; 12~2월: 겨울
  let seasonal-factor 1.0

  if summer? [ set seasonal-factor 1.15 ]  ;; 여름철 15% 증가 (냉방)
  if winter? [ set seasonal-factor 1.10 ]  ;; 겨울철 10% 증가 (난방)

  ;; 2. 가정용 노드
  ;; ESS 보유 노드 - 월별 + 시간대 계수 반영
  ask household-nodes with [has-ess?] [
    let ratio-c (0.9 + random-float 0.2)
    let ratio-p (0.9 + random-float 0.2)

    set monthly-consumption 400 * ratio-c * seasonal-factor
    set monthly-production 250 * ratio-p * seasonal-factor

    set daily-consumption monthly-consumption / 30
    set sixhour-consumption monthly-consumption / 120
    set consumption sixhour-consumption

    let m time:get "month" current-datetime
    let h time:get "hour" current-datetime
    let h6 floor (h / 6)

    ;; 시간대 계수를 곱한 생산량 (MWh → Wh)
    let solar-ratio item h6 item (m - 1) solar-hourly-ratio
    let solar-prod daily-production * solar-ratio

    set production solar-prod

    set true-consumption consumption     ;; 소비량
    set true-production production       ;; 시간대 반영된 생산량
    set true-energy current-energy       ;; ESS 잔여 에너지
  ]


  ;; ESS 미보유 가정용 노드 - 월별 + 시간대 계수 반영
  ask household-nodes with [not has-ess?] [
    let ratio-c (0.9 + random-float 0.2)
    let ratio-p (0.9 + random-float 0.2)

    set monthly-consumption 400 * ratio-c * seasonal-factor
    set monthly-production 25 * ratio-p * seasonal-factor  ;; ESS 미보유는 생산량이 작음

    set daily-consumption monthly-consumption / 30
    set sixhour-consumption monthly-consumption / 120
    set consumption sixhour-consumption

    let m time:get "month" current-datetime
    let h time:get "hour" current-datetime
    let h6 floor (h / 6)

    ;; 태양광 시간대 계수를 곱한 생산량 (MWh → Wh)
    let solar-ratio item h6 item (m - 1) solar-hourly-ratio
    let solar-prod daily-production * solar-ratio

    set production solar-prod

    set true-consumption consumption
    set true-production production
    set true-energy current-energy
  ]


  ;; 사업장 노드 - 월별 + 시간대 계수 반영
  ask company-nodes [
    let ratio-c (0.9 + random-float 0.2)
    let ratio-p (0.9 + random-float 0.2)

    set monthly-consumption 1000 * ratio-c * seasonal-factor
    set monthly-production 150 * ratio-p * seasonal-factor  ;; 회사 노드는 생산량이 중간 정도

    set daily-consumption monthly-consumption / 30
    set sixhour-consumption monthly-consumption / 120
    set consumption sixhour-consumption

    let m time:get "month" current-datetime
    let h time:get "hour" current-datetime
    let h6 floor (h / 6)

    ;; 태양광 시간대 계수를 곱한 생산량 (MWh → Wh)
    let solar-ratio item h6 item (m - 1) solar-hourly-ratio
    let solar-prod daily-production * solar-ratio

    set production solar-prod

    set true-consumption consumption
    set true-production production
    set true-energy current-energy
  ]


  ;; 4. 발전소는 월별 총 200,000kWh 기준으로 태양광:풍력 비율로 생산량 조정
  ;; 발전소 노드의 월별, 시간대별 생산량 계산
  let m time:get "month" current-datetime
  let h time:get "hour" current-datetime
  let time-index floor (h / 6)  ;; 0:0~5시, 1:6~11시, 2:12~17시, 3:18~23시

  ;; 해당 월의 태양광/풍력 총 생산량 (Wh 단위로 변환)
  let solar-monthly item (m - 1) solar-monthly-production * 1000000  ;; MWh → Wh
  let wind-monthly  item (m - 1) wind-monthly-production * 1000000   ;; MWh → Wh

  ;; 해당 월/시간대에 대한 계수 추출
  let solar-coef item time-index item (m - 1) solar-hourly-ratio
  let wind-coef  item time-index item (m - 1) wind-hourly-ratio

  ;; 시간대별 생산량 계산
  let solar-production solar-monthly * solar-coef
  let wind-production  wind-monthly  * wind-coef

  ;; 총 생산량 적용
  ask plant-nodes [
    set production solar-production + wind-production
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

; 메인 실행 루프
to go
  handle-selection
  update-time
  update-energy-values
  update-vpp-energy-status
  enforce-vpp-ess-limit
  update-shared-energy-status
  update-cooldown
  manage-link-ttl

  set tick-peer-trade-count 0
  enforce-ess-limit
  apply-consumption-priority
  let unmet-nodes-count count turtles with [consumption > (production + current-energy)]
  set tick-unmet-nodes-count-list lput unmet-nodes-count tick-unmet-nodes-count-list

  vpp-trade-cycle  ;; 각 tick마다 VPP 거래 사이클 수행

  create-sell-offers
  process-buy-offers
  process-buy-offers-plant-ems

  create-buy-offers
  process-sell-offers

  set ppa-received-this-tick 0
  set ppa-monitor-factor  (0.9 + random-float 0.1)
  ppa-trade          ;; PPA 계약 틱별 실행
  tick

  update-token-delta-per-tick
  update-metrics
  if sync-needed = true [
    synchronize-blockchain
    set sync-needed false
  ]

  ask ems-nodes [ set color blue ]

  ask plant-nodes [ set color orange ]

  ask turtles with [
    (consumption > (production + current-energy)) and
    not ((breed = household-nodes or breed = company-nodes) and is-vpp-member?)
  ] [
    decrease-reputation self
  ]

  ask vpp-nodes [
    if any? member-list with [consumption > (production + current-energy)] [
      decrease-vpp-reputation self
    ]
  ]

  ; 검증자 교체 주기 관리
  set validator-rotation-tick validator-rotation-tick + 1
  if validator-rotation-tick >= 24 [
    assign-validators
    set validator-rotation-tick 0
  ]
  update-ppa-vpp-metrics

  ; 1. 모든 상태별 색상 설정

  ask household-nodes [
    if is-vpp-member? [ set color violet ]
  ]
  ask company-nodes [
    if is-vpp-member? [ set color violet + 2 ]
  ]
  ; 2. 마지막에 검증자만 색상 덮어쓰기
  if any? validators [
    ask validators [ set color green + 2 ]
  ]

  ask ppa-proposer [ set color black ]
  ask ppa-receivers [ set color black + 2 ]
  tick
end

; 시간 업데이트(6시간 단위)
to update-time
  set current-datetime time:plus current-datetime 6 "hours"
end

; 링크 TTL 관리 (시각적 거래 연결)
to manage-link-ttl
  ask links [
    set ttl ttl - 1
    if ttl <= 0 [ die ]
  ]
end

; 성능 지표 계산
to update-metrics
  let total-trades length [blockchain] of one-of ems-nodes
  set economic-efficiency total-trades * energy-price * 0.8
end

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


; 블록 생성 함수
to create-block [tx-list]
  let block-id block-counter
  let timestamp time:show current-datetime "yyyy-MM-dd HH:mm"
  let proposer one-of validators
  let block-string (word block-id timestamp last-block-hash tx-list [real-name] of proposer)
  let block-hash combined-hash block-string
  let block-data (list
    block-id ; ← 숫자 그대로 저장
    timestamp
    last-block-hash
    block-hash
    [real-name] of proposer
    tx-list
  )
  ask ems-nodes [ set blockchain lput block-data blockchain ]
  set last-block-hash block-hash
  set block-counter block-counter + 1
  print (word "Block created: " block-data)
end

; 블록체인 트랜잭션 처리
to conduct-transaction [seller buyer amount price]
  let token-amount amount * price
  if [breed] of buyer = ems-nodes [
    let ess-space ([ess-storage] of buyer) - ([current-energy] of buyer)
    if amount > ess-space [
      print (word "Transaction failed: EMS has insufficient storage space (" amount "kWh 요청, 남은 공간: " ess-space "kWh) ")
      ask seller [
        set cooldown-tick 1
        decrease-reputation self
      ]
      ask buyer [
        set inbox lput (word "Offer failed: EMS has insufficient storage space") inbox
      ]
      stop
    ]
  ]
  ask buyer [
    set token-delta token-delta - token-amount
  ]
  ask seller [
    set token-delta token-delta + token-amount
  ]
  ask seller [ set current-energy current-energy - amount ]
  ask buyer [ set current-energy current-energy + amount ]
  let tx-data (list
    (word "\"seller\": \"" [real-name] of seller "\"")
    (word "\"buyer\": \"" [real-name] of buyer "\"")
    (word "\"amount\": " amount)
    (word "\"price\": " price)
    (word "\"timestamp\": \"" (time:show current-datetime "yyyy-MM-dd HH:mm") "\"")
  )
  add-transaction-to-pending tx-data
  ;; ✅ 거래 내역 기록 - VPP 멤버 노드는 제외, VPP 자체는 기록
  if [breed] of seller = vpp-nodes or not ([breed] of seller = household-nodes and [is-vpp-member?] of seller) [
    ask seller [ set personal-blockchain lput tx-data personal-blockchain ]
  ]

  if [breed] of buyer = vpp-nodes or not ([breed] of buyer = household-nodes and [is-vpp-member?] of buyer) [
    ask buyer [ set personal-blockchain lput tx-data personal-blockchain ]
  ]

  ;; — VPP 수익 및 판매량 갱신
  if [breed] of seller = vpp-nodes [
    ask seller [
      set total-revenue total-revenue + token-amount
      set total-mwh-sold total-mwh-sold + amount
    ]
  ]
  if [breed] of buyer = vpp-nodes [
    ask buyer [
      set total-revenue total-revenue + token-amount
      set total-mwh-sold total-mwh-sold + amount
    ]
  ]

  ;; ✅ 시각적 거래 링크 - VPP 멤버 간은 제외
  if ([breed] of seller != household-nodes or not [is-vpp-member?] of seller) and
  ([breed] of buyer != household-nodes or not [is-vpp-member?] of buyer) [
    ask seller [
      create-link-with buyer [
        set color yellow
        set thickness 0.03 + (amount / 500)
        set label (word precision amount 2 " kWh")
        set hidden? false
        set ttl 3
      ]
    ]
  ]

  ; 평판 증가: VPP 멤버(가정/기업)는 모두 제외
  if not (([breed] of seller = household-nodes or [breed] of seller = company-nodes) and [is-vpp-member?] of seller) [
    ask seller [ increase-reputation self ]
  ]
  if not (([breed] of buyer = household-nodes or [breed] of buyer = company-nodes) and [is-vpp-member?] of buyer) [
    ask buyer [ increase-reputation self ]
  ]

  if ([breed] of seller != ems-nodes and [breed] of seller != plant-nodes and
    [breed] of buyer != ems-nodes and [breed] of buyer != plant-nodes) [
    set tick-peer-trade-count tick-peer-trade-count + 1
  ]
end

; 거래 누적 함수
to add-transaction-to-pending [tx]
  set pending-transactions lput tx pending-transactions
  if length pending-transactions >= block-size [
    process-block pending-transactions
    set pending-transactions []
  ]
end

; 무결성 검증
to-report is-blockchain-valid
  let prev-hash "GENESIS"
  let valid? true
  let blocks [blockchain] of one-of ems-nodes
  foreach blocks [ block ->
    let block-str (word (item 0 block) (item 1 block) (item 2 block) (item 4 block) (item 5 block))
    let hash combined-hash block-str
    if (item 2 block) != (word "\"prev_hash\": \"" prev-hash "\"") [ set valid? false ]
    if (item 3 block) != (word "\"hash\": \"" hash "\"") [ set valid? false ]
    set prev-hash hash
  ]
  report valid?
end

; 검증자 선정
to assign-validators
  let candidates household-nodes with [not is-vpp-member?]
  if count candidates = 0 [
    set validators turtle-set nobody
    print "No nodes available for validator selection"
    stop
  ]
  let sorted-candidates sort-by [[a b] -> ([reputation-score] of b) > ([reputation-score] of a)] candidates
  let validator-count min (list 7 (count candidates) (length sorted-candidates))
  let selected-nodes n-of validator-count sorted-candidates
  ask candidates [ set validator? false ]
  foreach selected-nodes [ node ->
    ask node [
      set validator? true
      set color green + 2
    ]
  ]
  set validators turtle-set selected-nodes
end

; 검증자 중 한 명이 블록을 제안
to propose-block [tx-list]
  let proposer one-of validators
  let block-id block-counter
  let timestamp time:show current-datetime "yyyy-MM-dd HH:mm"
  let block-string (word block-id timestamp last-block-hash tx-list [real-name] of proposer)
  let block-hash combined-hash block-string
  let block-data (list
    (word "\"block_id\": " block-id)
    (word "\"timestamp\": \"" timestamp "\"")
    (word "\"prev_hash\": \"" last-block-hash "\"")
    (word "\"hash\": \"" block-hash "\"")
    (word "\"proposer\": \"" [real-name] of proposer "\"")
    (word "\"txs\": " tx-list)
  )
  set proposed-block block-data
  set block-approvals (list [who] of proposer) ; 제안자는 자동 승인
  print (word "Block proposed by " [real-name] of proposer)
end

; 각 검증자가 제안된 블록을 검증(서명)
to validate-block
  if proposed-block = [] [ stop ]
  ask validators [
    ; 예시: 블록 무결성, 트랜잭션 유효성 등 추가 검증 가능
    if not member? who block-approvals [
      set block-approvals lput who block-approvals
      print (word "Validator " real-name " approved the block.")
    ]
  ]
end

; 합의 도달 시 블록을 체인에 추가
to finalize-block
  if length block-approvals >= consensus-threshold [
    ask ems-nodes [ set blockchain lput proposed-block blockchain ]
    set last-block-hash item 3 proposed-block
    set block-counter block-counter + 1
    print (word "Block finalized and added to chain: " proposed-block)
    set proposed-block []
    set block-approvals []
    set sync-needed true ; 동기화 필요 플래그만 설정
  ]
end

; 블록 생성 전체 프로세스(제안→검증→합의)
to process-block [tx-list]
  propose-block tx-list
  validate-block
  finalize-block
end

; 블록체인 동기화
to synchronize-blockchain
  let master-chain [blockchain] of one-of ems-nodes
  ask turtles [
    set personal-blockchain master-chain
  ]
end

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
  let base-pric item (current-month - 1) monthly-electricity-prices
  let hour time:get "hour" current-datetime
  let factor get-hourly-price-factor hour
  let hourly-price base-pric * factor
  report hourly-price / token-price
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
  let vpp-width 8  ; VPP 멤버 여부 칼럼 폭 추가

  ; 헤더 출력
  output-print (word
    pad-string "ID" id-width
    " | " pad-string "Name" name-width
    " | " pad-string "Energy" energy-width
    " | " pad-string "Reputation" reputation-width
    " | " pad-string "Validator" validator-width
    " | " pad-string "VPP-Member" vpp-width
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
        " | " pad-string is-vpp-member? vpp-width
      )
    ]
  ]
end

; 블록 정보 리포트
to-report block-list-info
  let blocks [blockchain] of one-of ems-nodes
  let info-list []
  foreach blocks [ block ->
    let block-id item 0 block
    let proposer item 4 block
    let txs item 5 block
    let tx-count length txs
    let hash item 3 block
    set info-list lput (list block-id proposer tx-count hash) info-list
  ]
  report info-list
end

; 블록체인 현황
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

to print-block-row [idx block id-width proposer-width tx-width hash-width]
  let proposer item 4 block
  let hash item 3 block
  let tx-count 20 ; 또는 실제 트랜잭션 개수: length item 5 block
  output-print (word
    pad-string idx id-width
    " | " pad-string proposer proposer-width
    " | " pad-string tx-count tx-width
    " | " pad-string hash hash-width
  )
end

to print-blockchain-table
  clear-output
  let id-width 4
  let proposer-width 25
  let tx-width 7
  let hash-width 25

  output-print (word
    pad-string "ID" id-width
    " | " pad-string "Proposer" proposer-width
    " | " pad-string "TxCount" tx-width
    " | " pad-string "Hash" hash-width
  )

  let blocks [blockchain] of one-of ems-nodes
  let n length blocks
  let idx-list n-values n [i -> i]
  ; 인덱스 리스트를 이용해 안전하게 순회
  foreach idx-list [ idx ->
    let block item idx blocks
    print-block-row idx block id-width proposer-width tx-width hash-width
  ]
end

; 선택된 노드 거래 내역 출력
to print-selected-node-trades
  let selected-node one-of turtles with [selected?]
  ifelse selected-node = nobody [
    print "No node selected"
  ] [
    let logs [personal-blockchain] of selected-node
    ifelse length logs = 0 [
      print (word "No transactions for node " [real-name] of selected-node)
    ] [
      print (word "Transaction history for " [real-name] of selected-node ":")
      foreach logs [ block -> print block ]
    ]
  ]
end

; 현재 날짜/시간 리포트
to-report current-date-time
  report time:show current-datetime "yyyy-MM-dd HH:mm"
end

; 거래 성공률
to-report trade-success-rate
  let all-inboxes reduce sentence [inbox] of turtles
  let accepted length filter [o -> (is-list? o) and (item 5 o = "ACCEPTED")] all-inboxes
  let rejected length filter [o -> (is-list? o) and (item 5 o = "REJECTED")] all-inboxes
  let total-offers accepted + rejected
  if total-offers = 0 [ report 0 ]
  report precision (accepted / total-offers) 6
end

; 거래 거절 횟수
to-report rejected-trade-count
  let all-inboxes reduce sentence [inbox] of turtles
  report length filter [o -> (is-list? o) and (item 5 o = "REJECTED")] all-inboxes
end

; 안정성
to-report shortage-count
  report tick-unmet-nodes-count-list
end

; 선택 노드 거래 시도 횟수
to-report selected-inbox-length
  ifelse any? turtles with [selected?]
    [report length [inbox] of one-of turtles with [selected?]]
  [report 0]
end

; 선택 노드 거래 성공 횟수
to-report selected-accepted-count
  ifelse any? turtles with [selected?]
    [report length filter [o -> (is-list? o) and (item 5 o = "ACCEPTED")] [inbox] of one-of turtles with [selected?]]
  [report 0]
end

; 선택 노드 거래 실패 횟수
to-report selected-rejected-count
  ifelse any? turtles with [selected?]
    [report length filter [o -> (is-list? o) and (item 5 o = "REJECTED")] [inbox] of one-of turtles with [selected?]]
  [report 0]
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
    ;; VPP 노드인지 확인 (breed이 vpp-nodes)
    if member? t vpp-nodes [
      report "VPP 노드"
    ]
    ;; VPP 멤버인지 확인 (is-vpp-member? 플래그)
    if [is-vpp-member?] of t [
      report "VPP 멤버"
    ]
    ;; PPA 제안자인지 확인 (ppa-proposer)
    if t = ppa-proposer [
      report "PPA 제안자"
    ]
    ;; PPA 수신자인지 확인 (ppa-receivers agentset)
    if member? t ppa-receivers [
      report "PPA 수신자"
    ]
    ;; 그 외 기존 종류 구분
    if member? t validators [
      report "검증자 노드"
    ]
    if member? t ems-nodes [
      report "EMS 노드"
    ]
    if member? t household-nodes [
      report "가정 노드"
    ]
    if member? t company-nodes [
      report "기업 노드"
    ]
    if member? t plant-nodes [
      report "발전소 노드"
    ]
    report "알 수 없는 노드"
  ]
  report "노드 미선택"
end


to update-ppa-vpp-metrics
  ;; ===== VPP 지표 계산 =====
  ;; 1) vpp-capacity-utilization-rate: 현재 에너지 저장장치(ESS) 보유량 대비 최대 용량 활용률(%)
  ;;    current-energy와 ess-capacity는 vpp-nodes 에이전트가 가지고 있어야 함
  ask vpp-nodes [
    ifelse ess-capacity > 0 [
      set vpp-capacity-utilization-rate
        precision (100 * (current-energy / ess-capacity)) 2
    ] [
      set vpp-capacity-utilization-rate 0
    ]
    ;; 2) vpp-demand-response-success-rate: 수요반응 요청 대비 성공 이행률(%)
    ;;    successful-dispatch-count, demand-response-request-count도 vpp-nodes 소유 가정
    ifelse demand-response-request-count > 0 [
      set vpp-demand-response-success-rate
        precision (100 * (successful-dispatch-count / demand-response-request-count)) 2
    ] [
      set vpp-demand-response-success-rate 0
    ]
    ;; 3) vpp-revenue-per-mwh: 총 수익(total-revenue)을 판매한 전력량(total-mwh-sold)으로 나눈 값
    ifelse total-mwh-sold > 0 [
      set vpp-revenue-per-mwh
        precision (total-revenue / total-mwh-sold) 2
    ] [
      set vpp-revenue-per-mwh 0
    ]
  ]

  ;; ===== PPA 지표 계산 =====
  ;; ppa-received-this-tick: 전역 변수로, 해당 틱에 PPA 수신자 전체가 받은 전력 합(예: kWh)
  ;; ppa-receivers: 리스트 또는 agentset, 각 수신자 에이전트가 ess-capacity 소유
  let total-received ppa-received-this-tick
  ;; 실제 계약량: 각 수신자 ESS 용량의 50%를 계약 용량이라 가정하고 합산
  let total-contract sum [ess-capacity * 0.5] of ppa-receivers

  ;; 1) ppa-energy-delivery-rate: 한 틱 기준 계약 대비 전달률(%)
  ifelse total-contract > 0 [
    set ppa-energy-delivery-rate precision (100 * total-received / total-contract) 2
  ] [
    set ppa-energy-delivery-rate 0
  ]

  ;; 2) ppa-cost-savings-percentage: 기준 가격 대비 절감률(%)
  ;; base-price, actual-price는 전역 변수 또는 리포트 함수로부터 가져옴
  ifelse base-price > 0 [
    set ppa-cost-savings-percentage
      precision (100 * (base-price - actual-price) / base-price) 2
  ] [
    set ppa-cost-savings-percentage 0
  ]

  ;; 3) ppa-received-avg-per-tick: 틱당 평균 수신 전력량
  ifelse ppa-tick-count > 0 [
    set ppa-received-avg-per-tick
      precision (total-received / ppa-tick-count) 2
  ] [
    set ppa-received-avg-per-tick 0
  ]

  let current-month floor (ticks / 120)  ;; ticks-per-month는 한 달을 틱으로 환산한 값
  if current-month < length monthly-electricity-prices [
    set actual-price item current-month monthly-electricity-prices * get-hourly-price-factor(time:get "hour" current-datetime)
  ]
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
실행
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
rejected-trade-count
17
1
11

MONITOR
520
23
587
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
set selection-mode? not selection-mode?\n\n
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
517
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
ifelse-value (ticks = 0)\n  [0]\n  [length reduce sentence [inbox] of turtles]
17
1
11

MONITOR
24
332
120
377
총 성공 거래
length filter [o -> (is-list? o) and (item 5 o = \"ACCEPTED\")] reduce sentence [inbox] of turtles
17
1
11

MONITOR
120
285
216
330
총 미처리 거래
(ifelse-value (ticks = 0)\n  [0]\n  [length reduce sentence [inbox] of turtles]\n)\n-\n(length filter [o -> (is-list? o) and (item 5 o = \"ACCEPTED\")] reduce sentence [inbox] of turtles)\n-\n(length filter [o -> (is-list? o) and (item 5 o = \"REJECTED\")] reduce sentence [inbox] of turtles)
17
1
11

MONITOR
817
108
913
153
거래 시도 횟수
selected-inbox-length
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
"총 거래 시도 횟수" 1.0 0 -13791810 true "" "plot length reduce sentence [inbox] of turtles"
"총 거래 성공 횟수" 1.0 0 -15040220 true "" "plot length filter [o -> (is-list? o) and (item 5 o = \"ACCEPTED\")] reduce sentence [inbox] of turtles"
"총 거래 실패 횟수" 1.0 0 -5298144 true "" "plot length filter [o -> (is-list? o) and (item 5 o = \"REJECTED\")] reduce sentence [inbox] of turtles"
"총 미처리 거래 횟수" 1.0 0 -9276814 true "" "plot length filter [o -> (is-list? o) and (item 5 o = \"PENDING\")] reduce sentence [inbox] of turtles"

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
934
15
1048
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
1052
15
1165
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
155
21
208
39
날짜 설정\n
12
0.0
1

SLIDER
1171
15
1343
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

MONITOR
589
23
698
68
P2P 거래 횟수 (6h)
tick-peer-trade-count
17
1
11

MONITOR
722
258
913
303
에너지 소비량 미충족 노드
count turtles with [consumption > (production + current-energy)]
17
1
11

MONITOR
722
304
913
349
잉여 에너지 보유 노드
count (household-nodes with [current-energy > consumption]) +\ncount (company-nodes with [current-energy > consumption])
17
1
11

MONITOR
223
514
326
559
RE100 달성률(%)
re100
17
1
11

MONITOR
722
403
858
448
VPP 용량 활용률(%)
vpp-capacity-utilization-rate
17
1
11

MONITOR
722
355
858
400
VPP 수익률 (토큰/MWh)
vpp-revenue-per-mwh
17
1
11

MONITOR
328
514
443
559
PPA 계약 이행률(%)
ppa-energy-delivery-rate
17
1
11

MONITOR
593
514
711
559
PPA 비용 절감률(%)
ppa-cost-savings-percentage
17
1
11

MONITOR
444
514
592
559
PPA 평균 수신 전력량(6h)
ppa-received-avg-per-tick
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
