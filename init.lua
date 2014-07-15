local load_time_start = os.clock()

local current_path
local current_string

-- the directions
local directions = {
	x = {x=1, y=0, z=0},
	y = {x=0, y=1, z=0},
	z = {x=0, y=0, z=1},
	["-x"] = {x=-1, y=0, z=0},
	["-y"] = {x=0, y=-1, z=0},
	["-z"] = {x=0, y=0, z=-1}
}

local direction_strings,n = {},1
for i,_ in pairs(directions) do
	direction_strings[n] = i
	n = n+1
end
n = nil

local function table_contains(t, v)
	for _,i in pairs(t) do
		if i == v then
			return true
		end
	end
	return false
end

local function is_direction(typ)
	return table_contains(direction_strings, typ)
end

-- changes a string to a table
local function string_to_path(str)
	local full_path, num = {}, 1
	local anws = {}
	for _,i in ipairs(string.split(str, "\n")) do
		if i ~= "" then
			local path = string.split(i, " ")
			local count = #path
			if count ~= 0 then
				local typ = path[1]
				if not is_direction(typ) then
					local loop = tonumber(typ)
					if loop then
						for n = 1, loop do
							for j = 2, count do
								local dir = path[j]
								if not is_direction(dir) then
									local anw = anws[dir]
									if not anw then
minetest.chat_send_all(dir.." is no anw")
										return
									end
									for _,k in ipairs(anw) do
										full_path[num] = k
										num = num+1
									end
								else
									full_path[num] = dir
									num = num+1
								end
							end
						end
					else
						local anw,n = {},1
						for j = 2, count do
							anw[n] = path[j]
							n = n+1
						end
						anws[typ] = anw
					end
				else
					for _,dir in ipairs(path) do
						if not is_direction(dir) then
							local anw = anws[dir]
							if not anw then
minetest.chat_send_all(dir.." is no anw 2")
								return
							end
							for _,k in ipairs(anw) do
								full_path[num] = k
								num = num+1
							end
						else
							full_path[num] = dir
							num = num+1
						end
					end
				end
			end
		end
	end
	local tab = {}
	local path = full_path
	local count = #path
	for i = 1, count do		
		tab[i] = path[math.abs(i-1-count)]
	end
	return tab
end

-- gets the dug sound of a node
local ndsounds = {}
local function get_nd_sound(name)
	local sound = ndsounds[name]
	if sound then
		return sound
	end
	sound = minetest.registered_nodes[name]
	if not sound then
		return
	end
	sound = sound.sounds
	if not sound then
		return
	end
	sound = sound.dug
	if not sound then
		return
	end
	ndsounds[name] = sound
	return sound
end

-- moves the machine from p1 to p2
local function move_turtle(p1, p2, obj, name)
	local sounds = get_nd_sound(minetest.get_node(p2).name)
	minetest.remove_node(p2)
	obj:moveto(p2)
	if sounds then
		minetest.sound_play(sounds.name, {pos = p2,  gain = sounds.gain})
	end
	if name then
		minetest.add_node(p1, {name=name})
	else
		minetest.remove_node(p1)
	end
end

-- adds machine's meta
local function set_machine_meta(pos, ps)
	local meta = minetest.get_meta(pos)
	meta:set_string("formspec", "size[5,8]"..
		"textarea[0.3,0;5,9;ps;;${ps}]"..
		"button[0.3,7.1;2,2;run;run]"..
		"button[2.6,7.1;2,2;show;save and show box]"
	)
	meta:set_string("infotext", "digging machine")
	meta:set_string("ps", ps)
end

-- adds a machine
local function set_turtle(pos, ps, obj)
	minetest.add_node(pos, {name="simple_machines:dig_machine"})
	set_machine_meta(pos, ps)
	if obj then
		obj:remove()
	end
end

-- copy a table
local function copy_tab(tab)
	if not tab then
		return
	end
	local tab2 = {}
	for n,i in ipairs(tab) do
		tab2[n] = i
	end
	return tab2
end

-- the moving machine
minetest.register_entity("simple_machines:entity",{
	hp_max = 1,
	visual="cube",
	--visual_size={x=1/16, y=1/16},
	collisionbox = {0,0,0,0,0,0},
	physical=true,
	textures={"nodebox_creator_top.png", "nodebox_creator_bottom.png", "nodebox_creator_side1.png",
		"nodebox_creator_side1.png", "nodebox_creator_side2.png", "nodebox_creator_side2.png"},
	timer = 0,
	on_step = function(self, dtime)
		self.timer = self.timer+dtime
		if self.timer >= 1 then
			self.timer = 0
			local path = self.path
			if not path then
				self.object:remove()
				return
			end
			local count = #path
			local p1 = vector.round(self.object:getpos())
			local p2 = vector.add(p1, directions[path[count]])
			if count == 1 then
				set_turtle(p2, self.str, self.object)
				self.path = nil
			else
				move_turtle(p1, p2, self.object)
				self.path[count] = nil
			end
		end
	end,
	on_activate = function(self)
		if self.str then
			return
		end
		if current_path
		and current_path[1]
		and current_string then
			self.path = copy_tab(current_path)
			current_path = nil
			self.str = current_string
			current_string = nil
		else
			self.object:remove()
		end
	end
})

-- enables moving of the machine
local function do_mining(pos, str)
	current_string = str
	current_path = string_to_path(str)
	if not current_path then
		return
	end
	if #current_path == 1 then
		set_turtle(vector.add(pos, directions[current_path[1]]), str)
		current_path = nil
		minetest.remove_node(pos)
	else
		minetest.add_entity(pos, "simple_machines:entity")
	end
	--[[local oldpos
	local timer = 0
	for _,dir in ipairs(string.split(str, " ")) do
		oldpos = vector.new(pos)
		pos = vector.add(oldpos, directions[dir])
		minetest.after(timer, function(oldpos, pos, obj)
			move_turtle(oldpos, pos, obj)
		end, oldpos, pos, obj)
		timer = timer+1
	end
	minetest.after(timer, function(pos, str, obj)
		set_turtle(pos, str, obj)
	end, pos, str, obj)]]
end

-- the quiet machine
minetest.register_node("simple_machines:dig_machine", {
	description = "Digging machine",
	tiles = {"default_steel_block.png","default_wood.png"},
	groups = {snappy=1,bendy=2,cracky=1},
	sounds = default_stone_sounds,
	on_construct = function(pos)
		set_machine_meta(pos, "")
	end,
	on_receive_fields = function(pos, formname, fields, sender)
		local meta = minetest.get_meta(pos)
		local ps = fields.ps
		if not ps
		or ps == "" then
			ps = meta:get_string("ps")
		else
			meta:set_string("ps", ps)
		end
		if fields.run then
			do_mining(pos, ps)
		end
	end
})

print(string.format("[simple_machines] loaded after ca. %.2fs", os.clock() - load_time_start))
