#===============================================================================
# Game Character
#===============================================================================
class Game_Character
  def opacity=(value)
    @opacity = value
  end
end

#===============================================================================
# Sprite Surf Base
#===============================================================================
class Sprite_SurfBase
	alias fly_animation_update update
	def update()
		return if disposed?
		if $PokemonGlobal.surfing || $PokemonGlobal.diving
			if @sprite && !@sprite.disposed?
				@sprite.src_rect.x = 0
				@sprite.src_rect.y = 0
			end
			return
		end
		fly_animation_update()
	end
end

#===============================================================================
# pbFlyToNewLocation
#===============================================================================
def pbFlyToNewLocation(pokemon = nil, move = :FLY)
  return false if $game_temp.fly_destination.nil?
  pokemon = $player.get_pokemon_with_move(move) if !pokemon
  if !$DEBUG && !pokemon
    $game_temp.fly_destination = nil
    yield if block_given?
    return false
  end
  OverworldFlyAnimation.show_pokeball()
  pbWait(0.25)
  if !pokemon || !pbHiddenMoveAnimation(pokemon)
    name = pokemon&.name || $player.name
    pbMessage(_INTL("{1} used {2}!", name, GameData::Move.get(move).name))
  end
  OverworldFlyAnimation.departure()
  $stats.fly_count += 1
  pbFadeOutIn do
    pbSEPlay("Fly")
    $game_temp.player_new_map_id    = $game_temp.fly_destination[0]
    $game_temp.player_new_x         = $game_temp.fly_destination[1]
    $game_temp.player_new_y         = $game_temp.fly_destination[2]
    $game_temp.player_new_direction = 2
    $game_temp.fly_destination = nil
    pbDismountBike
    $scene.transfer_player
    $game_map.autoplay
    $game_map.refresh
    yield if block_given?
    pbWait(0.25)
  end
	OverworldFlyAnimation.landing()
  pbEraseEscapePoint()
  return true
end

#===============================================================================
# Overworld Fly Animation
#===============================================================================
class OverworldFlyAnimation

  POKEBALL_TIME   = 0.08
  BIRD_TIME       = 0.008
  ZOOM_MULTIPLIER = 0.08
  MOVEMENT_CONST  = 25

  # Draw the player showing the pokéball
  def self.show_pokeball()
    graphic = CHARACTER_PLAYER[$player.character_ID - 1]
    for i in 0..5 do
      case i
      when 0; $game_player.character_name = pbGetPlayerCharset(graphic[0])
      when 1; $game_player.turn_down
      when 2; $game_player.turn_left
      when 3; $game_player.turn_right
      when 4; $game_player.turn_up
      when 5; $game_player.character_name = pbGetPlayerCharset(graphic[1])
      end
      pbWait(POKEBALL_TIME)
    end
  end

  # Draw the player hiding the pokéball
  def self.hide_pokeball()
    graphic = CHARACTER_PLAYER[$player.character_ID - 1]
    for i in 0..5 do
      case i
      when 0; $game_player.character_name = pbGetPlayerCharset(graphic[0])
      when 1; $game_player.turn_up
      when 2; $game_player.turn_right
      when 3; $game_player.turn_left
      when 4; $game_player.turn_down
      when 5; $game_player.refresh_charset
      end
      pbWait(POKEBALL_TIME)
    end
  end

  # Fly to location
  def self.departure()
    graphic = CHARACTER_PLAYER[$player.character_ID - 1]
    # Bird flying out the pokéball
		viewport = Viewport.new(0, 0, Settings::SCREEN_WIDTH, Settings::SCREEN_HEIGHT)
		viewport.z = 999999
		sprite = {}
		sprite[CHARACTER_BIRD] = Sprite.new(viewport)
		sprite[CHARACTER_BIRD].bitmap = RPG::Cache.picture(CHARACTER_BIRD)
		sprite[CHARACTER_BIRD].ox = sprite[CHARACTER_BIRD].bitmap.width / 2
		sprite[CHARACTER_BIRD].oy = sprite[CHARACTER_BIRD].bitmap.height / 2
		sprite[CHARACTER_BIRD].x  = Settings::SCREEN_WIDTH / 2
		sprite[CHARACTER_BIRD].y  = Settings::SCREEN_HEIGHT / 2
		sprite[CHARACTER_BIRD].angle = 270
		sprite[CHARACTER_BIRD].zoom_x = 0
    sprite[CHARACTER_BIRD].zoom_y = 0
		time = 2
		value = 5.to_f
		distance = (Settings::SCREEN_HEIGHT / 2 + sprite[CHARACTER_BIRD].oy).to_f
		zoom = (value * time) / distance
		loop do
			Graphics.update
			pbUpdateSpriteHash(sprite)
			sprite[CHARACTER_BIRD].y -= value * time
      sprite[CHARACTER_BIRD].zoom_x += zoom
      sprite[CHARACTER_BIRD].zoom_y += zoom
      pbWait(BIRD_TIME)
      break if sprite[CHARACTER_BIRD].y <= -sprite[CHARACTER_BIRD].oy
		end
		pbDisposeSpriteHash(sprite)
		viewport.dispose()
    pbWait(POKEBALL_TIME)
    # Player hiding the pokéball
		hide_pokeball()
    # Player riding the bird animation
    pbSEPlay(SE_BIRD)
    viewport = Viewport.new(0, 0, Settings::SCREEN_WIDTH, Settings::SCREEN_HEIGHT)
    viewport.z = 999999
    pictureBird = Sprite.new(viewport)
    pictureBird.bitmap = RPG::Cache.picture(CHARACTER_BIRD)
    pictureBird.ox = pictureBird.bitmap.width / 2
    pictureBird.oy = pictureBird.bitmap.height / 2
    pictureBird.x  = Settings::SCREEN_WIDTH + pictureBird.bitmap.width
    pictureBird.y  = Settings::SCREEN_HEIGHT / 4
    player = Sprite.new(viewport)
    player.bitmap = RPG::Cache.picture(graphic[2])
    player.opacity = 0
    player.ox = player.bitmap.width / 2
    player.oy = player.bitmap.height / 2
    player.x = pictureBird.x
    player.y = pictureBird.y
    @@bird_with_player_frames = 0
    loop do
      pbUpdateSceneMap
      if pictureBird.x > (Settings::SCREEN_WIDTH / 2 + 10)
        pictureBird.x -= (Settings::SCREEN_WIDTH + pictureBird.bitmap.width - Settings::SCREEN_WIDTH / 2) / MOVEMENT_CONST
        pictureBird.y -= (Settings::SCREEN_HEIGHT / 4 - Settings::SCREEN_HEIGHT / 2) / MOVEMENT_CONST
        player.x = pictureBird.x
        player.y = pictureBird.y
        player.opacity = 0
        pictureBird.opacity = 255
      elsif pictureBird.x <= (Settings::SCREEN_WIDTH / 2 + 10) && pictureBird.x >= 0
        pictureBird.x -= (Settings::SCREEN_WIDTH + pictureBird.bitmap.width - Settings::SCREEN_WIDTH / 2) / MOVEMENT_CONST
        pictureBird.y += (Settings::SCREEN_HEIGHT / 4 - Settings::SCREEN_HEIGHT / 2) / MOVEMENT_CONST
        $game_player.opacity = 0
        player.x = pictureBird.x
        player.y = pictureBird.y
        player.zoom_x += ZOOM_MULTIPLIER
        player.zoom_y += ZOOM_MULTIPLIER
        @@bird_with_player_frames += 1
        player.opacity = 255
        pictureBird.opacity = 0
      else
        break
      end
      pbWait(BIRD_TIME)
      Graphics.update
    end
    pictureBird.dispose()
    player.dispose()
    viewport.dispose()
    return true
  end

  # Arrive at destination
  def self.landing()
    graphic = CHARACTER_PLAYER[$player.character_ID - 1]
    # Player riding the bird animation
    viewport = Viewport.new(0, 0, Settings::SCREEN_WIDTH, Settings::SCREEN_HEIGHT)
    viewport.z = 999999
    pictureBird = Sprite.new(viewport)
    pictureBird.bitmap = RPG::Cache.picture(CHARACTER_BIRD)
    pictureBird.ox = pictureBird.bitmap.width / 2
    pictureBird.oy = pictureBird.bitmap.height / 2
    pictureBird.x  = Settings::SCREEN_WIDTH + pictureBird.bitmap.width
    pictureBird.y  = Settings::SCREEN_HEIGHT / 4
    pictureBird.zoom_x += ZOOM_MULTIPLIER * @@bird_with_player_frames
    pictureBird.zoom_y += ZOOM_MULTIPLIER * @@bird_with_player_frames
    player = Sprite.new(viewport)
    player.bitmap = RPG::Cache.picture(graphic[3])
    player.opacity = 0
    player.ox = player.bitmap.width / 2
    player.oy = player.bitmap.height / 2
    player.x = pictureBird.x
    player.y = pictureBird.y
    loop do
      pbUpdateSceneMap
      if pictureBird.x > (Settings::SCREEN_WIDTH / 2 + 10)
        pictureBird.x -= (Settings::SCREEN_WIDTH + pictureBird.bitmap.width - Settings::SCREEN_WIDTH / 2) / MOVEMENT_CONST
        pictureBird.y -= (Settings::SCREEN_HEIGHT / 4 - Settings::SCREEN_HEIGHT / 2) / MOVEMENT_CONST
        player.x = pictureBird.x
        player.y = pictureBird.y
        if @@bird_with_player_frames > 0
          pictureBird.zoom_x -= ZOOM_MULTIPLIER
          pictureBird.zoom_y -= ZOOM_MULTIPLIER
          player.zoom_x = pictureBird.zoom_x
          player.zoom_y = pictureBird.zoom_y
          @@bird_with_player_frames -= 1
        end
        player.opacity = 255
        pictureBird.opacity = 0
      elsif pictureBird.x <= (Settings::SCREEN_WIDTH / 2 + 10) && pictureBird.x >= 0
        pictureBird.x -= (Settings::SCREEN_WIDTH + pictureBird.bitmap.width - Settings::SCREEN_WIDTH / 2) / MOVEMENT_CONST
        pictureBird.y += (Settings::SCREEN_HEIGHT / 4 - Settings::SCREEN_HEIGHT / 2) / MOVEMENT_CONST
        $game_player.opacity = 255
        player.x = pictureBird.x
        player.y = pictureBird.y
        player.opacity = 0
        pictureBird.opacity = 255
      else
        break
      end
      pbWait(BIRD_TIME)
      Graphics.update
    end
    pictureBird.dispose()
    player.dispose()
    viewport.dispose()
    pbWait(POKEBALL_TIME)
    # Player showing the pokéball
		show_pokeball()
    # Bird flying into the pokéball
		viewport = Viewport.new(0, 0, Settings::SCREEN_WIDTH, Settings::SCREEN_HEIGHT)
		viewport.z = 999999
		sprite = {}
		sprite[CHARACTER_BIRD] = Sprite.new(viewport)
		sprite[CHARACTER_BIRD].bitmap = RPG::Cache.picture(CHARACTER_BIRD)
		sprite[CHARACTER_BIRD].ox = sprite[CHARACTER_BIRD].bitmap.width / 2
		sprite[CHARACTER_BIRD].oy = sprite[CHARACTER_BIRD].bitmap.height / 2
		sprite[CHARACTER_BIRD].x  = Settings::SCREEN_WIDTH / 2
		sprite[CHARACTER_BIRD].y  = -sprite[CHARACTER_BIRD].oy
		sprite[CHARACTER_BIRD].angle = 90
		time = 2
		value = 5.to_f
		distance = (Settings::SCREEN_HEIGHT / 2 + sprite[CHARACTER_BIRD].oy).to_f
		zoom = (value * time) / distance
		loop do
			Graphics.update
			pbUpdateSpriteHash(sprite)
      sprite[CHARACTER_BIRD].y += value * time
      sprite[CHARACTER_BIRD].zoom_x -= zoom
      sprite[CHARACTER_BIRD].zoom_y -= zoom
      if sprite[CHARACTER_BIRD].y >= Settings::SCREEN_HEIGHT / 2
        sprite[CHARACTER_BIRD].zoom_x = 0
        sprite[CHARACTER_BIRD].zoom_y = 0
        break
      end
      pbWait(BIRD_TIME)
		end
		pbDisposeSpriteHash(sprite)
		viewport.dispose()
    # Player hiding the pokéball
		hide_pokeball()
    return true
  end
end
