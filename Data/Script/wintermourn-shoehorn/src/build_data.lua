local __Type = luanet.import_type "System.Type"
    local type__Single = __Type.GetType 'System.Single'

local __IO = luanet.namespace 'System.IO' or luanet.namespace 'System.IO.Directory'
    local __Directory = __IO.Directory
    local __Path = __IO.Path
    local __File = __IO.File

local __Json_Linq = import ("Newtonsoft.Json", "Newtonsoft.Json.Linq")
    local __JObject = __Json_Linq.JObject
    local __JTokenType = __Json_Linq.JTokenType

local __Dictionary__String_String = luanet.import_type 'System.Collections.Generic.Dictionary`2[System.String,System.String]'
    local type_Dictionary__String_string = luanet.ctype(__Dictionary__String_String)

local function get_string_in_jobject(object, key)
    local obj = object[key]
    return obj and obj:ToString() or ""
end

local function get_string_in_jobject_or_error(object, key, shoehorn_path, err)
    return object[key] and object[key]:ToString() or error(("%s (in %s)"):format(err, shoehorn_path))
end

local valid_pack_info_file_names = {
    ".shoehorn",
    "pack.shoehorn",
    "pack.shoehorn.json"
}

---@return Wintermourn.Shoehorn.Pack
return function(shoehorn_folder, constants)
    local ficontent
    for i, k in ipairs(valid_pack_info_file_names) do
        local path = __Path.Combine(shoehorn_folder, k)
        if __File.Exists(path) then
            ficontent = __File.ReadAllText(path)
            break
        end
    end
    local json = __JObject.Parse(ficontent)--__JsonConvert.DeserializeObject()

    if json == nil then print(("Shoehorn file in %s is invalid or missing"):format(shoehorn_folder:sub(RogueEssence.PathMod.APP_PATH:len()))) return nil end

    ---@class Wintermourn.Shoehorn.Pack
    local output = {
        shoehorn_version = json["shoehorn-version"]:ToObject(type__Single),
        folder = shoehorn_folder,
        name = json["name"]:ToString(),
        authors = {},
        description = json["description"]:ToString()
    }

    local namespace = json["id-namespace"]
    if namespace then output.public_id = namespace:ToString() end

    local authors = json["authors"]
    if authors and authors.Type == __JTokenType.Array then
        for token in luanet.each(authors) do
            if token.Type == __JTokenType.String then
                table.insert(output.authors, token:ToString())
            else
                print("invalid token in authors array")
            end
        end
    end

    local registrations = json["registrations"]
    if registrations and registrations.Type ~= __JTokenType.Object then
        print("invalid registrations object in shoehorn for ".. shoehorn_folder:sub(RogueEssence.PathMod.APP_PATH:len()))
        goto skip_registrations
    elseif not registrations then
        goto skip_registrations
    end
    output.registrations = {}

    -- Data Validation
    for _, category in pairs({
        "monsters",
        "elements",
        "skills",
        "items",
        "intrinsics"
    }) do
        local object = registrations[category]
        if not object or object.Type ~= __JTokenType.Array or object.Count == 0 then goto continue_category end
        output.registrations[category] = {}

        for registration in luanet.each(object) do
            local pref_id = get_string_in_jobject(registration, "preferred-id")
            if pref_id == "" then goto continue_reg end
            local replace_mode = get_string_in_jobject(registration, "replacement-mode")

            if not constants.valid_replace_types[category][replace_mode] then
                print(("Invalid replacement-mode '%s' for registration %s (in %s); defaulting to 'replace'"):format(
                    replace_mode, pref_id, shoehorn_folder:sub(RogueEssence.PathMod.APP_PATH:len())
                ))
                replace_mode = "replace"
            end

            local reg_output = {
                enabled = true,
                preferred_id = pref_id,
                replacement_mode = replace_mode
            }

            if category == "monsters" then
                local files = registration["files"]
                if not files then print(
                        ("Monster %s requires at least one file to be registered: data, sprites, portraits (in %s)"):format(
                            pref_id, shoehorn_folder:sub(RogueEssence.PathMod.APP_PATH:len())
                        )
                    )
                    goto continue_reg
                else
                    local data = get_string_in_jobject(files, "data")
                    local sprites = get_string_in_jobject(files, "sprites")
                    local portraits = get_string_in_jobject(files, "portraits")

                    local doesAnyExist = false
                    for _name, path in pairs({
                        data = data, sprites = sprites, portraits = portraits
                    }) do
                        if path == "" then goto continue_file_monsters end
                        if not __File.Exists(__Path.Combine(shoehorn_folder, path)) then
                            print(("File %s is listed for monster %s but does not exist (in %s)"):format(
                                path, pref_id, shoehorn_folder:sub(RogueEssence.PathMod.APP_PATH:len())
                            ))
                            goto continue_file_monsters
                        end
                        doesAnyExist = true
                        ::continue_file_monsters::
                    end

                    if not doesAnyExist then print(
                            ("Monster %s requires at least one file to be replaced: data, sprites, portraits (in %s)"):format(
                                pref_id, shoehorn_folder:sub(RogueEssence.PathMod.APP_PATH:len())
                            )
                        )
                        goto continue_reg
                    end

                    reg_output.files = {
                        data = data ~= "" and data or nil,
                        sprites = sprites ~= "" and sprites or nil,
                        portraits = portraits ~= "" and portraits or nil
                    }
                end
            else
                local file = registration["file"]
                if not file then 
                    local cat = category:sub(1,1):upper() .. category:sub(2, -2)
                    print(
                        ("%s %s requires a data file (in %s)"):format(
                            cat, pref_id, shoehorn_folder:sub(RogueEssence.PathMod.APP_PATH:len())
                        )
                    )
                    goto continue_reg
                end
                file = file:ToString()

                if not __File.Exists(__Path.Combine(shoehorn_folder, file)) then
                    local cat = category:sub(1, -2)
                    print(("File %s is listed for %s %s but does not exist (in %s)"):format(
                        file, cat, pref_id, shoehorn_folder:sub(RogueEssence.PathMod.APP_PATH:len())
                    ))
                    goto continue_reg
                end

                reg_output.file = file
            end

            table.insert(output.registrations[category], reg_output)

            ::continue_reg::
        end

        ::continue_category::
    end

    ::skip_registrations::

    local patches = json["patches"]
    if patches and patches.Type ~= __JTokenType.Object then
        print("invalid patches object in shoehorn for ".. shoehorn_folder:sub(RogueEssence.PathMod.APP_PATH:len()))
        return output
    elseif not patches then
        return output
    end
    output.patches = {}

    local zones = patches["zones"]
    if zones then
        output.patches.zones = {}

        if zones.Type ~= __JTokenType.Object then return output end

        for entry in luanet.each(zones:ToObject(type_Dictionary__String_string)) do
            output.patches.zones[entry.Key] = entry.Value
        end
    end

    return output
end