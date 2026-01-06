local __IO = luanet.namespace 'System.IO' or luanet.namespace 'System.IO.Directory'
    local __Path = __IO.Path
    local __File = __IO.File
local __SHA256 = luanet.import_type 'System.Security.Cryptography.SHA256'
local __BitConverter = luanet.import_type 'System.BitConverter'
local __Text = luanet.namespace 'System.Text'
    local __Encoding = __Text.Encoding

local sha = __SHA256.Create()

local function single_hash(file_path)
    if not __File.Exists(file_path) then return "" end

    local fileBytes = __File.ReadAllBytes(file_path)
    local hashBytes = sha:ComputeHash(fileBytes)

    return __BitConverter.ToString(hashBytes):gsub('-', '')
end

local function monster_hash(shoehorn, monster_registration_data)
    local combined_hash = ""

    if monster_registration_data.files.data then
        combined_hash = combined_hash .. single_hash(__Path.Combine(shoehorn.folder, monster_registration_data.files.data))
    end
    if monster_registration_data.files.sprites then
        combined_hash = combined_hash .. single_hash(__Path.Combine(shoehorn.folder, monster_registration_data.files.sprites))
    end
    if monster_registration_data.files.portraits then
        combined_hash = combined_hash .. single_hash(__Path.Combine(shoehorn.folder, monster_registration_data.files.portraits))
    end

    local final_hash = sha:ComputeHash(__Encoding.UTF8:GetBytes(combined_hash))

    return __BitConverter.ToString(final_hash):gsub('-', '')
end

return function(enabled_shoehorns)
    local master_hash = ""
    for _i,k in pairs(enabled_shoehorns) do
        if k.registrations == nil or k.registrations.monsters == nil or #k.registrations.monsters == 0 then goto skip end
        for _c,v in pairs(k.registrations.monsters) do
            if v.enabled then
                master_hash = master_hash .. monster_hash(k, v)
            end
        end
        ::skip::
    end

    return __BitConverter.ToString(
        sha:ComputeHash(__Encoding.UTF8:GetBytes(master_hash))
    ):gsub('-', '')
end