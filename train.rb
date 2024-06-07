# coding: utf-8
=begin

%% 

概要：汽車がグルグル走っているので、
適当に走ってくる車が衝突しないようにしてあげましょう。

操作方法：スペースキーで汽車・車がスタート
[ｍ]キーで車のスタート、ストップ

工夫した点、アピールしたい点：汽車のデザインと標識たちが好き
最初車のスピードを一定にしていたのですが、
いつも汽車にぶつからないタイミングでやってきてしまってつまらなかったので
ランダムになるよう工夫しました。

改良したい点：はじめは踏切を作って、それの開閉を操作するようにするつもりでした。
ですが、踏切にぶつかるような位置に車がいたらどうするか、
また踏切が閉まってからも車は走って行き、
その手前で止まるようにしなければいけないなど考えることが多くて断念したので
そこまでできるとよかったです。
あと車と汽車が接触した時止まるとか、車体の色が変わるとか
何か反応をさせたかったのですが
接触したかの判定が難しそうだったのでやめてしまいました。

%% 

=end

require 'opengl'
require 'glu'
require 'glut'
require 'cg/camera'
require 'cg/bitmapfont'
require 'cg/mglutils'

WSIZE  = 800 # ウインドウサイズ


INIT_THETA =  0.0  # カメラの初期位置
INIT_PHI   =  -30.0  # カメラの初期位置
INIT_DIST  =  6.0  # カメラの原点からの距離の初期値
L_INIT_PHI = 45.0  # 光源の初期位置
L_INIT_PSI = 45.0  # 光源の初期位置
DZ = 0.125         # カメラの原点からの距離変更の単位
DT = 3             # 回転角単位

GROUND_SIZE= 6  # 地面の広さ
SLICES=32
STACKS=32
RINGS=8
WIDTH=0.3       #道の幅
L_RADIUS=1.3    #線路内周
SIZE=WIDTH-0.05 #車体のサイズ
WHEEL=0.08      #車輪の大きさ
CHIMNEY=0.08    #煙突の大きさ
BAR=0.03        #標識の棒
STOP_WIDTH=0.03    #停止線の幅
TRAIN_SPEED=1.5   #汽車の速さ
CAR_SPEED=0.04  #車の速さ

# 状態変数
__camera = Camera.new(INIT_THETA,INIT_PHI,INIT_DIST)
__anim_on = false
__car = GROUND_SIZE  #車の初期位置
__stop = false       #車が動くか
__train = 0          #汽車の初期位置
__start = 50

#マテリアル
GROUND_MATERIAL = [[0.0,0.3,0.5],[0.1,0.5,0.1],[0.0,0.5,0.0],32.0]
LINE1_MATERIAL = [[0.5,0.4,0.3],[0.8,0.8,0.8],[0.1,0.1,0.1],64.0]
TRACK_MATERIAL = [[0.9,0.8,0.7],[0.8,0.8,0.8],[0.1,0.1,0.1],64.0]
LINE2_MATERIAL = [[0.7,0.7,0.7],[0.8,0.8,0.8],[0.1,0.1,0.1],64.0]
TRAIN_MATERIAL = [[1.0,0.0,0.0],[0.5,0.5,0.5],[0.1,0.1,0.1],64.0]
WHEEL_MATERIAL = [[0,0,0],[0,0,0],[0.1,0.1,0.1],64.0]
CAR_MATERIAL = [[0.0,0.0,1.0],[0.5,0.5,0.5],[0.1,0.1,0.1],64.0]
SIGNS_MATERIAL = [[1,1,1],[1,1,1],[0.1,0.1,0.1],64.0]
# GLU二次曲面オブジェクトの生成と設定
__quad = GLU.NewQuadric()
GLU.QuadricDrawStyle(__quad,GLU::FILL)
GLU.QuadricNormals(__quad,GLU::SMOOTH)

# Materialの項目定義
MATERIAL_ITEMS=[
  GL::AMBIENT,
  GL::DIFFUSE,
  GL::SPECULAR,
  GL::SHININESS
]

def set_material(material)
  # 材質の設定
  MATERIAL_ITEMS.each_with_index do |item,i|
    GL.Material(GL::FRONT,item,material[i]) if material[i]
  end
end

## 地面の定義

def ground
  # マテリアル
 set_material(GROUND_MATERIAL)
  ## y = 0が上面になるように位置調整する．
  GL.PushMatrix()
  GL.Translate(0.0,-0.1*GROUND_SIZE,0.0)
  GL.Scale(1.0,0.1,1.0)
  GLUT.SolidCube(2.0*GROUND_SIZE)
  GL.PopMatrix()
end

## 線路
def line1(quad)
  GL.PushMatrix()
  set_material(LINE1_MATERIAL)
  GL.Translate(0,0.01,0)
  GL.Rotate(90,1,0,0)
  GLU.Disk(quad,L_RADIUS,L_RADIUS+WIDTH,SLICES,RINGS)
  set_material(TRACK_MATERIAL)  # 轍
  GL.Translate(0,0,-0.01)
  GLU.Disk(quad,L_RADIUS+0.03,L_RADIUS+0.05,SLICES,RINGS)
  GLU.Disk(quad,L_RADIUS+WIDTH-0.05,L_RADIUS+WIDTH-0.03,SLICES,RINGS)
  GL.PopMatrix()
end

## 道路
def line2()
  GL.PushMatrix()
  set_material(LINE2_MATERIAL)
  GL.Translate(0,0.02,0)
  GL.Rotate(90,1,0,0)
  GL.Begin(GL::QUADS)
  GL.Vertex(-GROUND_SIZE,WIDTH/2)
  GL.Vertex(-GROUND_SIZE,-WIDTH/2)
  GL.Vertex(GROUND_SIZE,-WIDTH/2)
  GL.Vertex(GROUND_SIZE,WIDTH/2)
  GL.End()
  GL.PopMatrix()
end

## 汽車
def train(quad)
  GL.PushMatrix()
  set_material(TRAIN_MATERIAL)
  GL.Translate(0.0,0.1+WHEEL,0.0)
  GL.Scale(2.0,1.0,1.0)
  GLUT.SolidCube(SIZE)
  GL.PopMatrix()

  GL.PushMatrix()  # 後部
  GL.Translate(-WIDTH/2+0.027,WIDTH,0)
  GLUT.SolidCube(SIZE)
  GL.PopMatrix()

  GL.PushMatrix()  # 車輪
  set_material(WHEEL_MATERIAL)
  GL.Translate(-SIZE+0.1,WHEEL,-SIZE/2-0.01)
  GLU.Disk(quad,0,WHEEL,SLICES,RINGS)
  GL.Translate(2.0*(SIZE-0.1),0.0,0.0)
  GLU.Disk(quad,0,WHEEL,SLICES,RINGS)
  GL.Translate(0.0,0,2*(SIZE/2+0.01)+0.01)
  GLU.Disk(quad,0,WHEEL,SLICES,RINGS)
  GL.Translate(-2.0*(SIZE-0.1),0.0,0.0)
  GLU.Disk(quad,0,WHEEL,SLICES,RINGS)
  GL.PopMatrix()

  GL.PushMatrix()  # 煙突
  GL.Translate(WIDTH/2,WIDTH,0)
  GL.Rotate(-90,1,0,0)
  GLU.Cylinder(quad,CHIMNEY,CHIMNEY,CHIMNEY*2,SLICES,STACKS)
  GL.PopMatrix()
end

## 車
def car(quad)
  GL.PushMatrix()
  set_material(CAR_MATERIAL)
  GL.Translate(0,0.1+WHEEL,0)
  GL.Scale(2.0,1.0,1.0)
  GLUT.SolidCube(SIZE)
  GL.PopMatrix()

  GL.PushMatrix()  # 上部
  GL.Translate(0,WIDTH,0)
  GL.Scale(1.2,1.0,1.0)
  GLUT.SolidCube(SIZE)
  GL.PopMatrix()

  GL.PushMatrix()  # 車輪
  set_material(WHEEL_MATERIAL)
  GL.Translate(-SIZE+0.1,WHEEL,-SIZE/2-0.01)
  GLU.Disk(quad,0,WHEEL,SLICES,RINGS)
  GL.Translate(2*(SIZE-0.1),0,0)
  GLU.Disk(quad,0,WHEEL,SLICES,RINGS)
  GL.Translate(0,0,2*(SIZE/2+0.01)+0.01)
  GLU.Disk(quad,0,WHEEL,SLICES,RINGS)
  GL.Translate(-2*(SIZE-0.1),0,0)
  GLU.Disk(quad,0,WHEEL,SLICES,RINGS)
  GL.PopMatrix()
end

## 標識と停止線
def signs(quad)
  GL.PushMatrix()  # 棒
  set_material(SIGNS_MATERIAL)
  GL.Translate(WIDTH*6,0.5,0.4)
  GL.Rotate(90,1,0,0)
  GLU.Cylinder(quad,BAR,BAR,BAR*20,SLICES,STACKS)

  set_material(TRAIN_MATERIAL)  # 三角のとこ
  GL.Rotate(-90,1,0,0)
  GL.Translate(BAR/2,-0.1,0)
  GL.Begin(GL::TRIANGLES)
  GL.Vertex(BAR/2,0,0)
  GL.Vertex(BAR/2,BAR+0.35,-0.2)
  GL.Vertex(BAR/2,BAR+0.35,0.2)
  GL.End()
  GL.PopMatrix()

  GL.PushMatrix()   # 停止線
  set_material(SIGNS_MATERIAL)
  GL.Begin(GL::QUADS)
  GL.Vertex(WIDTH*6,0.03,-WIDTH/2)
  GL.Vertex(WIDTH*6+STOP_WIDTH,0.03,-WIDTH/2)
  GL.Vertex(WIDTH*6+STOP_WIDTH,0.03,WIDTH/2)
  GL.Vertex(WIDTH*6,0.03,WIDTH/2)
  GL.End()
  GL.PopMatrix()
end

#### 描画コールバック ####
display = Proc.new {
  GL.Clear(GL::COLOR_BUFFER_BIT|GL::DEPTH_BUFFER_BIT)
  # 光源の配置(平行光線)
  GL.Light(GL::LIGHT0,GL::POSITION,[1,1,1,0.0])
  ground()          #地面
  line1(__quad)     #線路
  line2()           #道路
  signs(__quad)     #標識と停止線

  GL.PushMatrix()   #車
  GL.Translate(__car,0,0)
  car(__quad)
  GL.PopMatrix()

  GL.PushMatrix()   #汽車
  GL.Rotate(__train,0,1,0)
  GL.Translate(1.43,0,0)
  GL.Rotate(90,0,1,0)
  train(__quad)
  GL.PopMatrix()

  GLUT.SwapBuffers()
}

#### アイドルコールバック ####
## 両方動いてる時
idle = Proc.new {
 if  rand(100) < 50   #いつも同じタイミングで車が来るとつまらないのでランダムに
  __train = __train+TRAIN_SPEED
  __car = __car-CAR_SPEED
  if __car < -GROUND_SIZE       #車が通り過ぎたら初期位置に戻ってきてもらう
    __car = GROUND_SIZE
  end
 else
   __train=__train+TRAIN_SPEED
 end
  GLUT.PostRedisplay()

}
## 車が止まってる時
idle_stop = Proc.new {
  __train = __train+TRAIN_SPEED
  GLUT.PostRedisplay()
}

#### キーボード入力コールバック ####
keyboard = Proc.new { |key,x,y|
  case key
       # [SPACE]: アニメーション開始/停止
  when ' '
    if __anim_on
      __anim_on = false
      GLUT.IdleFunc(nil)
    else
      __anim_on = true
      GLUT.IdleFunc(idle)
    end
    # 車を止める
  when 'm'
    if __stop
      GLUT.IdleFunc(idle)
       __stop = false
    else
      GLUT.IdleFunc(nil)
      GLUT.IdleFunc(idle_stop)
      __stop = true
    end
  # [j],[J]: 経度の正方向/逆方向にカメラを移動する
  when 'j','J'
    __camera.move((key == 'j') ? DT : -DT,0,0)
  # [k],[K]: 緯度の正方向/逆方向にカメラを移動する
  when 'k','K'
    __camera.move(0,(key == 'k') ? DT : -DT,0)
  # [l],[L]:
  when 'l','L'
    __camera.move(0,0,(key == 'l') ? DT : -DT)
  # [z],[Z]: zoom in/out
  when 'z','Z'
    __camera.zoom((key == 'z') ? DZ : -DZ)
  # [r]: 初期状態に戻す
  when 'r'
    __camera.reset
  # [q],[ESC]: 終了する
  when 'q', "\x1b"
    exit 0
  end

  GLUT.PostRedisplay()
}

#### ウインドウサイズ変更コールバック ####
reshape = Proc.new { |w,h|
  GL.Viewport(0,0,w,h)
  __camera.projection(w,h)
  GLUT.PostRedisplay()
}

# シェーディングの設定
def init_shading
  # 光源の環境光，拡散，鏡面成分の設定
  GL.Light(GL::LIGHT0,GL::AMBIENT, [0.4,0.4,0.4])
  GL.Light(GL::LIGHT0,GL::DIFFUSE, [1.0,1.0,1.0])
  GL.Light(GL::LIGHT0,GL::SPECULAR,[1.0,1.0,1.0])

  # シェーディング処理ON,光源(No.0)ON
  GL.Enable(GL::LIGHTING)
  GL.Enable(GL::LIGHT0)
end


##############################################
# main
##############################################
GLUT.Init()
GLUT.InitDisplayMode(GLUT::RGB|GLUT::DOUBLE|GLUT::DEPTH)
GLUT.InitWindowSize(WSIZE,WSIZE)
GLUT.CreateWindow('3D CG') 
GLUT.DisplayFunc(display)
GLUT.KeyboardFunc(keyboard)
GLUT.ReshapeFunc(reshape)
GL.Enable(GL::DEPTH_TEST)
init_shading()  
__camera.set   
GL.ClearColor(0.4,0.4,1.0,1.0)
GLUT.MainLoop()

