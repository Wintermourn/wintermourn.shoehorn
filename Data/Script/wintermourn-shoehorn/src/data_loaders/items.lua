local __DataType = RogueEssence.Data.DataManager.DataType
local __BindingFlags = luanet.import_type 'System.Reflection.BindingFlags'
local __IO = luanet.namespace 'System.IO' or luanet.namespace 'System.IO.Directory'
    local __Path = __IO.Path
    local __Directory = __IO.Directory
    local __File = __IO.File
    local __FileStream = __IO.FileStream
    local __MemoryStream = __IO.MemoryStream
    local __StreamReader = __IO.StreamReader
local __Json_Linq = import ("Newtonsoft.Json", "Newtonsoft.Json.Linq")
    local __JToken = __Json_Linq.JToken
    local __JObject = __Json_Linq.JObject
    local __JValue = __Json_Linq.JValue
    local __JTokenType = __Json_Linq.JTokenType
local __Json = import ("Newtonsoft.Json", "Newtonsoft.Json")
    local __JsonConvert = __Json.JsonConvert
local __Convert = luanet.import_type "System.Convert"
local __Dictionary__String_String = luanet.import_type 'System.Collections.Generic.Dictionary`2[System.String,System.String]'
    local type_Dictionary__String_string = luanet.ctype(__Dictionary__String_String)
local __Text = luanet.namespace 'System.Text'
    local __Encoding = __Text.Encoding
    local __UTF8Encoding = __Text.UTF8Encoding
local __Array = luanet.import_type 'System.Array'
local __Int32 = luanet.import_type 'System.Int32'

local resolve_id = require 'wintermourn-shoehorn.util.id_resolver'

local function exists(id)
    return _DATA.DataIndices[__DataType.Intrinsic]:ContainsKey(id)
end

local mod = RogueEssence.PathMod.GetModFromNamespace 'wintermourn-shoehorn'
local mod_path = __Path.Combine(RogueEssence.PathMod.APP_PATH, mod.Path)
local intrinsic_data_folder = __Path.Combine(mod_path, "Data/Intrinsic")

---@param shoehorn Wintermourn.Shoehorn.Global
---@param pack Wintermourn.Shoehorn.Pack
return function(shoehorn, pack, renames)

    if not __Directory.Exists(intrinsic_data_folder) then __Directory.CreateDirectory(intrinsic_data_folder) end

    local local_renames = {}
    local shared_ids = pack.public_id and shoehorn.shared_identifiers[pack.public_id].intrinsic or {}

    if pack.registrations.intrinsic == nil or #pack.registrations.intrinsic == 0 then return end
    for _c,v in pairs(pack.registrations.intrinsic) do
        if not v.enabled then
            goto continue
        end

        local final_name = v.preferred_id
        local replacement_mode = v.replacement_mode
        if exists(final_name) then
            if v.replacement_mode == "rename" then
                local idx = 1
                while exists(("%s-%d"):format(final_name, idx)) do
                    idx = idx + 1
                end
                local new_name = ("%s-%d"):format(final_name, idx)
                local_renames[final_name] = new_name
                final_name = new_name
            elseif replacement_mode == "ignore" then
                goto continue
            end
        end

        if pack.public_id then
            shared_ids[v.preferred_id] = final_name
        end

        local data_file_path = __Path.Combine(pack.folder, v.file)
        local out_path = __Path.Combine(intrinsic_data_folder, final_name ..".json")
        local json_data = __JObject.Parse(__File.ReadAllText(data_file_path))

        -- todo: patch events

        __File.WriteAllText(out_path, __JsonConvert.SerializeObject(json_data), __Encoding.UTF8)
        table.insert(shoehorn.registered_identifiers.intrinsics, final_name)

        ::continue::
    end

    print("finished intrinsics")

    return local_renames
end