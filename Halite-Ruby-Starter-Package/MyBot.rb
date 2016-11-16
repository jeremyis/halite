$:.unshift(File.dirname(__FILE__))
require 'networking'

network = Networking.new("ElBotGrande")
$tag, map = network.configure

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

while true
  moves = []
  map = network.frame

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

  network.send_moves(moves)
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