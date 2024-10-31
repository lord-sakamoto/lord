local S = minetest.get_mod_translator()

local default_can_dig = function(pos,player)
	local meta = minetest.get_meta(pos)
	return meta:get_inventory():is_empty("main")
end

local default_inventory_formspecs = {
	["4"]="size[8,6]"..
	"list[context;main;2,0;4,1;]"..
	"list[current_player;main;0,2;8,4;]",

	["6"]="size[8,6]"..
	"list[context;main;1,0;6,1;]"..
	"list[current_player;main;0,2;8,4;]",

	["8"]="size[8,6]"..
	"list[context;main;0,0;8,1;]"..
	"list[current_player;main;0,2;8,4;]",

	["12"]="size[8,7]"..
	"list[context;main;1,0;6,2;]"..
	"list[current_player;main;0,3;8,4;]",

	["16"]="size[8,7]"..
	"list[context;main;0,0;8,2;]"..
	"list[current_player;main;0,3;8,4;]",

	["24"]="size[8,8]"..
	"list[context;main;0,0;8,3;]"..
	"list[current_player;main;0,4;8,4;]",

	["32"]="size[8,9]"..
	"list[context;main;0,0.3;8,4;]"..
	"list[current_player;main;0,4.85;8,1;]"..
	"list[current_player;main;0,6.08;8,3;8]"..
	default.get_hotbar_bg(0,4.85),

	["50"]="size[10,10]"..
	"list[context;main;0,0;10,5;]"..
	"list[current_player;main;1,6;8,4;]",
}

local function get_formspec_by_size(size)
	--TODO heuristic to use the "next best size"
	local formspec = default_inventory_formspecs[tostring(size)]
	return formspec or default_inventory_formspecs
end

----
-- handle inventory setting
-- inventory = {
--	size = 16,
--	formspec = …,
--	locked = false,
--	lockable = true,
-- }
--
function lord_homedecor.handle_inventory(name, def, original_def)
	local inventory = def.inventory
	if not inventory then return end
	def.inventory = nil

	if inventory.size then
		local on_construct = def.on_construct
		def.on_construct = function(pos)
			local size = inventory.size
			local meta = minetest.get_meta(pos)
			meta:get_inventory():set_size("main", size)
			meta:set_string("formspec", inventory.formspec or get_formspec_by_size(size))
			if on_construct then on_construct(pos) end
		end
	end

	def.can_dig = def.can_dig or default_can_dig
	def.on_metadata_inventory_move = def.on_metadata_inventory_move or
		function(pos, from_list, from_index, to_list, to_index, count, player)
			minetest.log("action", S("%s moves stuff in %s at %s"):format(
				player:get_player_name(), name, minetest.pos_to_string(pos)
			))
		end
	def.on_metadata_inventory_put = def.on_metadata_inventory_put or
		function(pos, listname, index, stack, player)
			minetest.log("action", S("%s moves stuff to %s at %s"):format(
				player:get_player_name(), name, minetest.pos_to_string(pos)
			))
		end
	def.on_metadata_inventory_take = def.on_metadata_inventory_take or
		function(pos, listname, index, stack, player)
			minetest.log("action", S("%s takes stuff from %s at %s"):format(
				player:get_player_name(), name, minetest.pos_to_string(pos)
			))
		end

	local locked = inventory.locked
	if locked then
		local after_place_node = def.after_place_node
		def.after_place_node = function(pos, placer)
			local meta = minetest.get_meta(pos)
			local owner = placer:get_player_name() or ""

			meta:set_string("owner", owner)
			meta:set_string("infotext", S("%s (owned by %s)"):format(def.infotext or def.description, owner))
			return after_place_node and after_place_node(pos, placer)
		end

		local allow_move = def.allow_metadata_inventory_move
		def.allow_metadata_inventory_move = function(pos, from_list, from_index, to_list, to_index, count, player)
			local meta = minetest.get_meta(pos)
			local owner = meta:get_string("owner")
			local playername = player:get_player_name()

			if (playername ~= owner) then
				minetest.log("action", string.format("%s tried to access a %s belonging to %s at %s",
					playername, name, owner, minetest.pos_to_string(pos)
				))
				return 0
			end

			return allow_move and allow_move(pos, from_list, from_index, to_list, to_index, count, player)
				or count
		end

		local allow_put = def.allow_metadata_inventory_put
		def.allow_metadata_inventory_put = function(pos, listname, index, stack, player)
			local meta = minetest.get_meta(pos)
			local owner = meta:get_string("owner")
			local playername = player:get_player_name()

			if (playername ~= owner) then
				minetest.log("action", string.format("%s tried to access a %s belonging to %s at %s",
					playername, name, owner, minetest.pos_to_string(pos)
				))
				return 0
			end
			return allow_put and allow_put(pos, listname, index, stack, player)
				or stack:get_count()
		end

		local allow_take = def.allow_metadata_inventory_take
		def.allow_metadata_inventory_take = function(pos, listname, index, stack, player)
			local meta = minetest.get_meta(pos)
			local owner = meta:get_string("owner")
			local playername = player:get_player_name()

			if (playername ~= owner) then
				minetest.log("action", string.format("%s tried to access a %s belonging to %s at %s",
					playername, name, owner, minetest.pos_to_string(pos)
				))
				return 0
			end
			return allow_take and allow_take(pos, listname, index, stack, player)
				or stack:get_count()
		end
	end

	local lockable = inventory.lockable
	if lockable then
		local locked_def = table.copy(original_def)
		locked_def.description = S("Locked %s"):format(def.description or name)

		local locked_inventory = locked_def.inventory
		locked_inventory.locked = true
		locked_inventory.lockable = nil -- avoid loops of locked locked stuff

		local locked_name = name .. "_locked"
		lord_homedecor.register(locked_name, locked_def)
		minetest.register_craft({
			type = "shapeless",
			output = "lord_homedecor:" .. locked_name,
			recipe = { "lord_homedecor:" .. name, "default:steel_ingot" }
		})
	end

end
