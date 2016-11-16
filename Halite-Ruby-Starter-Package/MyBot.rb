$:.unshift(File.dirname(__FILE__))
require 'networking'

$network = Networking.new("ElBotGrande")
$tag, map = $network.configure

$NORTH = GameMap::CARDINALS[0]
$EAST = GameMap::CARDINALS[1]
$SOUTH = GameMap::CARDINALS[2]
$WEST = GameMap::CARDINALS[3]

$directions = [ GameMap::CARDINALS[0], GameMap::CARDINALS[1] ]
def valid_moves(map, loc)
  moves = []
  #GameMap::CARDINALS.each do |l|
  $directions.each do |l|
    new_loc = map.find_location(loc, l)
    site = map.site(new_loc)
    if site.owner != $tag
      moves << l
    end
  end
  moves
end

def should_wait(map, site)
  return true if site.strength < site.production*5

  return false if site.strength == 255

  return true if site.production > 50 && site.strength < 255
  return true if site.production > 30 && (site.strength < 90 || site.strength >= 165)
  return true if site.production > 10 && (site.strength < 30 || site.strength >= 225)
  return true if site.production > 5 && (site.strength < 15 || site.strength >= 245)

  return false
end

# Hash of piece to move and
#directions

def primary()
  while true
    moves = []
    map = $network.frame

    (0...map.height).each do |y|
      (0...map.width).each do |x|
        loc = Location.new(x, y)
        site = map.site(loc)

        next if site.owner != $tag

        next if should_wait(map, site)

        valid = valid_moves(map, loc)
        if valid.empty?
          opts = $directions
          #opts = site.strength == 255 ? directions : ([GameMap::DIRECTIONS[0] ] +  directions
          moves << Move.new(loc, opts.shuffle.first)
        else
          moves << Move.new(loc, valid.shuffle.first)
        end

      end
    end

    $network.send_moves(moves)
  end
end

# good algorithm
# 1) get all of our pieces
# 2) get all of our border spaces
# 3) assign each piece a destination border space
# 4) move each piece toward that space
# - need to worry about collisions, combining pieces
# - need to level of pieces
# - should move bots to high production areas nearby to level up

# simpler algorithm
# - if you're on a site that has:
#  str > 50, wait until you have 255
#  str > 30, wait until you have 90
#  str > 10, wait until you have 30
#  str > 5, wait until you have 15
#  else wait until you have 0
# - upon spawn, each bot is given two directions it can go in from
#  <north, south> and <east, west>
# - we assign a random movement of that set to each piece.
# - if there are multiple pieces assigned to that square, we assign them to the
# other square. if those are taken, we have the weakest wait.
# - don't attack a square unless you are stronger
#primary()

# other simple strategy:
# - if there is an unowned adjacent square:
#   - if you have > strength than it, then eat it
#   - otherwise, wait until your strength is >
# - if you are surrounded by your squares, move N or E

# OPTIMIZATIONS:
# - compute the center-of-mass and have your guys move away from it
#   there are two vectors you can move in, use some secondary selection
#   to determine which vector (random or weighted random according to vector?)
# - weigh the center-of-mass according to strength of dudes since the
#   weaker side will be having more trouble.
# - have a list of min targets so only one piece is waiting to capture another
#   if you have an L around a square
#   - how will this work when adjacent to an enemy square?
# - move inner pieces toward border that is closest to it (dynamic programming)
# - move toward high productive zones (are there clusters?)
# - or, more radially outward from center
# - re-write in go

# Return adjacent square with min strength.
def get_target(map, loc)
  owned = nil
  owned_min = 1000
  GameMap::CARDINALS.each do |l|
    new_loc = map.find_location(loc, l)
    site = map.site(new_loc)
    if site.owner != $tag && site.strength < owned_min
      owned_min = site.strength
      owned = l
    end
  end
  owned
end

def find_pieces(map)
  pieces = []
  (0...map.height).each do |y|
    (0...map.width).each do |x|
      loc = Location.new(x, y)
      site = map.site(loc)
      pieces << loc if site.owner == $tag
    end
  end
  return pieces
end

# the center will be closer to the area with more strength; so the
# weaker side will need more help. we'll send pieces away from the center
# and there will be more pieces on the weaker side.
def compute_weighted_center_of_mass(map, pieces)
  #cx = (x0*w0 + x1*w1 + ... + xn*wn) / (w0 + w1 + ... wn)
  total_weight = 0
  cx = 0
  cy = 0
  pieces.each do |loc|
    site = map.site(loc)
    total_weight += site.strength
    cx += loc.x*site.strength
    cy += loc.y*site.strength
  end
  return [cx / total_weight, cy / total_weight]
end

def simple()
  while true
    moves = []
    map = $network.frame
    pieces = find_pieces(map)
    cx, cy = compute_weighted_center_of_mass(map, pieces)
    File.open('debug.log', 'a') { |file| file.write([cx, cy,"\n"].join(" ")) }

    pieces.each do |loc|
      site = map.site(loc)

      target = get_target(map, loc)

      # All adjacent squares are controlled by this bot, so move away
      # from the center of mass.
      if target == nil || target.empty?

        options = []
        x_diff = loc.x - cx
        if x_diff > 0
          options << $EAST
        elsif x_diff < 0
          options << $WEST
        end

        # Y gets bigger going down.
        y_diff = loc.y - cy
        if y_diff > 0
          options << $SOUTH
        elsif y_diff < 0
          options << $NORTH
        end

=begin
        File.open('debug.log', 'a') { |file|
          file.write(['diff', x_diff, y_diff,"\n"].join(" "))
          file.write(([ ['diff_options'] + options, "\n"]).join(" "))
          file.write(([ ['allOptions'] + GameMap::CARDINALS, "\n"]).join(" "))
          file.write((['EAST', $EAST, "\n"].join(" ")))
        }
=end
        # TODO: next OPTIMIZATION: don't let big guys eat other guys. Just make sure
        # there are no collisions.

        # TODO: would be cool to weigh the direction you go in based off
        # how far offset you are respectfully (e.g. if you're almost
        # vertically aligned with COM you want to mostly move vertically
        # away). Do this with weighted probability

        # TODO: what about when we wrap around the map? :(

        if site.strength > 5*site.production
          options = options.empty? ? GameMap::CARDINALS : options
          moves << Move.new(loc, options.shuffle.first)
        end

      # Move toward minimum adjacent square as long as we can take it.
      else
        target_loc = map.site(map.find_location(loc, target))
        if target_loc.strength < site.strength
          moves << Move.new(loc, target)
        end
      end

    end

    $network.send_moves(moves)
  end
end

simple()
