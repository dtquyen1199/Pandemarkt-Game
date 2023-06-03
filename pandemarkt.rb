#!/bin/env ruby
# encoding: ISO-8859-1

require 'rubygems'
require 'gosu'

WIDTH, HEIGHT = 640, 480
CHARACTER_HEIGHT = 100
CHARACTER_SMALLER_WIDTH = 44
CHARACTER_LARGER_WIDTH = 88
TILE_DIMENSION = 50
class ZOrder
  BACKGROUND, PLAYER, ITEM,  UI = *0..3
end

module Tiles
  Floor, BottomShelf, TopShelf = *0..2
end 

class GameMap
  attr_accessor :width, :height, :tile_set, :tiles
end

class Player
  attr_accessor :x, :y, :dir, :vel, :game_map, :collected, :front1, :front2, :back1, :back2, :side1, :side2, :cur_image
end

class NonPlayerCharacter
  attr_accessor :x, :y, :type, :dir, :vel_x, :vel_y, :game_map, :collected, :stand_down,  :front1, :front2, :back1, :back2, :side1, :side2, :cur_image
end

class Item
  attr_accessor :x, :y, :type, :image, :points, :aisle
  def initialize(x,y,type, image, aisle,points)
      @x = x
      @y = y
      @type = type
      @image = image
      @aisle = aisle
      @points = points
  end
end

def read_item(item_file)
  #the attribute aisle, points and x will be used in later modification 
  type = item_file.gets().chomp
  x = item_file.gets().to_i
  image = item_file.gets().chomp
  image = Gosu::Image.new(image)
  aisle = item_file.gets().to_i
  points = item_file.gets().chomp
  item = Item.new(x,250,type,image,aisle,points)
  return item
end 

def read_items(item_file)
  items = Array.new()
  number_of_items = item_file.gets().to_i
  index = 0
  while index < number_of_items
  item = read_item(item_file)
  items << item
  index +=1 
  end	
  return items
end

def read_in_items(file_name)
  item_file = File.new(file_name, "r")
  items  = read_items(item_file)
  item_file.close()
  return items
end 

def setup_item
  items = read_in_items("food_item4.txt")
  def randomize_location()
    1.times do 
      x = rand(0..(@game_map.width-1))
      y = rand(0..(@game_map.height-1))
    if solid?(@game_map, x*50, y*50)
      return x*TILE_DIMENSION+25,y*TILE_DIMENSION+25
    else  redo
    end
  end
  end
  for item in items do
    item.x, item.y = randomize_location()
  end
end

def draw_items()

  for item in @list do
  item.image.draw_rot(item.x, item.y, ZOrder::ITEM, 0, 0.5, 0.5, 1, 1, 0xff_ffffff, mode = :default)
  end
end

def generate_list(items)
  list = []
  index = 0
  while index < 5 
  list <<@items.sample.type
  index +=1
  end
  return list
end

def collect_item(list, player)
  list.reject! do |item|
    if Gosu.distance(player.x, player.y, item.x, item.y) < 1.5*TILE_DIMENSION && button_down?(Gosu::KB_SPACE)
        player.collected << item
      true
    else
      false 
    end
  end
end

def setup_player(player, game_map, x, y)
  player = Player.new()
  player.x, player.y = x, y
  player.dir = :left
  player.game_map = game_map
  player.front1, player.front2, player.back1, player.back2, player.side1, player.side2 = Gosu::Image.load_tiles("artwork/player_tile.png",CHARACTER_LARGER_WIDTH,CHARACTER_HEIGHT)
  player.cur_image = player.front1
  player
end

def draw_player(player)
  if player.dir == :left
    factor = -1.0
  else
    factor = 1.0
  end
  player.cur_image.draw_rot(player.x, player.y, ZOrder::PLAYER, 0, 0.5, 0.75, factor, 1, 0xff_ffffff, mode = :default)
 
end

def would_fit_player(player, offs_x, offs_y)
  #check for game_map collision
  x_padding = CHARACTER_SMALLER_WIDTH/2
  y_padding = CHARACTER_HEIGHT/4
  not solid?(player.game_map, player.x - x_padding + offs_x, player.y + offs_y) and
  not solid?(player.game_map, player.x - x_padding + offs_x, player.y + offs_y + y_padding) and 
  not solid?(player.game_map, player.x + x_padding + offs_x, player.y + offs_y) and
  not solid?(player.game_map, player.x + x_padding + offs_x, player.y + offs_y + y_padding)
end


def update_player(player, move_x, move_y)

  #right
  if move_x > 0
    player.dir = :right 
    player.cur_image = (Gosu.milliseconds / 100 % 2 == 0) ? player.side1 : player.side2
    move_x.times { if would_fit_player(player, 1, 0) then player.x += 1 end }
  end
  #left
  if move_x < 0
    player.dir = :left
    player.cur_image = (Gosu.milliseconds / 100 % 2 == 0) ? player.side1 : player.side2
    (-move_x).times { if would_fit_player(player, -1, 0) then player.x -= 1 end }
  end
  #up
  if move_y <0
    player.dir = :up
    player.cur_image = (Gosu.milliseconds / 100 % 2 == 0) ? player.back1 : player.back2
    (-move_y).times {if would_fit_player(player, 0, -1) then player.y -=1 end}
  end
  #down
  if move_y >0
    player.dir = :down
    player.cur_image = (Gosu.milliseconds / 100 % 2 == 0) ? player.front1 : player.front2
    move_y.times { if would_fit_player(player, 0, 1) then player.y +=1 end} 
  end

  #stealing 
  for npc in @npcs do
    if Gosu.distance(npc.x, npc.y, @player.x, @player.y) <50 && npc.collected.size > 0 && button_down?(Gosu::KB_SPACE)
      @player.collected << npc.collected[0]
      npc.collected.delete_at(0)
    else
      
    end
  end

end

def chase(chasing, chased)
  chasing.dir = nil
  vel_x = (chased.x - chasing.x)/3 
  vel_y = (chased.y - chasing.y)/3
  case
  when would_fit_player(chasing,vel_x,vel_y)
  chasing.vel_x = vel_x 
  chasing.x += chasing.vel_x
  chasing.vel_y = vel_y
  chasing.y += chasing.vel_y
  when would_fit_player(chasing, 0, vel_y)
  chasing.vel_y = vel_y
  chasing.y += chasing.vel_y
  when would_fit_player(chasing, vel_x,0)
  chasing.vel_x = vel_x
  chasing.x += chasing.vel_x
  end 
end

def update_npcs(npcs, move_x, move_y)
  for npc in npcs do 

  if rand <0.01
    npc.dir  = [:right,:down,:up, :left].sample 
  end
  
  if npc.dir == :left && would_fit_player(npc,-15,0)
    npc.vel_x = -15
    npc.vel_y = 0
    npc.x += npc.vel_x
    npc.y += npc.vel_y
  elsif npc.dir == :left &&  would_fit_player(npc,-15,0) == false
    npc.vel_x = npc.vel_y = 0
    npc.dir = [:right,:down,:up].sample 
  end

  if npc.dir == :right && would_fit_player(npc,15,0)
    npc.vel_x = 15
    npc.vel_y = 0
    npc.x += npc.vel_x
    npc.y += npc.vel_y
  elsif npc.dir == :right &&  would_fit_player(npc,15,0) == false
    npc.vel_x = npc.vel_y = 0
    npc.dir = [:left,:down,:up].sample
  end

  if npc.dir == :down && would_fit_player(npc,0,15)
    npc.vel_x = 0
    npc.vel_y = 15
    npc.x += npc.vel_x
    npc.y += npc.vel_y
  elsif npc.dir == :down &&  would_fit_player(npc,0,15) == false
    npc.vel_x = npc.vel_y = 0
    npc.dir = [:left,:right,:up].sample
  end

  if npc.dir == :up && would_fit_player(npc,0,-15)
    npc.vel_x = 0
    npc.vel_y = -15
    npc.x += npc.vel_x
    npc.y += npc.vel_y
  elsif npc.dir == :up && would_fit_player(npc,0,-15) == false
    npc.vel_x = npc.vel_y = 0
    npc.dir = [:left,:right,:down].sample
  end

  #animate
  if npc.vel_x < 0 && ((npc.vel_x).abs > (npc.vel_y).abs) #left
    npc.dir = :left
    npc.cur_image = (Gosu.milliseconds / 200 % 2 == 0) ? npc.side1 : npc.side2
  elsif npc.vel_x > 0 && (npc.vel_x).abs > (npc.vel_y).abs #right
    npc.cur_image = (Gosu.milliseconds / 200 % 2 == 0) ? npc.side1 : npc.side2
    npc.vel_x.times { if would_fit_player(npc, 1, 0) then npc.x += 1 end }
  end
  if npc.vel_y > 0 && (npc.vel_y).abs > (npc.vel_x).abs #down
    npc.cur_image = (Gosu.milliseconds / 200 % 2 == 0) ? npc.front1 : npc.front2
  elsif npc.vel_y < 0 && (npc.vel_y).abs > (npc.vel_x).abs # up 
    npc.cur_image = (Gosu.milliseconds / 200 % 2 == 0) ? npc.back1 : npc.back2
  end 


  #chase and steal - shopper type 1
  if npc.type == 1
  if Gosu.distance(npc.x, npc.y, @player.x, @player.y) < 5*TILE_DIMENSION && @player.collected.length != 0 && npc.collected.length == 0
    chase(npc,@player)
  end
  if Gosu.distance(npc.x, npc.y, @player.x, @player.y) < 1.5*TILE_DIMENSION && @player.collected != nil && npc.collected.size == 0
    if @player.collected.length > 0 
    npc.collected << @player.collected[0]
    @player.collected.delete_at(0)
    end 
  end
  end
  
  #taking from shelves - shopper type 2
  if npc.type == 0
    for item in @list
      if Gosu.distance(npc.x, npc.y, item.x, item.y) < 5*TILE_DIMENSION && npc.collected.size == 0
      chase(npc,item)
      end
    if  Gosu.distance(npc.x, npc.y, item.x, item.y) < 1.5*TILE_DIMENSION
      npc.collected << item
      @list.delete(item)
    end
    end
  end   
  end 

end

def draw_npcs(npc)
  #drawing only a few tiles larger than WIDTH *HEIGHT
  if (((@camera_x-CHARACTER_LARGER_WIDTH)..(@camera_x + WIDTH + CHARACTER_LARGER_WIDTH)) === npc.x) && (((@camera_y-CHARACTER_LARGER_WIDTH)..(@camera_y + HEIGHT + CHARACTER_HEIGHT)) === npc.y)
  if npc.dir == :left
      factor = -1.0
    else
      factor = 1.0
    end
  npc.cur_image.draw_rot(npc.x, npc.y, ZOrder::PLAYER, 0, 0.5, 0.75, factor, 1, 0xff_ffffff, mode = :default)
  end
  if npc.collected.size > 0 
    for item in npc.collected do
      item.image.draw_rot(npc.x, npc.y, ZOrder::ITEM, 0, 0.5, 1, 1, 1, 0xff_ffffff, mode = :default)
    end 
  end
end

def setup_game_map(filename)
  game_map = GameMap.new
  game_map.tile_set = Gosu::Image.load_tiles("artwork/map_tile.png",50, 50, :tileable => true)
  lines = File.readlines(filename).map { |line| line.chomp }
  game_map.height = lines.size
  game_map.width = lines[0].size
  game_map.tiles = Array.new(game_map.width) do |x|
    Array.new(game_map.height) do |y|
      case lines[y][x, 1]
      when '.'
        Tiles::Floor
      when '#'
        Tiles::TopShelf
      when '='
        Tiles::BottomShelf
      else
        nil
      end
    end
  end
  game_map
end

def draw_game_map(game_map)
  game_map.height.times do |y|
    game_map.width.times do |x|
      tile = game_map.tiles[x][y]
      if tile && (((@camera_x/TILE_DIMENSION)..((@camera_x + WIDTH)/TILE_DIMENSION)) === x) && (((@camera_y/TILE_DIMENSION)..((@camera_y + HEIGHT)/TILE_DIMENSION)) === y)
        game_map.tile_set[tile].draw(x * TILE_DIMENSION - 5, y * TILE_DIMENSION - 5, 0)
      end
    end
  end
end

def draw_interface
  @font.draw_text("#{@minutes}:#{@seconds}",550,20, ZOrder::UI, 1,1, color = 0xff_000000, mode = :default) 
  for item in @scoreboard_list do
    index = @scoreboard_list.index(item)
    item.image.draw(index*50,20, ZOrder::UI, 1, 1, color = 0xff_808080, mode = :default)
    for collected_item in @player.collected do
      if collected_item.type == item.type
        item.image.draw(index*50,20, ZOrder::UI)
      end
    end   
  end 
end 

def solid?(game_map, x, y)
  game_map.tiles[x / 50][y / 50] && (game_map.tiles[x / 50][y / 50] != Tiles::Floor)
end

class Pandemarkt < (Example rescue Gosu::Window)
  def initialize
    super WIDTH, HEIGHT
    self.caption = "Pandemarkt"
    @game_map = setup_game_map("game_map2.txt")
    @items = setup_item()
    @player = setup_player(@player, @game_map, 300, 100)
    @npcs = Array.new()
    @player.collected = []
    @list = @items.sample(5)
    @scoreboard_list = @list.sample(5)
    @employee = Gosu::Image.new("artwork/employee_01.png")
    @employee_x = 5*TILE_DIMENSION+TILE_DIMENSION/2
    @employee_y = 23*TILE_DIMENSION+TILE_DIMENSION/2
    @time = 0
    @font = Gosu::Font.new(30)
    @font2 = Gosu::Font.new(15)
    @camera_x = @camera_y = 0
    @complete = false
  end

  def update
    @time = Gosu.milliseconds/1000
    @minutes = sprintf("%02d",@time/60)
    @seconds = sprintf("%02d",@time%60) 
    move_x = 0
    move_y = 0
    move_x -= 5 if Gosu.button_down? Gosu::KB_LEFT
    move_x += 5 if Gosu.button_down? Gosu::KB_RIGHT
    move_y -= 5 if Gosu.button_down? Gosu::KB_UP
    move_y += 5 if Gosu.button_down? Gosu::KB_DOWN
    update_player(@player, move_x, move_y)
    collect_item(@list, @player)
    @camera_x = [[@player.x - WIDTH / 2, 0].max, @game_map.width * 50 - WIDTH].min
    @camera_y = [[@player.y - HEIGHT / 2, 0].max, @game_map.height * 50 - HEIGHT].min

    if rand < 0.005 && @npcs.length < 6
    @npcs.push(generate_npcs)
    end

    remove_npcs

    if rand <0.1 && @npcs.length >0
      update_npcs(@npcs, move_x, move_y)
    end
    if @complete == true #completed mission!
      sleep(5)
      exit
    end
  end

  def draw
    Gosu.draw_rect(0, 0, 640, 480, Gosu::Color.argb(0xff_ffffff), ZOrder::BACKGROUND, mode=:default)
    draw_interface()

     Gosu.translate(-@camera_x, -@camera_y) do
      draw_game_map(@game_map)
      @employee.draw_rot(@employee_x,@employee_y , ZOrder::PLAYER, 0, 0.5, 0.75, 1, 1, 0xff_ffffff, mode = :default)
      @cash_reg = Gosu::Image.new("artwork/cash_reg.png")
      @cash_reg.draw(4*TILE_DIMENSION, 22*TILE_DIMENSION-10, ZOrder::BACKGROUND)
      draw_player(@player)
      draw_items()
      if @npcs.length >0
        @npcs.each {|npc| draw_npcs npc }
      end
      end

    if @player.collected.size == 5 && Gosu.distance(@player.x, @player.y, @employee_x, @employee_y) < TILE_DIMENSION*2
      text = "Mission Complete!"
      @font.draw_text_rel(text, WIDTH/2, HEIGHT/2, ZOrder::UI, 0.5, 0.5, scale_x = 1, scale_y = 1, color = 0xff_000000, mode = :default)
      credit = "Game Design by Thiem Quyen\nGroceries Icons from flaticon.com"
      @font2.draw_text_rel(credit, WIDTH/2, HEIGHT/8, ZOrder::UI, 0.5, 0.5, scale_x = 1, scale_y = 1, color = 0xff_000000, mode = :default)
      @complete = true
    end
  end

  def generate_npcs  
    npc = NonPlayerCharacter.new()
    npc.game_map = @game_map
    npc.vel_x = 0
    npc.vel_y = 0
    npc.x = 150
    npc.y = (@game_map.height-1)*50
    npc.dir = :up
    npc.collected = []

    case rand(0..1)
    when 0
    npc.type = 0
    npc.front1, npc.front2, npc.back1, npc.back2, npc.side1, npc.side2 = Gosu::Image.load_tiles("artwork/npc1_tile.png",CHARACTER_LARGER_WIDTH,CHARACTER_HEIGHT)
    npc.cur_image = npc.back1
    when 1
    npc.type = 1
    npc.front1, npc.front2, npc.back1, npc.back2, npc.side1, npc.side2 = Gosu::Image.load_tiles("artwork/npc2_tile.png",CHARACTER_LARGER_WIDTH,CHARACTER_HEIGHT)
    npc.cur_image = npc.back1
    end
    return npc
  end

  def remove_npcs
    if @npcs!=nil
    @npcs.reject! do |npc| 
      if npc.x >= 50*@game_map.width || npc.y >= 50*@game_map.height || npc.x <0 || npc.y <0
        #replace item that is taken outside of the store
        if npc.collected.size > 0 
        for npc_item in npc.collected do
          for item in @scoreboard_list do
          if item.type == npc_item.type
            @list << item
          end 
        end
        end
       end
        true
      else
        false
      end
    end
  end
  end

  def button_down(id)
    case id
    when Gosu::KB_ESCAPE
      close
    else
      super
    end
  end

end

Pandemarkt.new.show if __FILE__ == $0
