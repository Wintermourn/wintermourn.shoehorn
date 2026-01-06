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

local __ElementTableState = luanet.import_type 'PMDC.Dungeon.ElementTableState'

local element_symbol = '\u{2060}' -- zero width joiner character - used to remove the element icon

local function exists(id)
    return _DATA.DataIndices[__DataType.Element]:ContainsKey(id)
end

local mod = RogueEssence.PathMod.GetModFromNamespace 'wintermourn-shoehorn'
local mod_path = __Path.Combine(RogueEssence.PathMod.APP_PATH, mod.Path)
local element_data_folder = __Path.Combine(mod_path, "Data/Element")

local relational_terms = {
    strength = {
        none = 0,
        very_low = 2, very_weak = 2,
        low = 3, weak = 3,
        normal = 4, average = 4,
        high = 5, strong = 5,
        very_high = 6, very_strong = 6
    },
    resistance = {
        very_low = 6, very_weak = 6,
        low = 5, weak = 5,
        normal = 4, average = 4,
        high = 3, strong = 3,
        very_high = 2, very_strong = 2,
        immune = 0
    }
}

---@param shoehorn Wintermourn.Shoehorn.Global
---@param pack Wintermourn.Shoehorn.Pack
return function(shoehorn, pack)

    if not __Directory.Exists(element_data_folder) then __Directory.CreateDirectory(element_data_folder) end
    local elestate = _DATA.UniversalEvent.UniversalStates:GetWithDefault(luanet.ctype(__ElementTableState))

    local local_renames = {}
    local calculated_matchups = {}
    local shared_ids = pack.public_id and shoehorn.shared_identifiers[pack.public_id].element or {}

    if pack.registrations.elements == nil or #pack.registrations.elements == 0 then return end
    for _c,v in pairs(pack.registrations.elements) do
        if not v.enabled then
            goto continue
        end

        local final_name = v.preferred_id
        local final_id = _DATA.DataIndices[__DataType.Element].Count
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
            --elseif replacement_mode == "merge" then
            elseif replacement_mode == "ignore" then
                goto continue
            else
                final_id = elestate.TypeMap[final_name]
            end
        end
        elestate.TypeMap[final_name] = final_id

        if pack.public_id then
            shared_ids[v.preferred_id] = final_name
        end

        local data_file_path = __Path.Combine(pack.folder, v.file)
        local json_data = __JObject.Parse(__File.ReadAllText(data_file_path))

        local localname = RogueEssence.LocalText(json_data["name"]["default"]:ToString())

        local alternatives = json_data["name"]["localizations"]
        if alternatives and alternatives.Type == __JTokenType.Object then
            for entry in luanet.each(alternatives:ToObject(type_Dictionary__String_string)) do
                localname.LocalTexts[entry.Key] = entry.Value
            end
        end

        local relations = json_data["relations"]
        if relations then
            calculated_matchups[final_name] = {}
            for entry in luanet.each(relations["strength-against"]:ToObject(type_Dictionary__String_string)) do
                calculated_matchups[final_name][entry.Key] = relational_terms.strength[entry.Value] or tonumber(entry.Value) or 4
            end
            for entry in luanet.each(relations["resistance-against"]:ToObject(type_Dictionary__String_string)) do
                calculated_matchups[entry.Key] = calculated_matchups[entry.Key] or {}
                calculated_matchups[entry.Key][final_name] = relational_terms.resistance[entry.Value] or tonumber(entry.Value) or 4
            end
        end

        local element_data = RogueEssence.Data.ElementData()
        element_data.Name = localname
        element_data.Comment = "Generated with Shoehorn"

        --[[ local out_data = RogueEssence.Data.Serializer.SerializeData(element_data)--__JsonConvert.SerializeObject(element_data)
        local out_path = __Path.Combine(element_data_folder, final_name .. ".json")
        __File.WriteAllText(out_path, out_data) ]]
        local out_path = __Path.Combine(element_data_folder, final_name .. ".json")
        local stream = __MemoryStream()--[[ __FileStream(
            out_path,
            __IO.FileMode.Create,
            __IO.FileAccess.Write,
            __IO.FileShare.None
        ) ]]
        RogueEssence.Data.Serializer.SerializeData(stream, element_data, false)
        local memorydata = __Encoding.UTF8:GetString(stream:ToArray()):sub(4)

        local rejson_data = __JObject.Parse(memorydata)

        rejson_data["Object"]:Remove "Symbol"
        rejson_data["Object"]:Add("Symbol", __JValue (element_symbol))
        __File.WriteAllText(out_path, __JsonConvert.SerializeObject(rejson_data), __Encoding.UTF8)
        table.insert(shoehorn.registered_identifiers.elements, final_name)

        ::continue::
    end

    print "patching type matchups"

    local type_reverse_table = {}
    for entry in luanet.each(elestate.TypeMap) do
        type_reverse_table[entry.Value] = entry.Key
        calculated_matchups[entry.Key] = calculated_matchups[entry.Key] or {}
    end
    --[[ calculated_matchups["none"] = {}
    type_reverse_table[0] = "none" ]]

    print("type map size:", elestate.TypeMap.Count)
    local new_element_matchups = __Array.CreateInstance(elestate.TypeMatchup[0]:GetType(), elestate.TypeMap.Count)

    local arrayType = luanet.ctype(__Int32)
    for i = 0, elestate.TypeMatchup.Length - 1 do
        local thisElementArray = elestate.TypeMatchup[i]
        if thisElementArray == nil then
            print(("for some reason the element array for %d is nil"):format(i))
        end
        local array = __Array.CreateInstance(arrayType, elestate.TypeMap.Count)
        for e = 0, thisElementArray.Length - 1 do
            print(type_reverse_table[i],type_reverse_table[e],calculated_matchups[type_reverse_table[i]],calculated_matchups[type_reverse_table[i]][type_reverse_table[e]])
            array[e] = calculated_matchups[type_reverse_table[i]][type_reverse_table[e]] or thisElementArray[e] or 4
        end
        for e = thisElementArray.Length, elestate.TypeMap.Count - 1 do
            array[e] = calculated_matchups[type_reverse_table[i]][type_reverse_table[e]] or 4
        end
        new_element_matchups[i] = array
    end
    for i = elestate.TypeMatchup.Length, elestate.TypeMap.Count - 1 do
        local array = __Array.CreateInstance(arrayType, elestate.TypeMap.Count)
        for entry in luanet.each(elestate.TypeMap) do
            array[entry.Value] = calculated_matchups[type_reverse_table[i]][entry.Key] or 4
        end
        new_element_matchups[i] = array
    end
    elestate.TypeMatchup = new_element_matchups

    RogueEssence.Data.Serializer.SerializeDataAsDiff(
        __Path.Combine(mod_path, "Data", "Universal.jsonpatch"),
        __Path.Combine(RogueEssence.PathMod.APP_PATH, "Data", "Universal.json"),
        _DATA.UniversalEvent
    )

    print("finished elements")

    return local_renames
end