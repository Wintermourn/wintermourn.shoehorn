local __DataType = RogueEssence.Data.DataManager.DataType
local __BindingFlags = luanet.import_type 'System.Reflection.BindingFlags'
local __IO = luanet.namespace 'System.IO' or luanet.namespace 'System.IO.Directory'
    local __Path = __IO.Path
    local __Directory = __IO.Directory
    local __File = __IO.File
local __String = luanet.import_type 'System.String'
local __Json_Linq = import ("Newtonsoft.Json", "Newtonsoft.Json.Linq")
    local __JObject = __Json_Linq.JObject
    local __JValue = __Json_Linq.JValue
local __Json = import ("Newtonsoft.Json", "Newtonsoft.Json")
    local __JsonConvert = __Json.JsonConvert

local type__DataManager = _DATA:GetType()
    local method__loadObject = type__DataManager:GetMethod("loadData", LUA_ENGINE:LuaCast(40, __BindingFlags))

local resolve_id = require 'wintermourn-shoehorn.util.id_resolver'

local function exists(id)
    return _DATA.DataIndices[__DataType.Monster]:ContainsKey(id)
end

local mod = RogueEssence.PathMod.GetModFromNamespace 'wintermourn-shoehorn'
local mod_path = __Path.Combine(RogueEssence.PathMod.APP_PATH, mod.Path)
local monster_data_folder = __Path.Combine(mod_path, "Data/Monster")
local monster_chara_folder = __Path.Combine(mod_path, "Content/Chara")
local monster_portraits_folder = __Path.Combine(mod_path, "Content/Portrait")

---@param shoehorn Wintermourn.Shoehorn.Global
---@param pack Wintermourn.Shoehorn.Pack
return function(shoehorn, pack, renames)

    if not __Directory.Exists(monster_data_folder) then __Directory.CreateDirectory(monster_data_folder) end

    if not __Directory.Exists(monster_chara_folder) then __Directory.CreateDirectory(monster_chara_folder) end
    if not __Directory.Exists(monster_portraits_folder) then __Directory.CreateDirectory(monster_portraits_folder) end

    local shared_ids = pack.public_id and shoehorn.shared_identifiers[pack.public_id].monster or {}

    if pack.registrations.monsters == nil or #pack.registrations.monsters == 0 then return end
    for c,v in pairs(pack.registrations.monsters) do
        if not v.enabled then
            goto continue
        end

        if v.files.data == nil then
            local monster = _DATA:GetMonster(v.preferred_id)
            if not monster then goto continue end
            local monster_id = monster.IndexNum
            if v.files.sprites then
                __File.Copy(__Path.Combine(pack.folder, v.files.sprites), __Path.Combine(monster_chara_folder, monster_id .. ".chara"))
            end
            if v.files.portraits then
                __File.Copy(__Path.Combine(pack.folder, v.files.portraits), __Path.Combine(monster_portraits_folder, monster_id .. ".portrait"))
            end
            goto continue
        end

        local final_name = v.preferred_id
        local final_id = _DATA.DataIndices[__DataType.Monster].Count -- missingno is index 0
        local replacement_mode = v.replacement_mode
        if exists(final_name) then
            if v.replacement_mode == "rename" then
                local idx = 1
                while exists(("%s-%d"):format(final_name, idx)) do
                    idx = idx + 1
                end
                final_name = ("%s-%d"):format(final_name, idx)
            elseif replacement_mode == "ignore" then
                goto continue
            --[[ elseif replacement_mode == "merge" then
                local existing_monster = _DATA:GetMonster(final_name)
                local replacing_monster = method__loadObject:Invoke(nil, {__Path.Combine(shoehorn.folder, v.files.data), luanet.make_array(
                    __String, {}
                )})

                existing_monster.Name = replacing_monster.Name or existing_monster.Name
                existing_monster.Title = replacing_monster.Title or existing_monster.Title
                existing_monster.Released = replacing_monster.Released or existing_monster.Released
                existing_monster.Comment = replacing_monster.Comment or existing_monster.Comment
                existing_monster.IndexNum = existing_monster.IndexNum or replacing_monster.IndexNum
                existing_monster.EXPTable = replacing_monster.EXPTable or existing_monster.EXPTable
                existing_monster.SkillGroup1 = replacing_monster.SkillGroup1 or existing_monster.SkillGroup1
                existing_monster.SkillGroup2 = replacing_monster.SkillGroup2 or existing_monster.SkillGroup2
                existing_monster.JoinRate = replacing_monster.JoinRate or existing_monster.JoinRate
                existing_monster.PromoteFrom = replacing_monster.PromoteFrom or existing_monster.PromoteFrom
                existing_monster.Promotions = replacing_monster.Promotions or existing_monster.Promotions
                    ]]
            else
                final_id = _DATA:GetMonster(final_name).IndexNum
            end
        end

        local data_file_path = __Path.Combine(pack.folder, v.files.data)
        local json_data = __JObject.Parse(__File.ReadAllText(data_file_path))

        local monster_object = json_data["Object"]
        monster_object:Remove "IndexNum"
        monster_object:Add("IndexNum", __JValue (final_id))

        for form in luanet.each(monster_object["Forms"]) do
            for _, element in ipairs {"Element1", "Element2"} do
                local element_id = resolve_id(__DataType.Element, form[element]:ToString(), renames.elements, shoehorn)
                if element_id ~= nil then
                    print(element, element_id)
                    form:Remove (element)
                    form:Add (element, __JValue (element_id))
                end
            end
        end
        --! todo: patch moves

        local out_data = __JsonConvert.SerializeObject(json_data)
        local data_ext = __Path.GetExtension(v.files.data):lower()
        __File.WriteAllText(__Path.Combine(monster_data_folder, final_name .. data_ext), out_data)
        table.insert(shoehorn.registered_identifiers.monsters, final_name)
        if pack.public_id then
            shared_ids[v.preferred_id] = final_name
        end

        if v.files.sprites then
            __File.Copy(__Path.Combine(pack.folder, v.files.sprites), __Path.Combine(monster_chara_folder, final_id .. ".chara"), true)
        end
        if v.files.portraits then
            __File.Copy(__Path.Combine(pack.folder, v.files.portraits), __Path.Combine(monster_portraits_folder, final_id .. ".portrait"), true)
        end

        ::continue::
    end
end