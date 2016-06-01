# ふっとび速度(目に見える速度)は内部ふっとび速度と落下速度の和である
# 技を受けた時、ふっとび初速が決定する
# 内部ふっとび速度は、ふっとび初速から毎フレーム内部ふっとび加速度だけ減少する(0未満にはならない)
# 落下速度は、ふっとび初速から毎フレームキャラ別の落下加速度だけ増加する(キャラ別の終端落下速度未満にはならない)
# 鉛直方向の内部ふっとび速度が上バースト速度閾値 STEPOVER_THRESHOLD 以上のときに、上バーストラインを超えると死ぬ
# そのため、軽いキャラ(プリン等)ではふっとびの頂点でバーストラインを超えていても死ぬとは限らない
# プログラム中では鉛直上向きを正とする
INNER_ACCELERATION = -0.051 # ふっとび減衰加速度(おそらく変化しない)
STEPOVER_THRESHOLD = 2.4    # 上バースト速度閾値(おそらく全ステージ・全キャラ共通)
DAMAGE_RATIO       = 1.0    # ハンデ等(?)で変わるダメージ率: 0.0〜1.0
REACTION_RATIO     = 0.03   # ふっとび値 * REACTION_RATIO = ふっとび初速

# FIXME: ステージ・キャラ・技の管理は適当
# ステージ別のバースト位置
stages = [
  { name: 'Final Destination',  upper_bound: 188.0, ground_height: 0.0001 },
  { name: 'Battlefield',        upper_bound: 200.0, ground_height: 0.0001 },
  { name: 'Dream Land'      ,   upper_bound: 250.0, ground_height: 0.0089 },
  { name: 'Fountain of Dreams', upper_bound: 202.5, ground_height: 0.002875 },
  { name: 'Pokemon Stadium',    upper_bound: 180.0, ground_height: 0.0001 },
  { name: 'Yoshi\'s Story',     upper_bound: 168.0, ground_height: 0.0001 }
]

# キャラ別の落下関連値
chars = [
  { name: 'Bowser',      weight: 117, freefall_acceleration: -0.130, terminal_velocity: -1.90 },
  { name: 'C.Falcon',    weight: 104, freefall_acceleration: -0.130, terminal_velocity: -2.90 },
  { name: 'D.K.',        weight: 114, freefall_acceleration: -0.100, terminal_velocity: -2.40 },
  { name: 'Dr.Mario',    weight: 100, freefall_acceleration: -0.095, terminal_velocity: -1.70 },
  { name: 'Falco',       weight:  80, freefall_acceleration: -0.170, terminal_velocity: -3.10 },
  { name: 'Fox',         weight:  75, freefall_acceleration: -0.230, terminal_velocity: -2.80 },
  { name: 'Game&Watch',  weight:  60, freefall_acceleration: -0.095, terminal_velocity: -1.70 },
  { name: 'Ganondorf',   weight: 109, freefall_acceleration: -0.130, terminal_velocity: -2.00 },
  { name: 'IceClimbers', weight:  88, freefall_acceleration: -0.100, terminal_velocity: -1.60 },
  { name: 'JigglyPuff',  weight:  60, freefall_acceleration: -0.064, terminal_velocity: -1.30 },
  { name: 'Kirby',       weight:  70, freefall_acceleration: -0.080, terminal_velocity: -1.60 },
  { name: 'Link',        weight: 104, freefall_acceleration: -0.110, terminal_velocity: -2.13 },
  { name: 'Luigi',       weight: 100, freefall_acceleration: -0.069, terminal_velocity: -1.60 },
  { name: 'Mario',       weight: 100, freefall_acceleration: -0.095, terminal_velocity: -1.70 },
  { name: 'Marth',       weight:  87, freefall_acceleration: -0.085, terminal_velocity: -2.20 },
  { name: 'Mewtwo',      weight:  85, freefall_acceleration: -0.082, terminal_velocity: -1.50 },
  { name: 'Ness',        weight:  94, freefall_acceleration: -0.090, terminal_velocity: -1.83 },
  { name: 'Peach',       weight:  90, freefall_acceleration: -0.080, terminal_velocity: -1.50 },
  { name: 'Pichu',       weight:  55, freefall_acceleration: -0.110, terminal_velocity: -1.90 },
  { name: 'Pikachu',     weight:  80, freefall_acceleration: -0.110, terminal_velocity: -1.90 },
  { name: 'Roy',         weight:  85, freefall_acceleration: -0.114, terminal_velocity: -2.40 },
  { name: 'Samus',       weight: 110, freefall_acceleration: -0.066, terminal_velocity: -1.40 },
  { name: 'Sheik',       weight:  90, freefall_acceleration: -0.120, terminal_velocity: -2.13 },
  { name: 'Yoshi',       weight: 108, freefall_acceleration: -0.093, terminal_velocity: -1.93 },
  { name: 'YoungLink',   weight:  85, freefall_acceleration: -0.110, terminal_velocity: -2.13 },
  { name: 'Zelda',       weight:  90, freefall_acceleration: -0.073, terminal_velocity: -1.40 }
]

# 技情報
moves = [
  { name: 'Fox Up Smash'     , attack_percent: 18, angle_degree:  80, knockback_growth: 112, base_knockback: 30 },
  { name: 'Fox Up Tilt'      , attack_percent: 12, angle_degree: 110, knockback_growth: 140, base_knockback: 18 },
  { name: 'JigglyPuff Down B', attack_percent: 28, angle_degree: 361, knockback_growth: 120, base_knockback: 78 }
]

damageAfterHit = ( damage, smn, attack ) ->
  damage + smn * attack

radianAfterHit = ( angle, rdi ) ->
  angle = 45 if angle == 361 # Sakurai angle と呼ばれるもの
  ( angle + rdi ) * Math.PI / 180.0

# ふっとび初速(R固定値非設定技のみ)
initialVelocity = ( attack, kbg, bkb, weight, damage, smn ) ->
  d = damageAfterHit damage, smn, attack
  # ふっとび力F=R(β+(α/100)(18+(14(2+D)(S+DN))/(100+W)))
  force = ( ( ( 14.0 * d * ( 2.0 + attack ) / ( weight + 100.0 ) ) + 18.0 ) * 0.01 * kbg + bkb ) * DAMAGE_RATIO
  initial_velocity = force * REACTION_RATIO

evaluateDeath = ( stage, enemy, move, damage_percent, rdi_degree, smn_ratio ) ->
  s = stages[ ( e[ "name" ] for e in stages ).indexOf( stage ) ]
  c = chars[ ( e[ "name" ] for e in chars ).indexOf( enemy ) ]
  m = moves[ ( e[ "name" ] for e in moves ).indexOf( move ) ]

  # 横バーストも考えるなら initial_velocity * Cos( angle_radian ) で出す
  initial_velocity = initialVelocity( m[ "attack_percent" ], m[ "knockback_growth" ], m[ "base_knockback" ],
    c[ "weight" ], damage_percent, smn_ratio )
  angle_radian = radianAfterHit rdi_degree, m[ "angle_degree" ]
  initial_velocity_y = initial_velocity * Math.sin angle_radian
  inner_acceleration_y = INNER_ACCELERATION * Math.sin angle_radian

  # 攻撃されるキャラに関して
  freefall_acceleration = c[ "freefall_acceleration" ]
  terminal_velocity = c[ "terminal_velocity" ]

  # 初速不足
  return false if initial_velocity_y < STEPOVER_THRESHOLD

  # 重いキャラ( terminal_velocity > STEPOVER_THRESHOLD )と軽いキャラ( terminal_velocity <= STEPOVER_THRESHOLD )で判定方法を分ける
  # 重いキャラでは内部ふっとび速度が terminal_velocity 以上である最終フレームで上バーストラインを超えているか調べる
  # 軽いキャラでは内部ふっとび速度が STEPOVER_THRESHOLD 以上である最終フレームで上バーストラインを超えているか調べる
  # 重いキャラで頂点において落下速度が終端に達していないパターンは考えない(地面から上バーストラインまで相当近くないとありえないので)
  critical_frame = Math.floor( -( initial_velocity_y - Math.max( STEPOVER_THRESHOLD, -terminal_velocity ) ) / inner_acceleration_y )

  # 内部ふっとび速度から、判定対象のフレームにおける内部位置を求める
  critical_inner_velocity_y = initial_velocity_y + critical_frame * inner_acceleration_y
  critical_inner_position_y = 0.5 * ( initial_velocity_y + inner_acceleration_y + critical_inner_velocity_y ) * critical_frame

  # 落下速度から、判定対象のフレームにおける位置(落下による変位)を求める
  # 終端落下速度に達する前後で計算を分ける必要がある
  frames_before_reaching_terminal_velocity = Math.floor terminal_velocity / freefall_acceleration
  freefall_velocity_y_before_terminal_velocity = freefall_acceleration * ( frames_before_reaching_terminal_velocity )
  freefall_position_y_before_terminal_velocity = 0.5 *
    ( freefall_acceleration + freefall_velocity_y_before_terminal_velocity ) * frames_before_reaching_terminal_velocity
  remaining_frames_to_critical_frame = critical_frame - frames_before_reaching_terminal_velocity
  freefall_position_y_to_critical_frame = terminal_velocity * remaining_frames_to_critical_frame
  critical_freefall_position_y = freefall_position_y_before_terminal_velocity + freefall_position_y_to_critical_frame

  # 判定対象のフレームにおける実際の位置
  critical_position_y = s[ "ground_height" ] + critical_inner_position_y + critical_freefall_position_y

  return if critical_position_y > s[ "upper_bound" ] then true else false

# テスト
stage          = 'Final Destination'
enemy          = 'Falco'
move           = 'Fox Up Smash'
damage_percent = 93.0 # 技を受ける前の%
rdi_degree     = 16.0 # ベクトル変更(度): -18.0〜+18.0
smn_ratio      = 0.9  # ワンパターン相殺率( SMN: Stale-Move Negation ): 0.55〜1.0

death = evaluateDeath( stage, enemy, move, damage_percent, rdi_degree, smn_ratio )
console.log if death then "バースト" else "生存"
