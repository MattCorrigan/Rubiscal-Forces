require 'gosu'
include Gosu

$WIN = false
$LOSE = false
$PAUSE = true
$LEVEL = 1
$LEVELS = { 1 => {"jump_vel" => -9, "pgravity" => 0.2, "bgravity" => 0.08, "start_height" => 200, "end_height" => 300},
			2 => {"jump_vel" => -10, "pgravity" => 0.25, "bgravity" => 0.09, "start_height" => 300, "end_height" => 350},
			3 => {"jump_vel" => -8, "pgravity" => 0.23, "bgravity" => 0.095, "start_height" => 300, "end_height" => 300},
			4 => {"jump_vel" => -5, "pgravity" => 0.1, "bgravity" => 0.5, "start_height" => 100, "end_height" => 350},
			5 => {"jump_vel" => -5, "pgravity" => 0.18, "bgravity" => 0.07, "start_height" => 50, "end_height" => 390}
			}

class Block

	attr_accessor :image
	attr_accessor :x
	attr_accessor :y
	
	attr_accessor :width
	attr_accessor :height
	
	attr_accessor :perm
	attr_accessor :ending
	
	MAX_Y_VEL = 5
	MAX_X_VEL = 7
	@@gravity = 0.1
	X_FRIC = 0.2
	SLOW_CONSTANT = 5

	def initialize(x, y, perm, ending)
		@x = x
		@y = y
		
		@xvelocity = 0
		@yvelocity = 0
		
		@width = 25
		@height = 25
		@image = Gosu::Image.new("images/block.png", :tileable => false)
		@perm = perm
		@ending = ending
	end
	
	def collision(x, y, blocks, window)
	
		p = window.get_player
	
		if y + @height > 600
			@y = 600 - @height
			return true
		end
		
		blocks.each do |block|
			unless block == self
				if intersect_rect(x, y, block.x, block.y)
					return true
				end
			end
		end
		
		if intersect_rect(x, y, p.x, p.y)
			return true
		end
		
		return false
	end
	
	
	def apply_force(x, y, amount, out)
	
		if @perm
			return 0
		end
		
		# if inward and already sucked in, dont do anything
		unless out
			if x > @x && x < @x + @width && y > @y && y < @y + @height
				@xvelocity = 0
				@yvelocity = 0
				return 0
			end
		end
		
		bx = @x + (@width / 2)
		by = @y + (@height / 2)
	
		distance = Math.hypot(bx-x,by-y)
		
		delta_x = x - bx;
        delta_y = y - by;
		
		dir = -1 # automatically set to outward
		unless out
			dir = 1
		end
		
		if distance == 0
			distance = 0.01
		end
		
		if delta_x == 0
			delta_x = 0.01
		end
		
		if delta_y == 0
			delta_y = 0.01
		end
		
		@xvelocity = ((delta_x * amount / distance) / distance) * dir
		@yvelocity = ((delta_y * amount / distance) / distance) * dir
	end
	
	def self.set_gravity(g)
		@@gravity = g
	end
	
	def update(window, blocks, slow)
	
		if slow
			@xvelocity = @xvelocity / SLOW_CONSTANT
		end
		
		#add gravity if not being sucked in
		unless window.button_down?(Gosu::MsRight) && !slow || @perm
			if slow
				@yvelocity += @@gravity + 0.1
			else
				@yvelocity += @@gravity
			end
		end
		
		# keep under y max
		if @yvelocity > MAX_Y_VEL
			@yvelocity = MAX_Y_VEL
		elsif @yvelocity < MAX_Y_VEL * -1
			@yvelocity = MAX_Y_VEL * -1
		end
		
		# keep under x max
		if @xvelocity > MAX_X_VEL
			@xvelocity = MAX_X_VEL
		elsif @xvelocity < MAX_X_VEL * -1
			@xvelocity = MAX_X_VEL * -1
		end
		
		if slow
			@yvelocity = 0.16
		end
		
		# test yvelocity collisions (test for sitting, too)
		sitting = false
		unless collision(@x, @y + @yvelocity, blocks, window)
			@y = @y + @yvelocity
		else
			sitting = true
			@yvelocity = 0
		end
		
		#apply x friction
		if sitting
			if @xvelocity > X_FRIC
				@xvelocity -= X_FRIC
			elsif @xvelocity < -X_FRIC
				@xvelocity += X_FRIC
			else
				@xvelocity = 0
			end
		end
		
		# test xvelocity collisions
		unless collision(@x + @xvelocity, @y, blocks, window)
			@x = @x + @xvelocity
		else
			@xvelocity = 0
		end
	end
	
	def intersect_rect(x1, y1, x2, y2)
		return (x2 <= x1 + 25 && x2 + 25  >= x1 && y2 <= y1 + 25 && y2 + 25 >= y1)
	end

end

class Player

	attr_accessor :x
	attr_accessor :y
	attr_accessor :left
	attr_accessor :right
	attr_accessor :image
	attr_accessor :at_start
	
	attr_accessor :gravity
	attr_accessor :jump_vel

	MAX_X_VEL = 7
	MAX_Y_VEL = 5
	
	X_MOVE = 2
	X_FRIC = 0.2

	def initialize(x, y)
		@x = x
		@y = y
		
		@xvelocity = 0
		@yvelocity = 0
		
		@width = 25
		@height = 25
		@image = Gosu::Image.new("images/player.png", :tileable => false)
		
		@left = false
		@right = false
		
		@can_jump = false
		@at_start = true
		
		@gravity = 0.2
		@jump_vel = -8
	end
	
	def collision(x, y, blocks, window)
		
		if y + @height > 400
			$LOSE = true
		end
		
		blocks.each do |block|
			unless block == self
				if block.intersect_rect(x, y, block.x, block.y)
					unless block.perm
						@at_start = false
					else
						@at_start = true
					end
					if block.ending
						window.add_level()
					end
					return true
				end
			end
		end
		return false
		
	end
	
	def jump()
		if @can_jump
			@yvelocity = @jump_vel
			@can_jump = false
		end
	end
	
	def update(blocks, window)
		@yvelocity += @gravity
		
		if right
			@xvelocity = X_MOVE
		elsif left
			@xvelocity = -X_MOVE
		else
			if @xvelocity > X_FRIC
				@xvelocity -= X_FRIC
			elsif @xvelocity < -X_FRIC
				@xvelocity += X_FRIC
			else
				@xvelocity = 0
			end
		end
		
		# keep under y max
		if @yvelocity > MAX_Y_VEL
			@yvelocity = MAX_Y_VEL
		end
		
		# keep under x max
		if @xvelocity > MAX_X_VEL
			@xvelocity = MAX_X_VEL
		elsif @xvelocity < MAX_X_VEL * -1
			@xvelocity = MAX_X_VEL * -1
		end
		
		unless collision(@x, @y + @yvelocity, blocks, window)
			@y = @y + @yvelocity
		else
			@yvelocity = 0
			@can_jump = true
		end
		
		unless collision(@x, @y + 1, blocks, window)
			@at_start = false
		end
		
		unless collision(@x + @xvelocity, @y, blocks, window)
			@x = @x + @xvelocity
		else
			@xvelocity = 0
		end
		
	end

end

class GameWindow < Gosu::Window

	attr_accessor :blocks

	def initialize()
		super 900, 700, :fullscreen => false
		self.caption = "Rubiscal Forces"
		@cursor = Gosu::Image.new(self, 'images/cursor.png')
		@font = Gosu::Font.new(40)
		@small_font = Gosu::Font.new(40)
		@help = Gosu::Font.new(16)
		@blocks = []
		#start and end
		@blocks.push(Block.new(0, $LEVELS[$LEVEL]["start_height"], true, false))
		@blocks.push(Block.new(25, $LEVELS[$LEVEL]["start_height"], true, false))
		@blocks.push(Block.new(850, $LEVELS[$LEVEL]["end_height"], true, true))
		@blocks.push(Block.new(875, $LEVELS[$LEVEL]["end_height"], true, true))
		#normal blocks
		@blocks.push(Block.new(450, 300, false, false))
		@blocks.push(Block.new(450, 400, false, false))
		@blocks.push(Block.new(500, 250, false, false))
		@blocks.push(Block.new(550, 400, false, false))
		@blocks.push(Block.new(550, 300, false, false))
		@blocks.push(Block.new(200, 300, false, false))
		@blocks.push(Block.new(250, 400, false, false))
		@blocks.push(Block.new(325, 250, false, false))
		@blocks.push(Block.new(600, 400, false, false))
		@blocks.push(Block.new(700, 300, false, false))
		@blocks.push(Block.new(700, 100, false, false))
		@blocks.push(Block.new(500, 100, false, false))
		@blocks.push(Block.new(400, 100, false, false))
		@blocks.push(Block.new(600, 100, false, false))
		@blocks.push(Block.new(300, 100, false, false))
		@player = Player.new(10, 274)
		@player.jump_vel = $LEVELS[$LEVEL]["jump_vel"]
		@player.gravity = $LEVELS[$LEVEL]["pgravity"]
		Block.set_gravity( $LEVELS[$LEVEL]["bgravity"] )
		@blocks[0].y = $LEVELS[$LEVEL]["start_height"]
		@blocks[1].y = $LEVELS[$LEVEL]["start_height"]
		@blocks[2].y = $LEVELS[$LEVEL]["end_height"]
		@blocks[3].y = $LEVELS[$LEVEL]["end_height"]
		@player.x = 10
		@player.y = $LEVELS[$LEVEL]["start_height"] - 26
		
		@explosion = false
		@explosion_count = 0
		
		@slow_mo = false
		@slow_mo_count = 0
	end
	
	def get_player()
		return @player
	end
	
	def add_level()
	
		@slow_mo = false
	
		if $LEVEL == 20
			$WIN = true
		end
	
		$LEVEL += 1
		@player.jump_vel = $LEVELS[$LEVEL]["jump_vel"]
		@player.gravity = $LEVELS[$LEVEL]["pgravity"]
		Block.set_gravity( $LEVELS[$LEVEL]["bgravity"] )
		@blocks[0].y = $LEVELS[$LEVEL]["start_height"]
		@blocks[1].y = $LEVELS[$LEVEL]["start_height"]
		@blocks[2].y = $LEVELS[$LEVEL]["end_height"]
		@blocks[3].y = $LEVELS[$LEVEL]["end_height"]
		@player.x = 10
		@player.y = $LEVELS[$LEVEL]["start_height"] - 26
		if $LEVEL == 3 || $LEVEL == 4 || $LEVEL == 6 || $LEVEL == 7 || $LEVEL == 9 || $LEVEL == 11 || $LEVEL == 14 || $LEVEL == 16 || $LEVEL == 18 || $LEVEL == 19 || $LEVEL == 20
			@blocks.pop
		end
	end
	
	def check_explosion()
		if @explosion
			return 0
		end
		
		unless @player.at_start
			return 0
		end
		
		#check for explosive click
		outward = false
		lclick = button_down?(Gosu::MsLeft)
		rclick = button_down?(Gosu::MsRight)
		
		if lclick
			outward = true
		end
		
		if lclick | rclick
			mx = mouse_x
			my = mouse_y
			@explosion = true
			@blocks.each do |block|
				block.apply_force(mx, my, 900, outward)
			end
		end
	end

	def update
		if $WIN || $PAUSE || $LOSE
			return 0
		end
	
		if @slow_mo
			@explosion = true
		else
			@explosion = false
		end
	
		check_explosion()
		
		#update blocks
		@blocks.each do |block|
			block.update(self, @blocks, @slow_mo)
		end
		
		# update player
		@player.update(@blocks, self)
	end

	def draw
		@blocks.each do |block|
			block.image.draw(block.x, block.y, 0)
		end
		@player.image.draw(@player.x, @player.y, 0)
		draw_line(0, 400, Color::RED, 900, 400, Color::RED, z=0, mode=:default)
		if $WIN
			@font.draw("You Won!", 370, 300, 1, 1.0, 1.0, 0xff_ffff00)
		end
		if $LOSE
			@font.draw("You Lose...", 350, 300, 1, 1.0, 1.0, 0xff_ffff00)
			@small_font.draw("Press 'c' To Close", 300, 350, 1, 1.0, 1.0, 0xff_ffff00)
		end
		if $PAUSE
			@help.draw("Controls: a - left, d - right, spacebar - jump, left click - explode blocks, right click - suck blocks.", 3, 20, 1, 1.0, 1.0, 0xff_ffff00)
			@help.draw("Press 's' to slow down time. The blocks will slow, but you will not.", 3, 40, 1, 1.0, 1.0, 0xff_ffff00)
			@help.draw("You are the red block. Your goal is to get from the platform on the left to the platform on the right. Do not drop below the red line.", 3, 60, 1, 1.0, 1.0, 0xff_ffff00)
			@help.draw("Press spacebar to continue.", 3, 80, 1, 1.0, 1.0, 0xff_ffffff)
		end
		@help.draw("Level #{$LEVEL}", 3, 3, 1, 1.0, 1.0, 0xff_ff0000)
		@cursor.draw self.mouse_x, self.mouse_y, 0
	end
  
	def button_down(id)
		if id == Gosu::KbEscape
			close
		elsif id == Gosu::KbS
			@slow_mo = !@slow_mo
		elsif id == Gosu::KbA
			@player.left = true
		elsif id == Gosu::KbD
			@player.right = true
		elsif id == Gosu::KbSpace
			if $PAUSE
				$PAUSE = false
			else
				@player.jump
			end
		elsif id == Gosu::KbC
			self.close
		end
	end
	
	def button_up(id)
		if id == Gosu::KbA
			@player.left = false
		elsif id == Gosu::KbD
			@player.right = false
		end
	end
end

window = GameWindow.new()
window.show