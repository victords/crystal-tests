require "./global"

module MiniGL
  # Represents an object with a rectangular bounding box and the +passable+
  # property. It is the simplest structure that can be passed as an element of
  # the +obst+ array parameter of the +move+ method.
  class Block
    # The x-coordinate of the top left corner of the bounding box.
    getter x : (Int32 | Float32)

    # The y-coordinate of the top left corner of the bounding box.
    getter y : (Int32 | Float32)

    # The width of the bounding box.
    getter w : (Int32 | Float32)

    # The height of the bounding box.
    getter h : (Int32 | Float32)

    # Whether a moving object can pass through this block when coming from
    # below. This is a common feature of platforms in platform games.
    getter passable : Bool

    # Creates a new block.
    #
    # Parameters:
    # [x] The x-coordinate of the top left corner of the bounding box.
    # [y] The y-coordinate of the top left corner of the bounding box.
    # [w] The width of the bounding box.
    # [h] The height of the bounding box.
    # [passable] Whether a moving object can pass through this block when
    # coming from below. This is a common feature of platforms in platform
    # games. Default is +false+.
    def initialize(x, y, w, h, passable = false)
      @x = x; @y = y; @w = w; @h = h
      @passable = passable
    end

    # Returns the bounding box of this block as a Rectangle.
    def bounds
      Rectangle.new @x, @y, @w, @h
    end
  end

  # Represents a ramp, i.e., an inclined structure which allows walking over
  # it while automatically going up or down. It can be imagined as a right
  # triangle, with a side parallel to the x axis and another one parallel to
  # the y axis. You must provide instances of this class (or derived classes)
  # to the +ramps+ array parameter of the +move+ method.
  class Ramp
    # The x-coordinate of the top left corner of a rectangle that completely
    # (and precisely) encloses the ramp (thought of as a right triangle).
    getter x : (Int32 | Float32)

    # The y-coordinate of the top left corner of the rectangle described in
    # the +x+ attribute.
    getter y : (Int32 | Float32)

    # The width of the ramp.
    getter w : (Int32 | Float32)

    # The height of the ramp.
    getter h : (Int32 | Float32)

    # Whether the height of the ramp increases from left to right (decreases
    # from left to right when +false+).
    getter left : Bool

    getter ratio : Float32
    getter factor : Float32

    @can_collide = false

    # Creates a new ramp.
    #
    # Parameters:
    # [x] The x-coordinate of the top left corner of a rectangle that
    #     completely (and precisely) encloses the ramp (thought of as a right
    #     triangle).
    # [y] The y-coordinate of the top left corner of the rectangle described
    #     above.
    # [w] The width of the ramp (which corresponds to the width of the
    #     rectangle described above).
    # [h] The height of the ramp (which corresponds to the height of the
    #     rectangle described above, and to the difference between the lowest
    #     point of the ramp, where it usually meets the floor, and the
    #     highest).
    # [left] Whether the height of the ramp increases from left to right. Use
    #        +false+ for a ramp that goes down from left to right.
    def initialize(x, y, w, h, left)
      @x = x
      @y = y
      @w = w
      @h = h
      @left = left
      @ratio = @h.to_f / @w
      @factor = @w / Math.sqrt(@w**2 + @h**2)
    end

    # Checks if an object is in contact with this ramp (standing over it).
    #
    # Parameters:
    # [obj] The object to check contact with. It must have the +x+, +y+, +w+
    #       and +h+ accessible attributes determining its bounding box.
    def contact?(obj)
      obj.x + obj.w > @x && obj.x < @x + @w && obj.x.round(6) == get_x(obj).round(6) && obj.y.round(6) == get_y(obj).round(6)
    end

    # Checks if an object is intersecting this ramp (inside the corresponding
    # right triangle and at the floor level or above).
    #
    # Parameters:
    # [obj] The object to check intersection with. It must have the +x+, +y+,
    #       +w+ and +h+ accessible attributes determining its bounding box.
    def intersect?(obj)
      obj.x + obj.w > @x && obj.x < @x + @w && obj.y > get_y(obj) && obj.y < @y + @h
    end

    # :nodoc:
    def check_can_collide(m)
      y = get_y(m) + m.h
      @can_collide = m.x + m.w > @x && @x + @w > m.x && m.y < y && m.y + m.h > y
    end

    def check_intersection(obj)
      if @can_collide && intersect? obj
        counter = @left && obj.prev_speed.x > 0 || !@left && obj.prev_speed.x < 0
        if obj.prev_speed.y > 0 && counter
          dx = get_x(obj) - obj.x
          s = (obj.prev_speed.y.to_f / obj.prev_speed.x).abs
          dx /= s + @ratio
          obj.x += dx.to_f32
        end
        obj.y = get_y(obj)
        if counter && obj.bottom != self
          obj.speed.x *= @factor
        end
        obj.speed.y = 0
      end
    end

    def get_x(obj)
      return obj.x if @left && obj.x + obj.w > @x + @w
      return (@x + (1.0 * (@y + @h - obj.y - obj.h) * @w / @h) - obj.w).to_f32 if @left
      return obj.x if obj.x < @x
      (@x + (1.0 * (obj.y + obj.h - @y) * @w / @h)).to_f32
    end

    def get_y(obj)
      return @y - obj.h if @left && obj.x + obj.w > @x + @w
      return (@y + (1.0 * (@x + @w - obj.x - obj.w) * @h / @w) - obj.h).to_f32 if @left
      return @y - obj.h if obj.x < @x
      (@y + (1.0 * (obj.x - @x) * @h / @w) - obj.h).to_f32
    end
  end

  # This module provides objects with physical properties and methods for
  # moving. It allows moving with or without collision checking (based on
  # rectangular bounding boxes), including a method to behave as an elevator,
  # affecting other objects' positions as it moves.
  module Movement
    # The mass of the object, in arbitrary units. The default value for
    # GameObject instances, for example, is 1. The larger the mass (i.e., the
    # heavier the object), the more intense the forces applied to the object
    # have to be in order to move it.
    getter mass : (Int32 | Float32)

    @speed = Vector.zero
    # A Vector with the current speed of the object (x: horizontal component,
    # y: vertical component).
    getter speed

    # A Vector with the speed limits for the object (x: horizontal component,
    # y: vertical component).
    getter max_speed : Vector

    # Width of the bounding box.
    getter w : (Int32 | Float32)

    # Height of the bounding box.
    getter h : (Int32 | Float32)

    # The object that is making contact with this from above. If there's no
    # contact, returns +nil+.
    getter top : (Movement | Block | Ramp)?

    # The object that is making contact with this from below. If there's no
    # contact, returns +nil+.
    getter bottom : (Movement | Block | Ramp)?

    # The object that is making contact with this from the left. If there's no
    # contact, returns +nil+.
    getter left : (Movement | Block | Ramp)?

    # The object that is making contact with this from the right. If there's
    # no contact, returns +nil+.
    getter right : (Movement | Block | Ramp)?

    # The x-coordinate of the top left corner of the bounding box.
    property x : (Int32 | Float32)

    # The y-coordinate of the top left corner of the bounding box.
    property y : (Int32 | Float32)

    # Whether a moving object can pass through this block when coming from
    # below. This is a common feature of platforms in platform games.
    property passable : Bool

    @stored_forces = Vector.zero
    # A Vector with the horizontal and vertical components of a force that
    # be applied in the next time +move+ is called.
    property stored_forces

    @prev_speed = Vector.zero
    # A Vector containing the speed of the object in the previous frame.
    getter prev_speed

    # Returns the bounding box as a Rectangle.
    def bounds
      Rectangle.new @x, @y, @w, @h
    end

    # Moves this object, based on the forces being applied to it, and
    # performing collision checking.
    #
    # Parameters:
    # [forces] A Vector where x is the horizontal component of the resulting
    #          force and y is the vertical component.
    # [obst] An array of obstacles to be considered in the collision checking.
    #        Obstacles must be instances of Block (or derived classes), or
    #        objects that <code>include Movement</code>.
    # [ramps] An array of ramps to be considered in the collision checking.
    #         Ramps must be instances of Ramp (or derived classes).
    # [set_speed] Set this flag to +true+ to cause the +forces+ vector to be
    #             treated as a speed vector, i.e., the object's speed will be
    #             directly set to the given values. The force of gravity will
    #             also be ignored in this case.
    def move(forces : Vector, obst, ramps, set_speed = false)
      if set_speed
        @speed.x = forces.x
        @speed.y = forces.y
      else
        forces.x += G.gravity.x; forces.y += G.gravity.y
        forces.x += @stored_forces.x; forces.y += @stored_forces.y
        @stored_forces.x = @stored_forces.y = 0

        forces.x = 0 if (forces.x < 0 && @left) || (forces.x > 0 && @right)
        forces.y = 0 if (forces.y < 0 && @top) || (forces.y > 0 && @bottom)

        if (bottom = @bottom).is_a? Ramp
          if bottom.ratio > G.ramp_slip_threshold
            forces.x += (bottom.left ? -1 : 1) * (bottom.ratio - G.ramp_slip_threshold) * G.ramp_slip_force / G.ramp_slip_threshold
          elsif forces.x > 0 && bottom.left || forces.x < 0 && !bottom.left
            forces.x *= bottom.factor
          end
        end

        @speed.x += (forces.x / @mass).to_f32; @speed.y += (forces.y / @mass).to_f32
      end

      @speed.x = 0 if @speed.x.abs < G.min_speed.x
      @speed.y = 0 if @speed.y.abs < G.min_speed.y
      @speed.x = (@speed.x <=> 0).not_nil! * @max_speed.x if @speed.x.abs > @max_speed.x
      @speed.y = (@speed.y <=> 0).not_nil! * @max_speed.y if @speed.y.abs > @max_speed.y
      @prev_speed = @speed.clone

      x = @speed.x < 0 ? @x + @speed.x : @x
      y = @speed.y < 0 ? @y + @speed.y : @y
      w = @w + (@speed.x < 0 ? -@speed.x : @speed.x)
      h = @h + (@speed.y < 0 ? -@speed.y : @speed.y)
      move_bounds = Rectangle.new x, y, w, h
      coll_list = [] of (Movement | Block)
      obst.each do |o|
        coll_list << o if o != self && move_bounds.intersect?(o.bounds)
      end
      ramps.each do |r|
        r.check_can_collide move_bounds
      end

      if coll_list.size > 0
        up = @speed.y < 0; rt = @speed.x > 0; dn = @speed.y > 0; lf = @speed.x < 0
        if @speed.x == 0 || @speed.y == 0
          # Ortogonal
          if rt
            x_lim = find_right_limit coll_list
          elsif lf
            x_lim = find_left_limit coll_list
          elsif dn
            y_lim = find_down_limit coll_list
          elsif up
            y_lim = find_up_limit coll_list
          end
          if rt && @x + @w + @speed.x > x_lim.not_nil!
            @x = x_lim.not_nil! - @w; @speed.x = 0
          elsif lf && @x + @speed.x < x_lim.not_nil!
            @x = x_lim.not_nil!; @speed.x = 0
          elsif dn && @y + @h + @speed.y > y_lim.not_nil!
            @y = y_lim.not_nil! - @h; @speed.y = 0
          elsif up && @y + @speed.y < y_lim.not_nil!
            @y = y_lim.not_nil!; @speed.y = 0
          end
        else
          # Diagonal
          x_aim = @x + @speed.x + (rt ? @w : 0); x_lim_def = x_aim
          y_aim = @y + @speed.y + (dn ? @h : 0); y_lim_def = y_aim
          coll_list.each do |c|
            if c.passable; x_lim = x_aim
            elsif rt; x_lim = c.x
            else; x_lim = c.x + c.w
            end
            if dn; y_lim = c.y
            elsif c.passable; y_lim = y_aim
            else; y_lim = c.y + c.h
            end

            if c.passable
              y_lim_def = y_lim if dn && @y + @h <= y_lim && y_lim < y_lim_def
            elsif (rt && @x + @w > x_lim) || (lf && @x < x_lim)
              # Can't limit by x, will limit by y
              y_lim_def = y_lim if (dn && y_lim < y_lim_def) || (up && y_lim > y_lim_def)
            elsif (dn && @y + @h > y_lim) || (up && @y < y_lim)
              # Can't limit by y, will limit by x
              x_lim_def = x_lim if (rt && x_lim < x_lim_def) || (lf && x_lim > x_lim_def)
            else
              x_time = 1.0 * (x_lim - @x - (@speed.x < 0 ? 0 : @w)) / @speed.x
              y_time = 1.0 * (y_lim - @y - (@speed.y < 0 ? 0 : @h)) / @speed.y
              if x_time > y_time
                # Will limit by x
                x_lim_def = x_lim if (rt && x_lim < x_lim_def) || (lf && x_lim > x_lim_def)
              elsif (dn && y_lim < y_lim_def) || (up && y_lim > y_lim_def)
                y_lim_def = y_lim
              end
            end
          end
          if x_lim_def != x_aim
            @speed.x = 0
            if lf; @x = x_lim_def
            else; @x = x_lim_def - @w
            end
          end
          if y_lim_def != y_aim
            @speed.y = 0
            if up; @y = y_lim_def
            else; @y = y_lim_def - @h
            end
          end
        end
      end
      @x += @speed.x
      @y += @speed.y

      # Keeping contact with ramp
      # if @speed.y == 0 and @speed.x.abs <= G.ramp_contact_threshold and @bottom.is_a? Ramp
      #   @y = @bottom.get_y(self)
      #   puts 'aqui'
      # end
      ramps.each do |r|
        r.check_intersection self
      end
      check_contact obst, ramps
    end

    # Moves this object as an elevator (i.e., potentially carrying other
    # objects) with the specified forces or towards a given point.
    #
    # Parameters:
    # [arg] A Vector specifying either the forces acting on this object or a
    #       point towards the object should move.
    # [speed] If the first argument is a forces vector, then this should be
    #         +nil+. If it is a point, then this is the constant speed at which
    #         the object will move (provided as a scalar, not a vector).
    # [carried_objs] An array of objects that can potentially be carried by
    #                this object while it moves. The objects must respond to
    #                +x+, +y+, +w+ and +h+.
    # [obstacles] Obstacles that should be considered for collision checking
    #             with the carried objects, if they include the +Movement+
    #             module, and with this object too, if moving with forces and
    #             the +ignore_collision+ flag is false.
    # [ramps] Ramps that should be considered for the carried objects, if they
    #         include the +Movement+ module, and for this object too, if moving
    #         with forces and +ignore_collision+ is false.
    # [ignore_collision] Set to true to make this object ignore collision even
    #                    when moving with forces.
    def move_carrying(arg, speed, carried_objs, obstacles, ramps, ignore_collision = false)
      if speed
        x_d = arg.x - @x; y_d = arg.y - @y
        distance = Math.sqrt(x_d**2 + y_d**2)

        if distance == 0
          @speed.x = @speed.y = 0
          return
        end

        @speed.x = 1.0 * x_d * speed / distance
        @speed.y = 1.0 * y_d * speed / distance
        x_aim = @x + @speed.x; y_aim = @y + @speed.y
      else
        x_aim = @x + @speed.x + G.gravity.x + arg.x
        y_aim = @y + @speed.y + G.gravity.y + arg.y
      end

      passengers = [] of Movement
      carried_objs.each do |o|
        if @x + @w > o.x && o.x + o.w > @x
          foot = o.y + o.h
          if foot.round(6) == @y.round(6) || @speed.y < 0 && foot < @y && foot > y_aim
            passengers << o
          end
        end
      end

      prev_x = @x; prev_y = @y
      if speed
        if @speed.x > 0 && x_aim >= arg.x || @speed.x < 0 && x_aim <= arg.x
          @x = arg.x; @speed.x = 0
        else
          @x = x_aim
        end
        if @speed.y > 0 && y_aim >= arg.y || @speed.y < 0 && y_aim <= arg.y
          @y = arg.y; @speed.y = 0
        else
          @y = y_aim
        end
      else
        move(arg, ignore_collision ? [] of (Movement | Block) : obstacles, ignore_collision ? [] of Ramp : ramps)
      end

      forces = Vector.new @x - prev_x, @y - prev_y
      prev_g = G.gravity.clone
      G.gravity.x = G.gravity.y = 0
      passengers.each do |p|
        if p.class.included_modules.include?(Movement)
          prev_speed = p.speed.clone
          prev_forces = p.stored_forces.clone
          prev_bottom = p.bottom
          p.speed.x = p.speed.y = 0
          p.stored_forces.x = p.stored_forces.y = 0
          p.instance_exec { @bottom = nil }
          p.move(forces * p.mass, obstacles, ramps)
          p.speed.x = prev_speed.x
          p.speed.y = prev_speed.y
          p.stored_forces.x = prev_forces.x
          p.stored_forces.y = prev_forces.y
          p.instance_exec(prev_bottom) { |b| @bottom = b }
        else
          p.x += forces.x
          p.y += forces.y
        end
      end
      G.gravity = prev_g
    end

    # Moves this object, without performing any collision checking, towards
    # a specified point or in a specified direction.
    #
    # Parameters:
    # [aim] A +Vector+ specifying where the object will move to or an angle (in
    #       degrees) indicating the direction of the movement. Angles are
    #       measured starting from the right (i.e., to move to the right, the
    #       angle must be 0) and raising clockwise.
    # [speed] The constant speed at which the object will move. This must be
    #         provided as a scalar, not a vector.
    def move_free(aim, speed)
      if aim.is_a? Vector
        x_d = aim.x - @x; y_d = aim.y - @y
        distance = Math.sqrt(x_d**2 + y_d**2)

        if distance == 0
          @speed.x = @speed.y = 0
          return
        end

        @speed.x = 1.0 * x_d * speed / distance
        @speed.y = 1.0 * y_d * speed / distance

        if (@speed.x < 0 && @x + @speed.x <= aim.x) || (@speed.x >= 0 && @x + @speed.x >= aim.x)
          @x = aim.x
          @speed.x = 0
        else
          @x += @speed.x
        end

        if (@speed.y < 0 && @y + @speed.y <= aim.y) || (@speed.y >= 0 && @y + @speed.y >= aim.y)
          @y = aim.y
          @speed.y = 0
        else
          @y += @speed.y
        end
      else
        rads = aim * Math::PI / 180
        @speed.x = speed * Math.cos(rads)
        @speed.y = speed * Math.sin(rads)
        @x += @speed.x
        @y += @speed.y
      end
    end

    # Causes the object to move in cycles across multiple given points (the
    # first point in the array is the first point the object will move towards,
    # so it doesn't need to be equal to the current/initial position). If
    # obstacles are provided, it will behave as an elevator (as in
    # +move_carrying+).
    #
    # Parameters:
    # [points] An array of Vectors representing the path that the object will
    #          perform.
    # [speed] The constant speed at which the object will move. This must be
    #         provided as a scalar, not a vector.
    # [obstacles] An array of obstacles to be considered in the collision
    #             checking, and carried along when colliding from above.
    #             Obstacles must be instances of Block (or derived classes),
    #             or objects that <code>include Movement</code>.
    # [obst_obstacles] Obstacles that should be considered when moving objects
    #                  from the +obstacles+ array, i.e., these obstacles won't
    #                  interfere in the elevator's movement, but in the movement
    #                  of the objects being carried.
    # [obst_ramps] Ramps to consider when moving objects from the +obstacles+
    #              array, as described for +obst_obstacles+.
    # [stop_time] Optional stop time (in frames) when the object reaches each of
    #             the points.
    def cycle(points, speed, obstacles = nil, obst_obstacles = nil, obst_ramps = nil, stop_time = 0)
      unless @cycle_setup
        @cur_point = 0 if @cur_point.nil?
        if obstacles
          obst_obstacles = [] of Movement if obst_obstacles.nil?
          obst_ramps = [] of Ramp if obst_ramps.nil?
          move_carrying points[@cur_point], speed, obstacles, obst_obstacles, obst_ramps
        else
          move_free points[@cur_point], speed
        end
      end
      if @speed.x == 0 && @speed.y == 0
        unless @cycle_setup
          @cycle_timer = 0
          @cycle_setup = true
        end
        if @cycle_timer >= stop_time
          if @cur_point == points.length - 1
            @cur_point = 0
          else
            @cur_point += 1
          end
          @cycle_setup = false
        else
          @cycle_timer += 1
        end
      end
    end

    private def check_contact(obst, ramps)
      prev_bottom = @bottom
      @top = @bottom = @left = @right = nil
      obst.each do |o|
        x2 = @x + @w; y2 = @y + @h; x2o = o.x + o.w; y2o = o.y + o.h
        @right = o if !o.passable && x2.round(6) == o.x.round(6) && y2 > o.y && @y < y2o
        @left = o if !o.passable && @x.round(6) == x2o.round(6) && y2 > o.y && @y < y2o
        @bottom = o if y2.round(6) == o.y.round(6) && x2 > o.x && @x < x2o
        @top = o if !o.passable && @y.round(6) == y2o.round(6) && x2 > o.x && @x < x2o
      end
      if @bottom.nil?
        ramps.each do |r|
          if r.contact? self
            @bottom = r
            break
          end
        end
        if @bottom.nil?
          ramps.each do |r|
            if r == prev_bottom && @x + @w > r.x && r.x + r.w > @x &&
                @prev_speed.x.abs <= G.ramp_contact_threshold &&
                @prev_speed.y >= 0
              @y = r.get_y self
              @bottom = r
              break
            end
          end
        end
      end
    end

    private def find_right_limit(coll_list) : (Int32 | Float32)
      limit = @x + @w + @speed.x
      coll_list.each do |c|
        limit = c.x if !c.passable && c.x < limit
      end
      limit
    end

    private def find_left_limit(coll_list)
      limit = @x + @speed.x
      coll_list.each do |c|
        limit = c.x + c.w if !c.passable && c.x + c.w > limit
      end
      limit
    end

    private def find_down_limit(coll_list)
      limit = @y + @h + @speed.y
      coll_list.each do |c|
        limit = c.y if c.y < limit && c.y >= @y + @h
      end
      limit
    end

    private def find_up_limit(coll_list)
      limit = @y + @speed.y
      coll_list.each do |c|
        limit = c.y + c.h if !c.passable && c.y + c.h > limit
      end
      limit
    end
  end
end
