require "gosu"
require "./global"
require "./game_object"

include MiniGL

class MyGame < GameWindow
  def initialize
    Res.retro_images = true
    @sprite = Res.imgs(:Armep, 1, 4)
    @tileset = Res.tileset("1", 16, 16)
    @sound = Res.sound(:bell)
    @font = Res.font(:corbel, 24)
    @obj = GameObject.new(5, 5, 10, 10, :Ball)

    super(800, 600, false, Vector.zero)
    self.caption = "Test"

    Res.song(:credits).play(true)
  end

  def needs_cursor?
    true
  end

  def update
    KB.update
    forces = Vector.zero
    forces.x -= 3 if KB.key_down?(Gosu::KB_LEFT)
    forces.x += 3 if KB.key_down?(Gosu::KB_RIGHT)
    forces.y -= 3 if KB.key_down?(Gosu::KB_UP)
    forces.y += 3 if KB.key_down?(Gosu::KB_DOWN)
    # @obj.move(forces, [] of Movement, [] of Ramp)

    @sound.play if KB.key_pressed?(Gosu::KB_A)
  end

  def draw
    @sprite[0].draw(400, 10, 0, 2, 2)
    @tileset[0].draw(400, 300, 0, 2, 2)
    # @obj.draw

    @font.draw_text("Testing text", 10, 300, 0)
  end
end

MyGame.new.show